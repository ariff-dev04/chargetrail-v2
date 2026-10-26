"""Service layer coordinating EV Charging Station business rules and seed data.

Handles radial distance calculation, view transforms, 404 enforcement, and
realistic Malaysian EV charging seed orchestration across states.
"""

import math
from uuid import UUID

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
