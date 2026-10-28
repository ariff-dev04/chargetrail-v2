"""Service layer coordinating EV Charging Station business rules and seed data.

Handles radial distance calculation, view transforms, 404 enforcement, and
realistic Malaysian EV charging seed orchestration across states.
"""

import math
from uuid import NAMESPACE_DNS, UUID, uuid5

from fastapi import HTTPException, status

from app.models.station import ChargingStation
from app.repositories.station_repository import StationRepository
from app.schemas.station import (
    AccessStep,
    PlugInfo,
    SeedResponse,
    StationCreate,
    StationFilterParams,
    StationRead,
)
from app.services.station_seed_data import build_malaysian_seed_dataset


def haversine_distance_km(
    lat1: float,
    lon1: float,
    lat2: float,
    lon2: float,
) -> float:
    """Calculate great circle distance between two points in kilometers."""
    earth_radius_km = 6371.0088
    phi1 = math.radians(lat1)
    phi2 = math.radians(lat2)
    delta_phi = math.radians(lat2 - lat1)
    delta_lambda = math.radians(lon2 - lon1)

    a = (
        math.sin(delta_phi / 2.0) ** 2
        + math.cos(phi1) * math.cos(phi2) * math.sin(delta_lambda / 2.0) ** 2
    )
    c = 2.0 * math.atan2(math.sqrt(a), math.sqrt(1.0 - a))
    return earth_radius_km * c


