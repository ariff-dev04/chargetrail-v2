"""Route planning engine calculating range anxiety risk and corridor charging stops."""

import asyncio
from dataclasses import dataclass

from app.repositories.station_repository import StationRepository
from app.repositories.vehicle_repository import VehicleRepository
from app.schemas.routing import (
    ChargingStopRecommendation,
    LatLngPoint,
    RoutePlanRequest,
    RoutePlanResponse,
)
from app.schemas.station import StationCreate, StationFilterParams, StationRead
from app.services.osm_harvester_service import OsmHarvesterService
from app.services.osrm_client import OsrmClient
from app.services.station_service import StationService, haversine_distance_km

NORTHBOUND_KEYWORDS = ("northbound", "north bound", " nb", "arah utara", "utara")
SOUTHBOUND_KEYWORDS = ("southbound", "south bound", " sb", "arah selatan", "selatan")
EASTBOUND_KEYWORDS = ("eastbound", "east bound", " eb", "arah timur", "timur")
WESTBOUND_KEYWORDS = ("westbound", "west bound", " wb", "arah barat", "barat")


def _has_keyword(text: str, keywords: tuple[str, ...]) -> bool:
    return any(kw in text for kw in keywords)


@dataclass
class _CorridorCandidate:
    station: StationRead
    dist: float
    detour: float
    local_dlat: float = 0.0
    local_dlng: float = 0.0
    is_on_left: bool = False


def _is_directionally_compatible(
    station_name: str,
    station_address: str,
    station_lat: float,
    station_lng: float = 0.0,
    origin_lat: float = 0.0,
    dest_lat: float = 0.0,
    local_dlat: float | None = None,
    local_dlng: float | None = None,
) -> bool:
    del station_lng
    raw = f"{station_name.lower()} {station_address.lower()}"
    text = (
        raw.replace("utara-selatan", "")
        .replace("utara\u2013selatan", "")
        .replace("utara selatan", "")
        .replace("north-south", "")
    )
    has_nb, has_sb = (
        _has_keyword(text, NORTHBOUND_KEYWORDS),
        _has_keyword(text, SOUTHBOUND_KEYWORDS),
    )
    has_eb, has_wb = _has_keyword(text, EASTBOUND_KEYWORDS), _has_keyword(text, WESTBOUND_KEYWORDS)

    d_lat = (
        local_dlat
        if local_dlat is not None and abs(local_dlat) > 0.0001
        else (dest_lat - origin_lat)
    )
    d_lng = local_dlng if local_dlng is not None and abs(local_dlng) > 0.0001 else 0.0

    if (d_lat > 0.0005 and has_sb and not has_nb) or (d_lat < -0.0005 and has_nb and not has_sb):
        return False
    if (d_lng > 0.0005 and has_wb and not has_eb) or (d_lng < -0.0005 and has_eb and not has_wb):
        return False
    return (min(origin_lat, dest_lat) - 0.05) <= station_lat <= (max(origin_lat, dest_lat) + 0.05)


