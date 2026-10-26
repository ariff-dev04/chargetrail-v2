"""Service layer coordinating EV specifications, presets catalog, and garage operations."""

from uuid import UUID

from fastapi import HTTPException, status

from app.models.vehicle import VehicleProfile
from app.repositories.vehicle_repository import VehicleRepository
from app.schemas.vehicle import (
    VehicleCreate,
    VehiclePresetRead,
    VehicleRead,
    VehicleUpdate,
)
from app.services.vehicle_presets import get_malaysian_presets


class VehicleService:
    """Manages EV garage profiles, battery telemetry, and preset catalogs."""

    def __init__(self, vehicle_repository: VehicleRepository) -> None:
        """Initialize service with an injected vehicle repository."""
        self.vehicle_repo = vehicle_repository

    def get_presets(self) -> list[VehiclePresetRead]:
        """Retrieve verified Malaysian EV factory specification presets."""
        return get_malaysian_presets()

    async def list_vehicles(self, user_id: UUID | None) -> list[VehicleRead]:
        """Fetch all garage vehicles for active user/session."""
        entities = await self.vehicle_repo.list_vehicles(user_id)
        return [self._entity_to_dto(v) for v in entities]

    async def get_vehicle(self, vehicle_id: UUID) -> VehicleRead:
        """Fetch single vehicle profile by UUID or raise 404."""
        entity = await self.vehicle_repo.get_by_id(vehicle_id)
        if entity is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Vehicle profile with ID '{vehicle_id}' was not found.",
            )
        return self._entity_to_dto(entity)

    async def create_vehicle(
        self,
        data: VehicleCreate,
        user_id: UUID | None,
    ) -> VehicleRead:
        """Persist new vehicle to user's garage and return computed range metrics."""
        entity = await self.vehicle_repo.create_vehicle(data, user_id)
        return self._entity_to_dto(entity)

    async def update_vehicle(
        self,
        vehicle_id: UUID,
        data: VehicleUpdate,
    ) -> VehicleRead:
        """Update mutable fields on existing vehicle profile."""
        entity = await self.vehicle_repo.get_by_id(vehicle_id)
        if entity is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Vehicle profile with ID '{vehicle_id}' was not found.",
            )
        updated = await self.vehicle_repo.update_vehicle(entity, data)
        return self._entity_to_dto(updated)

    async def set_primary_vehicle(
        self,
        vehicle_id: UUID,
        user_id: UUID | None,
    ) -> VehicleRead:
        """Set designated vehicle as primary active EV for route planning."""
        entity = await self.vehicle_repo.set_primary_vehicle(vehicle_id, user_id)
        if entity is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Vehicle profile with ID '{vehicle_id}' was not found.",
            )
        return self._entity_to_dto(entity)

    async def delete_vehicle(self, vehicle_id: UUID) -> None:
        """Remove vehicle profile from garage."""
        deleted = await self.vehicle_repo.delete_vehicle(vehicle_id)
        if not deleted:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Vehicle profile with ID '{vehicle_id}' was not found.",
            )

    @staticmethod
    def _entity_to_dto(entity: VehicleProfile) -> VehicleRead:
        """Transform SQLAlchemy VehicleProfile entity to Pydantic VehicleRead with buffer range."""
        safe_range = round(
            entity.usable_range_km * (100 - entity.reserve_soc_percent) / 100.0,
            1,
        )
        return VehicleRead(
            id=entity.id,
            user_id=entity.user_id,
            brand=entity.brand,
            model_name=entity.model_name,
            nickname=entity.nickname,
            battery_capacity_kwh=entity.battery_capacity_kwh,
            usable_range_km=entity.usable_range_km,
            efficiency_wh_per_km=entity.efficiency_wh_per_km,
            max_dc_charge_kw=entity.max_dc_charge_kw,
            connector_type=entity.connector_type,
            reserve_soc_percent=entity.reserve_soc_percent,
            is_primary=entity.is_primary,
            effective_safe_range_km=safe_range,
            created_at=entity.created_at,
            updated_at=entity.updated_at,
        )
