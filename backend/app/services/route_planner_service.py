"""Route planning engine calculating range anxiety risk and corridor charging stops."""

import asyncio

from pydantic.fields import FieldInfo

from app.repositories.station_repository import StationRepository
from app.repositories.vehicle_repository import VehicleRepository
from app.schemas.routing import (
    ChargingStopRecommendation,
    LatLngPoint,
    RoutePlanRequest,
    RoutePlanResponse,
)
from app.schemas.station import StationFilterParams
from app.services.directional_highway_scorer import (
    CorridorCandidate,
    build_corridor_candidates,
    is_tesla_station,
)
from app.services.osm_harvester_service import OsmHarvesterService
from app.services.osrm_client import OsrmClient
from app.services.station_service import StationService, haversine_distance_km

_CorridorCandidate = CorridorCandidate

if "stop_strategy" not in RoutePlanRequest.model_fields:
    for k, a, d in (
        ("stop_strategy", str, "quickest"),
        ("target_arrival_soc_pct", float, 15.0),
        ("prefer_easy_access", bool, True),
        ("vehicle_name", str, ""),
        ("is_tesla_vehicle", bool, False),
    ):
        RoutePlanRequest.model_fields[k] = FieldInfo(annotation=a, default=d)
    RoutePlanRequest.model_rebuild(force=True)


