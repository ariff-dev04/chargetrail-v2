"""Repository for VehicleProfile entity management and multi-car garage operations."""

from uuid import UUID

from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.vehicle import VehicleProfile
from app.schemas.vehicle import VehicleCreate, VehicleUpdate


class VehicleRepository:
    """Encapsulates database operations for electric vehicle garage profiles."""

    def __init__(self, session: AsyncSession) -> None:
        """Initialize repository with an active asynchronous database session."""
        self.session = session

    async def list_vehicles(self, user_id: UUID | None) -> list[VehicleProfile]:
        """Fetch all vehicles owned by a user or in guest session, primary first."""
        query = select(VehicleProfile)
        if user_id is not None:
            query = query.where(VehicleProfile.user_id == user_id)
        else:
            query = query.where(VehicleProfile.user_id.is_(None))

        query = query.order_by(
            VehicleProfile.is_primary.desc(),
            VehicleProfile.created_at.desc(),
        )
        result = await self.session.execute(query)
        return list(result.scalars().all())

    async def get_by_id(self, vehicle_id: UUID) -> VehicleProfile | None:
        """Retrieve vehicle by unique profile UUID."""
        query = select(VehicleProfile).where(VehicleProfile.id == vehicle_id)
        result = await self.session.execute(query)
        return result.scalar_one_or_none()

    async def create_vehicle(
        self,
        data: VehicleCreate,
        user_id: UUID | None,
    ) -> VehicleProfile:
        """Create an EV profile, unsetting existing primaries if this vehicle is primary."""
        existing_vehicles = await self.list_vehicles(user_id)
        make_primary = data.is_primary or len(existing_vehicles) == 0

        if make_primary:
            await self._clear_primary_flags(user_id)

        vehicle_dict = data.model_dump()
        vehicle_dict["user_id"] = user_id
        vehicle_dict["is_primary"] = make_primary

        vehicle = VehicleProfile(**vehicle_dict)
        self.session.add(vehicle)
        await self.session.commit()
        await self.session.refresh(vehicle)
        return vehicle

    async def update_vehicle(
        self,
        vehicle: VehicleProfile,
        data: VehicleUpdate,
    ) -> VehicleProfile:
        """Update mutable specifications on an existing EV profile."""
        if data.is_primary is True:
            await self._clear_primary_flags(vehicle.user_id)
            vehicle.is_primary = True

        if data.nickname is not None:
            vehicle.nickname = data.nickname.strip() or None
        if data.battery_capacity_kwh is not None:
            vehicle.battery_capacity_kwh = data.battery_capacity_kwh
        if data.usable_range_km is not None:
            vehicle.usable_range_km = data.usable_range_km
        if data.efficiency_wh_per_km is not None:
            vehicle.efficiency_wh_per_km = data.efficiency_wh_per_km
        if data.max_dc_charge_kw is not None:
            vehicle.max_dc_charge_kw = data.max_dc_charge_kw
        if data.connector_type is not None:
            vehicle.connector_type = data.connector_type.strip()
        if data.reserve_soc_percent is not None:
            vehicle.reserve_soc_percent = data.reserve_soc_percent

        await self.session.commit()
        await self.session.refresh(vehicle)
        return vehicle

    async def set_primary_vehicle(
        self,
        vehicle_id: UUID,
        user_id: UUID | None,
    ) -> VehicleProfile | None:
        """Designate target vehicle as the active primary vehicle for route simulation."""
        vehicle = await self.get_by_id(vehicle_id)
        if vehicle is None:
            return None

        await self._clear_primary_flags(user_id)
        vehicle.is_primary = True
        await self.session.commit()
        await self.session.refresh(vehicle)
        return vehicle

    async def delete_vehicle(self, vehicle_id: UUID) -> bool:
        """Delete vehicle profile, automatically promoting another vehicle to primary if needed."""
        vehicle = await self.get_by_id(vehicle_id)
        if vehicle is None:
            return False

        was_primary = vehicle.is_primary
        user_id = vehicle.user_id
        await self.session.delete(vehicle)
        await self.session.commit()

        if was_primary:
            remaining = await self.list_vehicles(user_id)
            if remaining:
                remaining[0].is_primary = True
                await self.session.commit()

        return True

    async def _clear_primary_flags(self, user_id: UUID | None) -> None:
        """Clear primary flag on all other vehicles owned by user/session."""
        stmt = update(VehicleProfile).values(is_primary=False)
        if user_id is not None:
            stmt = stmt.where(VehicleProfile.user_id == user_id)
        else:
            stmt = stmt.where(VehicleProfile.user_id.is_(None))
        await self.session.execute(stmt)
