"""Route planning engine calculating range anxiety risk and corridor charging stops."""

from dataclasses import dataclass

from app.repositories.station_repository import StationRepository
from app.repositories.vehicle_repository import VehicleRepository
from app.schemas.routing import (
    ChargingStopRecommendation,
    LatLngPoint,
    RoutePlanRequest,
    RoutePlanResponse,
)
from app.schemas.station import StationFilterParams, StationRead
from app.services.osm_harvester_service import OsmHarvesterService
from app.services.osrm_client import OsrmClient
from app.services.station_service import StationService, haversine_distance_km


@dataclass
class _CorridorCandidate:
    station: StationRead
    dist: float
    detour: float


def _is_directionally_compatible(
    station_name: str, station_lat: float, origin_lat: float, dest_lat: float
) -> bool:
    """Filter out highway R&Rs on opposite bound or stations behind origin/beyond destination."""
    name_lower = station_name.lower()
    if dest_lat - origin_lat > 0.15:
        if "southbound" in name_lower or "arah selatan" in name_lower:
            return False
        if station_lat < origin_lat - 0.05 or station_lat > dest_lat + 0.05:
            return False
    elif origin_lat - dest_lat > 0.15:
        if "northbound" in name_lower or "arah utara" in name_lower:
            return False
        if station_lat > origin_lat + 0.05 or station_lat < dest_lat - 0.05:
            return False
    return True