class RoutePlannerService:
    """Orchestrates battery route simulation, corridor filtering, and charging stop optimization."""

    def __init__(
        self,
        station_repo: StationRepository,
        vehicle_repo: VehicleRepository,
        osrm_client: OsrmClient,
    ) -> None:
        self.station_repo = station_repo
        self.vehicle_repo = vehicle_repo
        self.osrm_client = osrm_client

    async def plan_route(self, request: RoutePlanRequest) -> RoutePlanResponse:
        """Execute battery-aware journey simulation and recommend optimized charging stops."""
        b_kwh, eff, kw, conn, res, v_label = await self._resolve_vehicle_specs(request)
        is_tesla_driver = bool(
            getattr(request, "is_tesla_vehicle", False)
            or "tesla" in str(getattr(request, "vehicle_name", "") or "").lower()
            or "tesla" in v_label.lower()
        )
        pts, dist_km, drive_mins = await self.osrm_client.fetch_route(
            origin_lat=request.origin_lat,
            origin_lng=request.origin_lng,
            dest_lat=request.destination_lat,
            dest_lng=request.destination_lng,
        )
        total_energy = round((dist_km * eff) / 1000.0, 2)
        used_soc = (total_energy / b_kwh) * 100.0
        proj_soc = round(request.starting_soc_percent - used_soc)
        cand = await self._find_corridor_candidates(
            pts, request, conn, is_tesla_driver=is_tesla_driver
        )
        t_arr = max(5.0, min(50.0, float(getattr(request, "target_arrival_soc_pct", 15.0) or 15.0)))
        code, summary = self._classify_range_anxiety(
            proj_soc, round(t_arr), request.starting_soc_percent, round(used_soc)
        )
        stops, c_mins, final_soc = self._optimize_charging_stops(
            cand,
            request,
            dist_km,
            pts,
            (b_kwh, eff, kw, res),
            proj_soc,
            code,
            is_tesla_driver=is_tesla_driver,
        )
        return RoutePlanResponse(
            origin_name=request.origin_name,
            destination_name=request.destination_name,
            total_distance_km=dist_km,
            estimated_drive_minutes=drive_mins,
            total_charging_minutes=c_mins,
            total_trip_minutes=drive_mins + c_mins,
            starting_soc_percent=request.starting_soc_percent,
            final_arrival_soc_percent=final_soc,
            projected_destination_soc_without_charging=proj_soc,
            total_energy_kwh=total_energy,
            range_anxiety_status=code,
            status_summary=summary,
            vehicle_summary=v_label,
            polyline_points=pts,
            recommended_stops=stops,
            corridor_stations=[c.station for c in cand],
        )

    async def _resolve_vehicle_specs(self, req: RoutePlanRequest):
        v = await self.vehicle_repo.get_by_id(req.vehicle_id) if req.vehicle_id else None
        lbl = f"{v.brand} {v.model_name}" if v else f"EV ({req.battery_capacity_kwh} kWh)"
        src = v or req
        return (
            src.battery_capacity_kwh,
            src.efficiency_wh_per_km,
            src.max_dc_charge_kw,
            src.connector_type,
            src.reserve_soc_percent,
            lbl,
        )

    async def _harvest_osm(
        self, pts, min_lat, min_lng, max_lat, max_lng, c_lat, c_lng, span, is_tesla: bool = False
    ):
        cell_key = f"{round(c_lat * 20)}_{round(c_lng * 20)}"
        if cell_key in OsmHarvesterService._harvest_cache and not is_tesla:
            return OsmHarvesterService._harvest_cache[cell_key]

        tasks = []
        if span <= 1.2 or len(pts) < 6:
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
        else:
            tasks = [
                OsmHarvesterService.harvest_viewport(
                    p.latitude - 0.32,
                    p.longitude - 0.32,
                    p.latitude + 0.32,
                    p.longitude + 0.32,
                    center_lat=p.latitude,
                    center_lng=p.longitude,
                    persist=False,
                )
                for p in [
                    pts[int(len(pts) * f)]
                    for f in (0.12, 0.24, 0.36, 0.48, 0.60, 0.72, 0.84, 0.90)
                    if int(len(pts) * f) < len(pts)
                ]
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
        if is_tesla:
            for q in ("Tesla Supercharger", "Tesla Destination"):
                tasks.append(
                    OsmHarvesterService.harvest_corridor_brand_pois(
                        min_lat, min_lng, max_lat, max_lng, query_text=q
                    )
                )
        res = await asyncio.gather(*tasks, return_exceptions=True)
        return [x for r in res if isinstance(r, list) for x in r]

    async def _find_corridor_candidates(
        self,
        points: list[LatLngPoint],
        req: RoutePlanRequest,
        connector: str,
        is_tesla_driver: bool = False,
    ) -> list[_CorridorCandidate]:
        if not points:
            return []
        o_lat, d_lat = req.origin_lat, req.destination_lat
        o_lng = req.origin_lng or points[0].longitude
        d_lng = req.destination_lng or points[-1].longitude
        b = (
            min(o_lat, d_lat) - 0.25,
            min(o_lng, d_lng) - 0.25,
            max(o_lat, d_lat) + 0.25,
            max(o_lng, d_lng) + 0.25,
        )
        filters = StationFilterParams(
            min_lat=b[0],
            min_lng=b[1],
            max_lat=b[2],
            max_lng=b[3],
            connector_type=connector,
            limit=150,
        )
        db_stations = [
            StationService._entity_to_dto(e) for e in await self.station_repo.list_stations(filters)
        ]
        osm_candidates = await self._harvest_osm(
            points,
            *b,
            (o_lat + d_lat) / 2.0,
            (o_lng + d_lng) / 2.0,
            max(abs(d_lat - o_lat), abs(d_lng - o_lng)),
            is_tesla=is_tesla_driver,
        )
        all_stations = StationService.merge_osm_stations(
            db_stations=db_stations, osm_candidates=osm_candidates, filters=filters
        )
        seen = set()
        deduped = [
            st
            for st in sorted(
                all_stations, key=lambda s: (round(s.latitude, 5), round(s.longitude, 5), str(s.id))
            )
            if (k := (round(st.latitude, 5), round(st.longitude, 5))) not in seen
            and not seen.add(k)
        ]
        return build_corridor_candidates(
            stations=deduped,
            points=points,
            origin_lat=o_lat,
            dest_lat=d_lat,
            max_corridor_detour=min(req.corridor_radius_km, 5.0),
            prefer_easy_access=bool(getattr(req, "prefer_easy_access", True)),
            is_tesla_driver=is_tesla_driver,
        )

    def _classify_range_anxiety(
        self, proj_soc: int, res_soc: int, start_soc: int, used_pct: int
    ) -> tuple[str, str]:
        if proj_soc >= res_soc + 10:
            return "safe", f"Destination safe: {proj_soc}% remaining (above {res_soc}% reserve)."
        if proj_soc >= res_soc:
            return "warning", f"Arrival tight: {proj_soc}% SoC."
        return (
            "critical_charging_required",
            f"Depletion risk: Trip needs {used_pct}% > {start_soc}%.",
        )

    @staticmethod
    def _build_stop(best, arr_soc, dep_soc, kwh, kw, points, cand, key_fn):
        added = ((dep_soc - arr_soc) / 100.0) * kwh
        mins = max(round((added / (min(best.station.max_power_kw, kw) * 0.85)) * 60), 12)
        close = [
            c
            for c in cand
            if abs(c.dist - best.dist) <= 45.0 and str(c.station.id) != str(best.station.id)
        ]
        alts = [c.station for c in sorted(close, key=key_fn)[:4]]
        p = min(
            points,
            key=lambda pt: haversine_distance_km(
                pt.latitude, pt.longitude, best.station.latitude, best.station.longitude
            ),
        )
        return ChargingStopRecommendation(
            station=best.station,
            distance_from_origin_km=best.dist,
            detour_distance_km=best.detour,
            arrival_soc_percent=max(arr_soc, 5),
            departure_soc_percent=dep_soc,
            energy_added_kwh=round(added, 1),
            estimated_charge_minutes=mins,
            estimated_cost_myr=round(added * (best.station.charging_cost_myr or 1.40), 2),
            corridor_lat=p.latitude,
            corridor_lng=p.longitude,
            nearby_alternatives=alts,
        ), mins

    def _optimize_charging_stops(
        self,
        candidates: list[_CorridorCandidate],
        request: RoutePlanRequest,
        total_dist_km: float,
        points: list[LatLngPoint],
        specs: tuple[float, float, float, int],
        projected_dest_soc: int,
        status_code: str,
        is_tesla_driver: bool = False,
    ) -> tuple[list[ChargingStopRecommendation], int, int]:
        strategy = str(getattr(request, "stop_strategy", "quickest") or "quickest").lower()
        t_arr = max(5.0, min(50.0, float(getattr(request, "target_arrival_soc_pct", 15.0) or 15.0)))
        trig_soc, dep_cap = {
            "few_long": (max(25.0, t_arr), 95.0),
            "short_many": (max(40.0, t_arr + 10.0), 65.0),
        }.get(strategy, (max(30.0, t_arr), 80.0))
        if (status_code == "safe" and projected_dest_soc >= t_arr) or not candidates:
            return [], 0, max(projected_dest_soc, 0)

        b_kwh, eff, kw, _ = specs
        cur_km, cur_soc, total_mins, stops = 0.0, request.starting_soc_percent, 0, []
        preferred_set = set(request.preferred_stop_station_ids or [])

        while True:
            rem_km = total_dist_km - cur_km
            soc_to_dest = (rem_km * eff / 1000.0 / b_kwh) * 100.0
            if cur_soc - soc_to_dest >= t_arr:
                return stops, total_mins, max(round(cur_soc - soc_to_dest), 0)

            ahead = [c for c in candidates if c.dist > cur_km]
            if not ahead:
                break

            max_safe = cur_km + ((cur_soc - 15.0) / 100.0 * b_kwh * 1000.0 / eff)
            in_range = [c for c in ahead if c.dist <= max_safe] or [ahead[0]]

            valid = []
            for c in in_range:
                arr = cur_soc - (((c.dist - cur_km) * eff) / 1000.0 / b_kwh) * 100.0
                has_further = any(n.dist > c.dist for n in in_range)
                is_final_leg = (total_dist_km - c.dist <= 350.0) or (arr <= 55.0)
                is_sc = is_tesla_driver and is_tesla_station(
                    c.station.name, c.station.operator_name or ""
                )
                if (is_sc and arr <= 58.0 and (dep_cap - arr >= 20.0)) or (
                    arr <= trig_soc
                    or not has_further
                    or (is_final_leg and arr <= max(trig_soc, 45.0))
                ):
                    valid.append(c)

            reachable = valid or [in_range[-1]]
            if is_tesla_driver and (
                scs := [
                    c
                    for c in reachable
                    if is_tesla_station(c.station.name, c.station.operator_name or "")
                ]
            ):
                reachable = scs

            pref = next((c for c in reachable if str(c.station.id) in preferred_set), None)
            if not pref and preferred_set:
                ext = cur_km + ((cur_soc - 10.0) / 100.0 * b_kwh * 1000.0 / eff)
                pref = next(
                    (
                        c
                        for c in candidates
                        if cur_km < c.dist <= ext and str(c.station.id) in preferred_set
                    ),
                    None,
                )

            def key_fn(c):
                return (
                    c.score,
                    round(c.station.latitude, 6),
                    round(c.station.longitude, 6),
                    str(c.station.id),
                )

            best = pref or min(reachable, key=key_fn)
            arr_soc = max(
                round(cur_soc - (((best.dist - cur_km) * eff) / 1000.0 / b_kwh) * 100.0), 5
            )
            dep_soc = round(dep_cap if arr_soc < dep_cap else min(arr_soc + 15, 95))

            rem_to_dest = total_dist_km - best.dist
            soc_needed_dest = (rem_to_dest * eff / 1000.0 / b_kwh) * 100.0
            more_ahead = any(c.dist > best.dist for c in candidates)
            can_reach_next = any(
                c.dist > best.dist
                and c.dist <= best.dist + ((dep_cap - 15.0) / 100.0 * b_kwh * 1000.0 / eff)
                for c in candidates
            )
            if not more_ahead or not can_reach_next or (soc_needed_dest + t_arr <= 95.0):
                dep_soc = max(dep_soc, min(round(soc_needed_dest + t_arr), 95))

            min_delta = (
                20
                if (
                    is_tesla_driver
                    and is_tesla_station(best.station.name, best.station.operator_name or "")
                )
                else 12
            )
            if (dep_soc - arr_soc < min_delta) and (arr_soc >= 20):
                if more_ahead:
                    cur_km, cur_soc = best.dist, arr_soc
                    continue
                dep_soc = min(max(dep_soc, arr_soc + min_delta), 95)

            rec, charge_mins = self._build_stop(
                best, arr_soc, dep_soc, b_kwh, kw, points, candidates, key_fn
            )
            stops.append(rec)
            total_mins += charge_mins
            cur_km, cur_soc = best.dist, dep_soc

        return (
            stops,
            total_mins,
            max(round(cur_soc - (total_dist_km - cur_km) * eff / 1000.0 / b_kwh * 100.0), 0),
        )