class StationService:
    """Orchestrates station retrieval, distance calculations, and seed operations."""

    def __init__(self, repository: StationRepository) -> None:
        """Initialize service with an injected station repository."""
        self.repository = repository

    async def get_stations(
        self,
        filters: StationFilterParams,
    ) -> list[StationRead]:
        """Retrieve charging stations matching filter criteria with distance calculation."""
        entities = await self.repository.list_stations(filters)
        results: list[StationRead] = []

        is_proximity_query = filters.lat is not None and filters.lng is not None

        for entity in entities:
            station_dto = self._entity_to_dto(entity)

            if is_proximity_query and filters.lat is not None and filters.lng is not None:
                dist = haversine_distance_km(
                    filters.lat,
                    filters.lng,
                    entity.latitude,
                    entity.longitude,
                )
                # Enforce exact circular radius filter
                if dist > filters.radius_km:
                    continue
                station_dto.distance_km = round(dist, 2)

            results.append(station_dto)

        # Sort proximity queries by ascending distance
        if is_proximity_query:
            results.sort(key=lambda s: s.distance_km or 0.0)

        return results

    async def get_station_by_id(self, station_id: UUID) -> StationRead:
        """Retrieve station detail by ID or raise HTTP 404."""
        entity = await self.repository.get_by_id(station_id)
        if not entity:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Charging station with ID '{station_id}' was not found.",
            )
        return self._entity_to_dto(entity)

    async def seed_sample_stations(self) -> SeedResponse:
        """Seed realistic Malaysian charging stations across major geographic hubs."""
        sample_dataset = build_malaysian_seed_dataset()
        inserted, total = await self.repository.upsert_seed_stations(sample_dataset)

        message = (
            f"Successfully seeded {inserted} new stations. Total available: {total}."
            if inserted > 0
            else f"Seed stations already exist. Database retains {total} total stations."
        )
        return SeedResponse(
            inserted_count=inserted,
            total_count=total,
            message=message,
        )

    async def upsert_batch_stations(
        self,
        stations_in: list[StationCreate],
    ) -> list[StationRead]:
        """Batch upsert externally discovered OSM stations idempotently."""
        if not stations_in:
            return []
        await self.repository.upsert_seed_stations(stations_in)
        min_lat = min(s.latitude for s in stations_in) - 0.02
        max_lat = max(s.latitude for s in stations_in) + 0.02
        min_lng = min(s.longitude for s in stations_in) - 0.02
        max_lng = max(s.longitude for s in stations_in) + 0.02
        saved = await self.repository.list_stations(
            StationFilterParams(min_lat=min_lat, min_lng=min_lng, max_lat=max_lat, max_lng=max_lng)
        )
        return [self._entity_to_dto(s) for s in saved]

    async def upsert_external_station(self, station_in: StationCreate) -> StationRead:
        """Idempotently upsert an externally discovered OSM or community station upon interaction."""
        existing = await self.repository.find_by_coordinates(
            latitude=station_in.latitude,
            longitude=station_in.longitude,
            tolerance_km=0.15,
        )
        if existing:
            return self._entity_to_dto(existing)

        persisted_data = station_in.model_copy(
            update={"is_verified": True, "source": station_in.source or "osm_live"}
        )
        created = await self.repository.create_station(persisted_data)
        return self._entity_to_dto(created)

    @classmethod
    def merge_osm_stations(
        cls,
        db_stations: list[StationRead],
        osm_candidates: list[StationCreate],
        filters: StationFilterParams,
    ) -> list[StationRead]:
        """Merge in-memory live OSM stations with DB stations, deduplicating within 150m."""
        is_proximity = filters.lat is not None and filters.lng is not None
        merged = list(db_stations)
        existing_coords = [(s.latitude, s.longitude) for s in db_stations]

        for cand in osm_candidates:
            # 1. Viewport boundary check if specified
            if (
                filters.min_lat is not None
                and filters.max_lat is not None
                and not (filters.min_lat <= cand.latitude <= filters.max_lat)
            ):
                continue
            if (
                filters.min_lng is not None
                and filters.max_lng is not None
                and not (filters.min_lng <= cand.longitude <= filters.max_lng)
            ):
                continue

            # 2. Proximity distance check
            dist_km: float | None = None
            if is_proximity and filters.lat is not None and filters.lng is not None:
                dist_km = haversine_distance_km(
                    filters.lat, filters.lng, cand.latitude, cand.longitude
                )
                if dist_km > filters.radius_km:
                    continue

            # 3. Power output filter
            if filters.min_kw is not None and cand.max_power_kw < filters.min_kw:
                continue

            # 4. Connector type filter
            if filters.connector_type is not None:
                req_conn = filters.connector_type.lower()
                if not any(p.type.lower() == req_conn for p in cand.plug_types):
                    continue

            # 5. Amenity filter
            if filters.amenity is not None:
                req_amenity = filters.amenity.lower()
                if not any(req_amenity in a.lower() for a in cand.amenities):
                    continue

            # 6. Deduplicate against DB stations and already accepted candidates (150m tolerance)
            # Exception: Do not deduplicate opposite-direction highway R&Rs across the highway median
            is_dup = False
            for existing_st in merged:
                if (
                    haversine_distance_km(
                        cand.latitude, cand.longitude, existing_st.latitude, existing_st.longitude
                    )
                    < 0.15
                ):
                    c_name = (
                        f"{cand.name} {cand.address}".lower()
                        .replace("utara-selatan", "")
                        .replace("utara\u2013selatan", "")
                    )
                    e_name = (
                        f"{existing_st.name} {existing_st.address}".lower()
                        .replace("utara-selatan", "")
                        .replace("utara\u2013selatan", "")
                    )
                    c_nb = any(k in c_name for k in ("northbound", "arah utara"))
                    c_sb = any(k in c_name for k in ("southbound", "arah selatan"))
                    e_nb = any(k in e_name for k in ("northbound", "arah utara"))
                    e_sb = any(k in e_name for k in ("southbound", "arah selatan"))
                    if (c_nb and e_sb) or (c_sb and e_nb):
                        continue
                    is_dup = True
                    break

            if is_dup:
                continue

            # Convert to StationRead DTO
            dto = cls._create_to_dto(cand)
            if dist_km is not None:
                dto.distance_km = round(dist_km, 2)

            merged.append(dto)
            existing_coords.append((cand.latitude, cand.longitude))

        if is_proximity:
            merged.sort(key=lambda s: s.distance_km if s.distance_km is not None else float("inf"))

        return merged

    @staticmethod
    def _create_to_dto(station_in: StationCreate) -> StationRead:
        """Convert a non-persisted StationCreate to StationRead DTO with a deterministic UUID."""
        seed_key = f"{station_in.latitude:.6f}_{station_in.longitude:.6f}_{station_in.name}"
        station_id = uuid5(NAMESPACE_DNS, seed_key)

        return StationRead(
            id=station_id,
            name=station_in.name,
            operator_name=station_in.operator_name,
            address=station_in.address,
            city=station_in.city,
            state=station_in.state,
            latitude=station_in.latitude,
            longitude=station_in.longitude,
            plug_types=station_in.plug_types,
            max_power_kw=station_in.max_power_kw,
            is_available=station_in.is_available,
            is_24_hours=station_in.is_24_hours,
            charging_cost_myr=station_in.charging_cost_myr,
            parking_fee_myr=station_in.parking_fee_myr,
            parking_level=station_in.parking_level,
            operation_hours=station_in.operation_hours,
            amenities=station_in.amenities or [],
            how_to_access=station_in.how_to_access or [],
            description=station_in.description,
            rating=0.0,
            review_count=0,
            source=station_in.source or "osm_live",
            is_verified=station_in.is_verified,
        )

    @staticmethod
    def _entity_to_dto(entity: ChargingStation) -> StationRead:
        """Transform SQLAlchemy ORM ChargingStation entity to Pydantic StationRead DTO."""
        plugs = [PlugInfo(**p) if isinstance(p, dict) else p for p in (entity.plug_types or [])]
        steps = [
            AccessStep(**s) if isinstance(s, dict) else s for s in (entity.how_to_access or [])
        ]

        return StationRead(
            id=entity.id,
            name=entity.name,
            operator_name=entity.operator_name,
            address=entity.address,
            city=entity.city,
            state=entity.state,
            latitude=entity.latitude,
            longitude=entity.longitude,
            plug_types=plugs,
            max_power_kw=entity.max_power_kw,
            is_available=entity.is_available,
            is_24_hours=entity.is_24_hours,
            charging_cost_myr=entity.charging_cost_myr,
            parking_fee_myr=entity.parking_fee_myr,
            parking_level=entity.parking_level,
            operation_hours=entity.operation_hours,
            amenities=entity.amenities or [],
            how_to_access=steps,
            description=entity.description,
            rating=entity.rating,
            review_count=entity.review_count,
            source=entity.source,
            is_verified=entity.is_verified,
            created_at=entity.created_at,
            updated_at=entity.updated_at,
        )