class RoutePlannerService:
    """Orchestrates battery route simulation, corridor filtering, and charging stop optimization."""

    def __init__(
        self,
        station_repository: StationRepository,
        vehicle_repository: VehicleRepository,
        osrm_client: OsrmClient,
    ) -> None:
        """Initialize service with station, vehicle, and routing dependencies."""
        self.station_repo = station_repository
        self.vehicle_repo = vehicle_repository
        self.osrm_client = osrm_client

    async def plan_route(self, request: RoutePlanRequest) -> RoutePlanResponse:
        """Execute battery-aware journey simulation and recommend optimized charging stops."""
        # 1. Resolve Vehicle Specifications (Garage vehicle vs custom parameters)
        (
            battery_kwh,
            efficiency,
            max_dc_kw,
            connector,
            reserve_soc,
            vehicle_label,
        ) = await self._resolve_vehicle_specs(request)

        # 2. Fetch Highway Polyline and Road Distance via OSRM Client
        points, total_dist_km, drive_mins = await self.osrm_client.fetch_route(
            origin_lat=request.origin_lat,
            origin_lng=request.origin_lng,
            dest_lat=request.destination_lat,
            dest_lng=request.destination_lng,
        )

        # 3. Compute Energy Expenditure & Direct Arrival Battery SoC (KF14)
        total_energy_kwh = round((total_dist_km * efficiency) / 1000.0, 2)
        used_soc_percent = (total_energy_kwh / battery_kwh) * 100.0
        projected_dest_soc = round(request.starting_soc_percent - used_soc_percent)

        # 4. Filter Corridor Charging Stations Along Route Geometry (KF15)
        candidates = await self._find_corridor_candidates(
            points=points,
            connector=connector,
            max_radius_km=request.corridor_radius_km,
            origin_lat=request.origin_lat,
            dest_lat=request.destination_lat,
        )

        if len(candidates) < 2 and points:
            await OsmHarvesterService.harvest_route_corridor(self.station_repo, points)
            candidates = await self._find_corridor_candidates(
                points=points,
                connector=connector,
                max_radius_km=request.corridor_radius_km,
                origin_lat=request.origin_lat,
                dest_lat=request.destination_lat,
            )

        corridor_stations = [c.station for c in candidates]

        # 5. Classify Range Anxiety Status (KF14)
        status_code, status_summary = self._classify_range_anxiety(
            projected_soc=projected_dest_soc,
            reserve_soc=reserve_soc,
            starting_soc=request.starting_soc_percent,
            energy_used_percent=round(used_soc_percent),
        )

        # 6. Optimize Corridor Charging Stops if Battery Recharge Required (KF15)
        recommended_stops, total_charge_mins, final_arrival_soc = self._optimize_charging_stops(
            candidates=candidates,
            total_dist_km=total_dist_km,
            starting_soc=request.starting_soc_percent,
            reserve_soc=reserve_soc,
            battery_kwh=battery_kwh,
            efficiency=efficiency,
            max_dc_kw=max_dc_kw,
            projected_dest_soc=projected_dest_soc,
            status_code=status_code,
            points=points,
            preferred_stop_ids=request.preferred_stop_station_ids,
        )

        return RoutePlanResponse(
            origin_name=request.origin_name,
            destination_name=request.destination_name,
            total_distance_km=total_dist_km,
            estimated_drive_minutes=drive_mins,
            total_charging_minutes=total_charge_mins,
            total_trip_minutes=drive_mins + total_charge_mins,
            starting_soc_percent=request.starting_soc_percent,
            projected_destination_soc_without_charging=projected_dest_soc,
            final_arrival_soc_percent=final_arrival_soc,
            total_energy_kwh=total_energy_kwh,
            range_anxiety_status=status_code,
            status_summary=status_summary,
            vehicle_summary=vehicle_label,
            polyline_points=points,
            recommended_stops=recommended_stops,
            corridor_stations=corridor_stations,
        )

    async def _resolve_vehicle_specs(
        self,
        request: RoutePlanRequest,
    ) -> tuple[float, float, float, str, int, str]:
        """Resolve battery capacity, consumption rate, and safety reserves."""
        if request.vehicle_id:
            vehicle = await self.vehicle_repo.get_by_id(request.vehicle_id)
            if vehicle:
                label = f"{vehicle.brand} {vehicle.model_name}"
                return (
                    vehicle.battery_capacity_kwh,
                    vehicle.efficiency_wh_per_km,
                    vehicle.max_dc_charge_kw,
                    vehicle.connector_type,
                    vehicle.reserve_soc_percent,
                    label,
                )

        label = f"EV ({request.battery_capacity_kwh} kWh, {request.efficiency_wh_per_km} Wh/km)"
        return (
            request.battery_capacity_kwh,
            request.efficiency_wh_per_km,
            request.max_dc_charge_kw,
            request.connector_type,
            request.reserve_soc_percent,
            label,
        )

    async def _find_corridor_candidates(
        self,
        points: list[LatLngPoint],
        connector: str,
        max_radius_km: float,
        origin_lat: float,
        dest_lat: float,
    ) -> list[_CorridorCandidate]:
        """Find verified stations supporting connector standard within corridor buffer."""
        all_stations = await self.station_repo.list_stations(
            StationFilterParams(limit=100, connector_type=connector)
        )
        candidates: list[_CorridorCandidate] = []

        for entity in all_stations:
            if not _is_directionally_compatible(entity.name, entity.latitude, origin_lat, dest_lat):
                continue
            station_dto = StationService._entity_to_dto(entity)
            # Find minimum orthogonal distance from station to any polyline point
            detour_km = min(
                haversine_distance_km(p.latitude, p.longitude, entity.latitude, entity.longitude)
                for p in points
            )

            if detour_km <= max_radius_km:
                # Estimate distance along highway from origin
                closest_idx = min(
                    range(len(points)),
                    key=lambda i: haversine_distance_km(
                        points[i].latitude, points[i].longitude, entity.latitude, entity.longitude
                    ),
                )
                dist_along_route = (
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
                        station=station_dto,
                        dist=round(dist_along_route, 1),
                        detour=round(detour_km, 1),
                    )
                )

        candidates.sort(key=lambda c: c.dist)
        return candidates

    def _classify_range_anxiety(
        self,
        projected_soc: int,
        reserve_soc: int,
        starting_soc: int,
        energy_used_percent: int,
    ) -> tuple[str, str]:
        """Determine trip range anxiety severity classification (KF14)."""
        if projected_soc >= reserve_soc + 10:
            return (
                "safe",
                f"Destination reachable safely with {projected_soc}% battery remaining "
                f"(comfortable margin above {reserve_soc}% safety reserve).",
            )

        if projected_soc >= reserve_soc:
            return (
                "warning",
                f"Arrival battery will be tight ({projected_soc}% SoC). "
                f"Approaching your {reserve_soc}% reserve safety buffer.",
            )

        return (
            "critical_charging_required",
            f"Depletion risk: Trip requires {energy_used_percent}% battery, "
            f"exceeding starting charge ({starting_soc}%). Charging stop mandatory.",
        )

    def _optimize_charging_stops(
        self,
        candidates: list[_CorridorCandidate],
        total_dist_km: float,
        starting_soc: int,
        reserve_soc: int,
        battery_kwh: float,
        efficiency: float,
        max_dc_kw: float,
        projected_dest_soc: int,
        status_code: str,
        points: list[LatLngPoint],
        preferred_stop_ids: list[str] | None = None,
    ) -> tuple[list[ChargingStopRecommendation], int, int]:
        """Select optimal charging stop sequence along travel corridor (KF15)."""
        if status_code == "safe" or not candidates:
            return [], 0, max(projected_dest_soc, 0)

        current_km = 0.0
        current_soc = starting_soc
        stops: list[ChargingStopRecommendation] = []
        total_charge_mins = 0
        preferred_set = set(preferred_stop_ids or [])

        while True:
            # Check if remaining highway distance can reach destination with safety buffer
            remaining_km = total_dist_km - current_km
            soc_to_dest = (remaining_km * efficiency / 1000.0 / battery_kwh) * 100.0

            if current_soc - soc_to_dest >= reserve_soc:
                final_soc = round(current_soc - soc_to_dest)
                return stops, total_charge_mins, max(final_soc, 0)

            # Max reachable distance before hitting safety reserve
            max_safe_dist = current_km + (
                (current_soc - reserve_soc) / 100.0 * battery_kwh * 1000.0 / efficiency
            )

            # Find reachable corridor candidates ahead (avoid immediate departure stops if starting SoC healthy)
            min_stop_dist = (
                current_km + 25.0
                if current_km == 0 and current_soc > reserve_soc + 10
                else current_km
            )
            reachable = [c for c in candidates if min_stop_dist < c.dist <= max_safe_dist]
            if not reachable:
                reachable = [c for c in candidates if current_km < c.dist <= max_safe_dist]
            if not reachable:
                # If tight, pick closest charger ahead
                reachable = [c for c in candidates if c.dist > current_km]
            if not reachable:
                break

            # Prioritize preferred user-swapped station if reachable, else fastest charger
            preferred = next((c for c in reachable if str(c.station.id) in preferred_set), None)
            if not preferred and preferred_set:
                extended_dist = current_km + (
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
                        if current_km < c.dist <= extended_dist
                        and str(c.station.id) in preferred_set
                    ),
                    None,
                )
            best = preferred or max(reachable, key=lambda c: (c.station.max_power_kw, c.dist))

            leg_dist = best.dist - current_km
            leg_energy = (leg_dist * efficiency) / 1000.0
            arrival_soc = round(current_soc - (leg_energy / battery_kwh) * 100.0)

            target_departure_soc = 80
            if target_departure_soc <= arrival_soc:
                target_departure_soc = min(arrival_soc + 20, 95)

            energy_added = ((target_departure_soc - arrival_soc) / 100.0) * battery_kwh
            effective_kw = min(best.station.max_power_kw, max_dc_kw)
            charge_mins = max(round((energy_added / (effective_kw * 0.85)) * 60), 12)
            cost_myr = round(energy_added * (best.station.charging_cost_myr or 1.40), 2)

            # Find vicinity alternatives along corridor (within ±45km)
            nearby_alts = [
                c.station
                for c in candidates
                if abs(c.dist - best.dist) <= 45.0 and str(c.station.id) != str(best.station.id)
            ][:4]

            # Project coordinate onto nearest point on highway polyline
            closest_p = min(
                points,
                key=lambda p: haversine_distance_km(
                    p.latitude, p.longitude, best.station.latitude, best.station.longitude
                ),
            )

            stops.append(
                ChargingStopRecommendation(
                    station=best.station,
                    distance_from_origin_km=best.dist,
                    detour_distance_km=best.detour,
                    arrival_soc_percent=max(arrival_soc, 5),
                    departure_soc_percent=target_departure_soc,
                    energy_added_kwh=round(energy_added, 1),
                    estimated_charge_minutes=charge_mins,
                    estimated_cost_myr=cost_myr,
                    corridor_lat=closest_p.latitude,
                    corridor_lng=closest_p.longitude,
                    nearby_alternatives=nearby_alts,
                )
            )

            total_charge_mins += charge_mins
            current_km = best.dist
            current_soc = target_departure_soc

        final_soc = round(
            current_soc - (total_dist_km - current_km) * efficiency / 1000.0 / battery_kwh * 100.0
        )
        return stops, total_charge_mins, max(final_soc, 0)
