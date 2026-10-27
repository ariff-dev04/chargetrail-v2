"""REST API router for Charging Station discovery, detail inspection, and seeding."""

from uuid import UUID

from fastapi import APIRouter, Depends, status
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db_session
from app.repositories.station_repository import StationRepository
from app.schemas.station import (
    SeedResponse,
    StationCreate,
    StationFilterParams,
    StationRead,
)
from app.services.osm_harvester_service import OsmHarvesterService
from app.services.station_service import StationService

router = APIRouter(prefix="/stations", tags=["Stations"])


class HarvestViewportRequest(BaseModel):
    """Payload for triggering live OpenStreetMap viewport harvesting."""

    min_lat: float
    min_lng: float
    max_lat: float
    max_lng: float
    center_lat: float | None = None
    center_lng: float | None = None


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
    results = await service.get_stations(filters)

    # If DB currently has 0 stations for the queried spatial bounds, auto-trigger live OSM harvest
    if not results and (filters.min_lat is not None or filters.lat is not None):
        min_lat = (
            filters.min_lat
            if filters.min_lat is not None
            else (filters.lat - (filters.radius_km / 111.0))
        )
        max_lat = (
            filters.max_lat
            if filters.max_lat is not None
            else (filters.lat + (filters.radius_km / 111.0))
        )
        min_lng = (
            filters.min_lng
            if filters.min_lng is not None
            else (filters.lng - (filters.radius_km / 111.0))
        )
        max_lng = (
            filters.max_lng
            if filters.max_lng is not None
            else (filters.lng + (filters.radius_km / 111.0))
        )
        c_lat = filters.lat or (min_lat + max_lat) / 2.0
        c_lng = filters.lng or (min_lng + max_lng) / 2.0

        await OsmHarvesterService.harvest_viewport(
            repository=service.repository,
            min_lat=min_lat,
            min_lng=min_lng,
            max_lat=max_lat,
            max_lng=max_lng,
            center_lat=c_lat,
            center_lng=c_lng,
        )
        results = await service.get_stations(filters)

    return results


@router.post(
    "/upsert-batch",
    response_model=list[StationRead],
    status_code=status.HTTP_200_OK,
    summary="Batch upsert externally discovered OSM stations into database",
)
async def upsert_batch_stations(
    stations_in: list[StationCreate],
    service: StationService = Depends(get_station_service),
) -> list[StationRead]:
    """Persist multiple harvested OSM stations to local database."""
    return await service.upsert_batch_stations(stations_in)


@router.post(
    "/harvest-viewport",
    response_model=list[StationRead],
    status_code=status.HTTP_200_OK,
    summary="Trigger live OpenStreetMap harvest for given viewport bounds",
)
async def harvest_viewport(
    req: HarvestViewportRequest,
    service: StationService = Depends(get_station_service),
) -> list[StationRead]:
    """Harvest live OpenStreetMap chargers in viewport and return persisted records."""
    entities = await OsmHarvesterService.harvest_viewport(
        repository=service.repository,
        min_lat=req.min_lat,
        min_lng=req.min_lng,
        max_lat=req.max_lat,
        max_lng=req.max_lng,
        center_lat=req.center_lat,
        center_lng=req.center_lng,
    )
    return [service._entity_to_dto(e) for e in entities]


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


@router.post(
    "/upsert-external",
    response_model=StationRead,
    status_code=status.HTTP_200_OK,
    summary="Idempotently upsert an external OSM station upon interaction",
)
async def upsert_external_station(
    station_in: StationCreate,
    service: StationService = Depends(get_station_service),
) -> StationRead:
    """Save or return existing station when driver interacts with an external OSM pin."""
    return await service.upsert_external_station(station_in)
