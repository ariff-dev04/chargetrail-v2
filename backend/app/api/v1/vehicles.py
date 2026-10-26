"""REST API endpoints for EV Garage management and vehicle specifications."""

from uuid import UUID

from fastapi import APIRouter, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db_session
from app.repositories.vehicle_repository import VehicleRepository
from app.schemas.vehicle import (
    VehicleCreate,
    VehiclePresetRead,
    VehicleRead,
    VehicleUpdate,
)
from app.services.vehicle_service import VehicleService

router = APIRouter(prefix="/vehicles", tags=["Vehicles"])


def get_vehicle_service(
    session: AsyncSession = Depends(get_db_session),
) -> VehicleService:
    """Dependency provider injecting VehicleService with request session."""
    repo = VehicleRepository(session)
    return VehicleService(repo)


@router.get(
    "/presets",
    response_model=list[VehiclePresetRead],
    summary="List popular Malaysian EV models catalog",
)
def list_presets(
    service: VehicleService = Depends(get_vehicle_service),
) -> list[VehiclePresetRead]:
    """Retrieve verified manufacturer specs for popular Malaysian EV trims."""
    return service.get_presets()


@router.get(
    "",
    response_model=list[VehicleRead],
    summary="List vehicles in user's garage",
)
async def list_vehicles(
    service: VehicleService = Depends(get_vehicle_service),
) -> list[VehicleRead]:
    """Retrieve all garage vehicles for active user/session with computed range buffers."""
    return await service.list_vehicles(user_id=None)


@router.post(
    "",
    response_model=VehicleRead,
    status_code=status.HTTP_201_CREATED,
    summary="Add an electric vehicle to garage",
)
async def create_vehicle(
    payload: VehicleCreate,
    service: VehicleService = Depends(get_vehicle_service),
) -> VehicleRead:
    """Save an EV profile and optionally set as primary active vehicle."""
    return await service.create_vehicle(payload, user_id=None)


@router.get(
    "/{vehicle_id}",
    response_model=VehicleRead,
    summary="Get vehicle profile by ID",
)
async def get_vehicle(
    vehicle_id: UUID,
    service: VehicleService = Depends(get_vehicle_service),
) -> VehicleRead:
    """Retrieve EV specifications and effective safe range."""
    return await service.get_vehicle(vehicle_id)


@router.patch(
    "/{vehicle_id}",
    response_model=VehicleRead,
    summary="Update vehicle specifications or reserve SoC",
)
async def update_vehicle(
    vehicle_id: UUID,
    payload: VehicleUpdate,
    service: VehicleService = Depends(get_vehicle_service),
) -> VehicleRead:
    """Update custom nickname, battery capacity, or safety buffer percent."""
    return await service.update_vehicle(vehicle_id, payload)


@router.post(
    "/{vehicle_id}/select",
    response_model=VehicleRead,
    summary="Set vehicle as primary active EV",
)
async def set_primary_vehicle(
    vehicle_id: UUID,
    service: VehicleService = Depends(get_vehicle_service),
) -> VehicleRead:
    """Set active EV used for journey route simulations and stop planning."""
    return await service.set_primary_vehicle(vehicle_id, user_id=None)


@router.delete(
    "/{vehicle_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Delete vehicle profile from garage",
)
async def delete_vehicle(
    vehicle_id: UUID,
    service: VehicleService = Depends(get_vehicle_service),
) -> None:
    """Remove EV from garage."""
    await service.delete_vehicle(vehicle_id)
