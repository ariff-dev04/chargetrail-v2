"""REST API endpoints for Malaysian place geocoding and battery route planning."""

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.database import get_db_session
from app.repositories.station_repository import StationRepository
from app.repositories.vehicle_repository import VehicleRepository
from app.schemas.routing import (
    PlaceSuggestion,
    RoutePlanRequest,
    RoutePlanResponse,
)
from app.services.geocoding_service import GeocodingService
from app.services.osrm_client import OsrmClient
from app.services.route_planner_service import RoutePlannerService

router = APIRouter(prefix="/routing", tags=["Routing"])
settings = get_settings()

geocoding_service = GeocodingService()


def get_route_planner_service(
    session: AsyncSession = Depends(get_db_session),
) -> RoutePlannerService:
    """Dependency provider injecting RoutePlannerService with active session and OSRM client."""
    station_repo = StationRepository(session)
    vehicle_repo = VehicleRepository(session)
    osrm_client = OsrmClient(base_url=settings.OSRM_BASE_URL)
    return RoutePlannerService(station_repo, vehicle_repo, osrm_client)


@router.get(
    "/places",
    response_model=list[PlaceSuggestion],
    summary="Search Malaysian landmarks, expressway interchanges, and cities",
)
async def search_places(
    q: str = "",
    limit: int = 8,
) -> list[PlaceSuggestion]:
    """Retrieve geocoded coordinates for origins and destinations."""
    return await geocoding_service.search_places(query=q, limit=limit)


@router.post(
    "/plan",
    response_model=RoutePlanResponse,
    summary="Plan battery-aware route with corridor charging recommendations",
)
async def plan_route(
    payload: RoutePlanRequest,
    service: RoutePlannerService = Depends(get_route_planner_service),
) -> RoutePlanResponse:
    """Simulate battery State of Charge depletion along highway corridor and optimize charging stops."""
    return await service.plan_route(payload)