class RoutePlannerService:
    """Orchestrates battery route simulation, corridor filtering, and charging stop optimization."""

    def __init__(
        self,
        station_repo: StationRepository,
        vehicle_repo: VehicleRepository,
        osrm_client: OsrmClient,
    ) -> None:
        self.station_repo, self.vehicle_repo, self.osrm_client = (
            station_repo,
            vehicle_repo,
            osrm_client,
        )

    async def plan_route(self, request: RoutePlanRequest) -> RoutePlanResponse:
        """Execute battery-aware journey simulation and recommend optimized charging stops."""
        (
            battery_kwh,
            efficiency,
            max_dc_kw,
            connector,
            reserve_soc,
            vehicle_label,
        ) = await self._resolve_vehicle_specs(request)
        points, total_dist_km, drive_mins = await self.osrm_client.fetch_route(
            origin_lat=request.origin_lat,
            origin_lng=request.origin_lng,
            dest_lat=request.destination_lat,
            dest_lng=request.destination_lng,
        )

        total_energy_kwh = round((total_dist_km * efficiency) / 1000.0, 2)
        used_soc_percent = (total_energy_kwh / battery_kwh) * 100.0
        projected_dest_soc = round(request.starting_soc_percent - used_soc_percent)

        candidates = await self._find_corridor_candidates(points, request, connector)
        corridor_stations = [c.station for c in candidates]

        status_code, status_summary = self._classify_range_anxiety(
            projected_dest_soc, reserve_soc, request.starting_soc_percent, round(used_soc_percent)
        )

        recommended_stops, total_charge_mins, final_arrival_soc = self._optimize_charging_stops(
            candidates,
            request,
            total_dist_km,
            points,
            (battery_kwh, efficiency, max_dc_kw, reserve_soc),
            projected_dest_soc,
            status_code,
        )

        resp_dict = {
            "origin_name": request.origin_name,
            "destination_name": request.destination_name,
            "total_distance_km": total_dist_km,
            "estimated_drive_minutes": drive_mins,
            "total_charging_minutes": total_charge_mins,
            "total_trip_minutes": drive_mins + total_charge_mins,
            "starting_soc_percent": request.starting_soc_percent,
            "final_arrival_soc_percent": final_arrival_soc,
            "projected_destination_soc_without_charging": projected_dest_soc,
            "total_energy_kwh": total_energy_kwh,
            "range_anxiety_status": status_code,
            "status_summary": status_summary,
            "vehicle_summary": vehicle_label,
            "polyline_points": points,
            "recommended_stops": recommended_stops,
            "corridor_stations": corridor_stations,
        }
        return RoutePlanResponse(**resp_dict)

    async def _resolve_vehicle_specs(
        self, req: RoutePlanRequest
    ) -> tuple[float, float, float, str, int, str]:
        if req.vehicle_id and (v := await self.vehicle_repo.get_by_id(req.vehicle_id)):
            return (
                v.battery_capacity_kwh,
                v.efficiency_wh_per_km,
                v.max_dc_charge_kw,
                v.connector_type,
                v.reserve_soc_percent,
                f"{v.brand} {v.model_name}",
            )
        return (
            req.battery_capacity_kwh,
            req.efficiency_wh_per_km,
            req.max_dc_charge_kw,
            req.connector_type,
            req.reserve_soc_percent,
            f"EV ({req.battery_capacity_kwh} kWh, {req.efficiency_wh_per_km} Wh/km)",
        )

    async def _find_corridor_candidates(
        self, points: list[LatLngPoint], req: RoutePlanRequest, connector: str
    ) -> list[_CorridorCandidate]:
        if not points:
            return []
        o_lat, d_lat = req.origin_lat, req.destination_lat
        o_lng = req.origin_lng if req.origin_lng is not None else points[0].longitude
        d_lng = req.destination_lng if req.destination_lng is not None else points[-1].longitude
        min_lat, max_lat = min(o_lat, d_lat) - 0.25, max(o_lat, d_lat) + 0.25
        min_lng, max_lng = min(o_lng, d_lng) - 0.25, max(o_lng, d_lng) + 0.25
        c_lat, c_lng = (o_lat + d_lat) / 2.0, (o_lng + d_lng) / 2.0

        corridor_filters = StationFilterParams(
            min_lat=min_lat,
            max_lat=max_lat,
            min_lng=min_lng,
            max_lng=max_lng,
            connector_type=connector,
            limit=150,
        )
        db_entities = await self.station_repo.list_stations(corridor_filters)
        db_stations = [StationService._entity_to_dto(e) for e in db_entities]
        lat_span, lng_span = abs(d_lat - o_lat), abs(d_lng - o_lng)
        osm_candidates: list[StationCreate] = []

        if (lat_span > 1.2 or lng_span > 1.2) and len(points) >= 6:
            pts = [points[int(len(points) * f)] for f in (0.2, 0.4, 0.6, 0.8)]
            tasks = [
                OsmHarvesterService.harvest_viewport(
                    p.latitude - 0.2,
                    p.longitude - 0.2,
                    p.latitude + 0.2,
                    p.longitude + 0.2,
                    center_lat=p.latitude,
                    center_lng=p.longitude,
                    persist=False,
                )
                for p in pts
            ]
            tasks.append(
                OsmHarvesterService.harvest_viewport(
                    min_lat,
                    min_lng,
                    max_lat,
                    max_lng,
                    center_lat=c_lat,
                    center_lng=c_lng,
                    persist=False,
                )
            )
            for r in await asyncio.gather(*tasks, return_exceptions=True):
                if isinstance(r, list):
                    osm_candidates.extend(r)
        else:
            osm_candidates = await OsmHarvesterService.harvest_viewport(
                min_lat=min_lat,
                min_lng=min_lng,
                max_lat=max_lat,
                max_lng=max_lng,
                center_lat=c_lat,
                center_lng=c_lng,
                persist=False,
            )

        all_stations = StationService.merge_osm_stations(
            db_stations=db_stations,
            osm_candidates=osm_candidates,
            filters=corridor_filters,
        )
        candidates: list[_CorridorCandidate] = []
        max_corridor_detour = min(req.corridor_radius_km, 5.0)

        for st in all_stations:
            detour_km = min(
                haversine_distance_km(p.latitude, p.longitude, st.latitude, st.longitude)
                for p in points
            )
            if detour_km <= max_corridor_detour:
                closest_idx = min(
                    range(len(points)),
                    key=lambda i: haversine_distance_km(
                        points[i].latitude, points[i].longitude, st.latitude, st.longitude
                    ),
                )
                start_idx, end_idx = max(0, closest_idx - 3), min(len(points) - 1, closest_idx + 3)
                local_dlat = points[end_idx].latitude - points[start_idx].latitude
                local_dlng = points[end_idx].longitude - points[start_idx].longitude

                trip_dlat, trip_dlng = d_lat - o_lat, d_lng - o_lng
                if (trip_dlat > 0.1 and local_dlat <= 0) or (trip_dlat < -0.1 and local_dlat >= 0):
                    local_dlat = trip_dlat
                if (trip_dlng > 0.1 and local_dlng <= 0) or (trip_dlng < -0.1 and local_dlng >= 0):
                    local_dlng = trip_dlng

                if not _is_directionally_compatible(
                    station_name=st.name,
                    station_address=st.address,
                    station_lat=st.latitude,
                    station_lng=st.longitude,
                    origin_lat=o_lat,
                    dest_lat=d_lat,
                    local_dlat=local_dlat,
                    local_dlng=local_dlng,
                ):
                    continue

                pt = points[closest_idx]
                is_on_left = (
                    local_dlng * (st.latitude - pt.latitude)
                    - local_dlat * (st.longitude - pt.longitude)
                ) > 0
                dist_along = (
                    sum(
                        haversine_distance_km(
                            points[i].latitude,
                            points[i].longitude,
                            points[i + 1].latitude,
                            points[i + 1].longitude,
                        )
                        for i in range(closest_idx)
                    )
                    + detour_km
                )

                candidates.append(
                    _CorridorCandidate(
                        station=st,
                        dist=round(dist_along, 1),
                        detour=round(detour_km, 1),
                        local_dlat=local_dlat,
                        local_dlng=local_dlng,
                        is_on_left=is_on_left,
                    )
                )

        candidates.sort(key=lambda c: c.dist)
        return candidates

    def _classify_range_anxiety(
        self, proj_soc: int, res_soc: int, start_soc: int, used_pct: int
    ) -> tuple[str, str]:
        if proj_soc >= res_soc + 10:
            return (
                "safe",
                f"Destination reachable safely with {proj_soc}% battery remaining (margin above {res_soc}% reserve).",
            )
        if proj_soc >= res_soc:
            return (
                "warning",
                f"Arrival battery will be tight ({proj_soc}% SoC). Approaching your {res_soc}% reserve buffer.",
            )
        return (
            "critical_charging_required",
            f"Depletion risk: Trip requires {used_pct}% battery, exceeding starting charge ({start_soc}%).",
        )

    @staticmethod
    def _score_candidate(c: _CorridorCandidate) -> float:
        st = c.station
        score = st.max_power_kw + (50.0 if c.detour < 1.5 else -c.detour * 10.0)
        desc = f"{st.name.lower()} {str(st.address).lower()} {str(st.parking_level).lower()} {st.city.lower()}"
        nb, sb = _has_keyword(desc, NORTHBOUND_KEYWORDS), _has_keyword(desc, SOUTHBOUND_KEYWORDS)

        if (c.local_dlat > 0.0005 and nb and not sb) or (c.local_dlat < -0.0005 and sb and not nb):
            score += 120.0
        if c.is_on_left:
            score += 40.0
        if any(
            k in desc
            for k in [
                "r&r",
                "rsa",
                "layby",
                "highway",
                "petrol",
                "shell",
                "petronas",
                "caltex",
                "open",
            ]
        ):
            score += 80.0
        if any(
            k in desc
            for k in [
                "mall",
                "plaza",
                "klcc",
                "pavilion",
                "basement",
                "multi-storey",
                "underground",
            ]
        ) or (st.parking_fee_myr and st.parking_fee_myr > 0.0):
            score -= 60.0
        return score

    @staticmethod
    def _build_stop(
        best: _CorridorCandidate,
        arr_soc: int,
        dep_soc: int,
        added_kwh: float,
        mins: int,
        cost: float,
        p: LatLngPoint,
        alts: list[StationRead],
    ) -> ChargingStopRecommendation:
        return ChargingStopRecommendation(
            station=best.station,
            distance_from_origin_km=best.dist,
            detour_distance_km=best.detour,
            arrival_soc_percent=max(arr_soc, 5),
            departure_soc_percent=dep_soc,
            energy_added_kwh=round(added_kwh, 1),
            estimated_charge_minutes=mins,
            estimated_cost_myr=cost,
            corridor_lat=p.latitude,
            corridor_lng=p.longitude,
            nearby_alternatives=alts,
        )

    def _optimize_charging_stops(
        self,
        candidates: list[_CorridorCandidate],
        request: RoutePlanRequest,
        total_dist_km: float,
        points: list[LatLngPoint],
        specs: tuple[float, float, float, int],
        projected_dest_soc: int,
        status_code: str,
    ) -> tuple[list[ChargingStopRecommendation], int, int]:
        if status_code == "safe" or not candidates:
            return [], 0, max(projected_dest_soc, 0)

        battery_kwh, efficiency, max_dc_kw, reserve_soc = specs
        current_km, current_soc, total_charge_mins = 0.0, request.starting_soc_percent, 0
        stops: list[ChargingStopRecommendation] = []
        preferred_set = set(request.preferred_stop_station_ids or [])

        while True:
            remaining_km = total_dist_km - current_km
            soc_to_dest = (remaining_km * efficiency / 1000.0 / battery_kwh) * 100.0
            if current_soc - soc_to_dest >= reserve_soc:
                return stops, total_charge_mins, max(round(current_soc - soc_to_dest), 0)

            max_safe_dist = current_km + (
                (current_soc - reserve_soc) / 100.0 * battery_kwh * 1000.0 / efficiency
            )
            min_stop_dist = (
                current_km + 25.0
                if current_km == 0 and current_soc > reserve_soc + 10
                else current_km
            )

            reachable = [c for c in candidates if min_stop_dist < c.dist <= max_safe_dist]
            if not reachable:
                reachable = [c for c in candidates if current_km < c.dist <= max_safe_dist]
            if not reachable:
                reachable = [c for c in candidates if c.dist > current_km]
            if not reachable:
                break

            preferred = next((c for c in reachable if str(c.station.id) in preferred_set), None)
            if not preferred and preferred_set:
                ext_dist = current_km + (
                    (current_soc - max(reserve_soc - 5, 5))
                    / 100.0
                    * battery_kwh
                    * 1000.0
                    / efficiency
                )
                preferred = next(
                    (
                        c
                        for c in candidates
                        if current_km < c.dist <= ext_dist and str(c.station.id) in preferred_set
                    ),
                    None,
                )
            best = preferred or max(reachable, key=lambda c: (self._score_candidate(c), c.dist))

            leg_energy = ((best.dist - current_km) * efficiency) / 1000.0
            arrival_soc = round(current_soc - (leg_energy / battery_kwh) * 100.0)

            target_dep_soc = 80 if arrival_soc < 80 else min(arrival_soc + 20, 95)
            energy_added = ((target_dep_soc - arrival_soc) / 100.0) * battery_kwh
            effective_kw = min(best.station.max_power_kw, max_dc_kw)
            charge_mins = max(round((energy_added / (effective_kw * 0.85)) * 60), 12)
            cost_myr = round(energy_added * (best.station.charging_cost_myr or 1.40), 2)

            nearby_alts = [
                c.station
                for c in candidates
                if abs(c.dist - best.dist) <= 45.0 and str(c.station.id) != str(best.station.id)
            ][:4]
            closest_p = min(
                points,
                key=lambda p: haversine_distance_km(
                    p.latitude, p.longitude, best.station.latitude, best.station.longitude
                ),
            )

            stops.append(
                self._build_stop(
                    best,
                    arrival_soc,
                    target_dep_soc,
                    energy_added,
                    charge_mins,
                    cost_myr,
                    closest_p,
                    nearby_alts,
                )
            )

            total_charge_mins += charge_mins
            current_km, current_soc = best.dist, target_dep_soc

        final_soc = round(
            current_soc - (total_dist_km - current_km) * efficiency / 1000.0 / battery_kwh * 100.0
        )
        return stops, total_charge_mins, max(final_soc, 0)
