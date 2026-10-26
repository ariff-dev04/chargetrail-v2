"""REST API router for Charging Station discovery, detail inspection, and seeding."""

from uuid import UUID

from fastapi import APIRouter, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db_session
from app.repositories.station_repository import StationRepository
from app.schemas.station import (
    SeedResponse,
    StationFilterParams,
    StationRead,
)
from app.services.station_service import StationService

router = APIRouter(prefix="/stations", tags=["Stations"])


def get_station_service(
    session: AsyncSession = Depends(get_db_session),
) -> StationService:
    """Dependency provider instantiating StationService with current session."""
    repository = StationRepository(session)
    return StationService(repository)


@router.get(
    "",
    response_model=list[StationRead],
    summary="List charging stations with viewport or proximity filters",
)
async def list_stations(
    filters: StationFilterParams = Depends(),
    service: StationService = Depends(get_station_service),
) -> list[StationRead]:
    """Retrieve charging stations filtered by bounding box, radius, power, or amenities."""
    return await service.get_stations(filters)


@router.get(
    "/{station_id}",
    response_model=StationRead,
    summary="Get charging station details by ID",
)
async def get_station_by_id(
    station_id: UUID,
    service: StationService = Depends(get_station_service),
) -> StationRead:
    """Retrieve complete station metadata including step-by-step parking access instructions."""
    return await service.get_station_by_id(station_id)


@router.post(
    "/seed-sample",
    response_model=SeedResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Seed realistic Malaysian charging stations dataset",
)
async def seed_sample_stations(
    service: StationService = Depends(get_station_service),
) -> SeedResponse:
    """Idempotently insert verified Malaysian EV charging station samples."""
    return await service.seed_sample_stations()
