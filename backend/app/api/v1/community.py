"""REST API router for community station submissions, reviews, and Survei Mikro consensus."""

from uuid import UUID

from fastapi import APIRouter, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db_session
from app.repositories.community_repository import CommunityRepository
from app.repositories.station_repository import StationRepository
from app.schemas.community import (
    MicroSurveyConsensusRead,
    MicroSurveyCreate,
    ReviewCreate,
    ReviewRead,
    StationModerationUpdate,
)
from app.schemas.station import StationCreate, StationRead
from app.services.community_service import CommunityService

router = APIRouter(prefix="/community", tags=["Community"])


def get_community_service(
    session: AsyncSession = Depends(get_db_session),
) -> CommunityService:
    """Dependency provider injecting CommunityService with request-scoped session."""
    community_repo = CommunityRepository(session)
    station_repo = StationRepository(session)
    return CommunityService(community_repo, station_repo)


@router.post(
    "/stations",
    response_model=StationRead,
    status_code=status.HTTP_201_CREATED,
    summary="Submit a new community charging station for verification",
)
async def submit_station(
    payload: StationCreate,
    service: CommunityService = Depends(get_community_service),
) -> StationRead:
    """Submit a hidden or newly observed EV charger for community moderation."""
    return await service.submit_community_station(payload)


@router.get(
    "/stations/pending",
    response_model=list[StationRead],
    summary="List unverified community stations awaiting moderation",
)
async def list_pending_stations(
    service: CommunityService = Depends(get_community_service),
) -> list[StationRead]:
    """Retrieve queue of unverified community submissions for moderators."""
    return await service.list_pending_stations()


@router.patch(
    "/stations/{station_id}/moderate",
    response_model=StationRead | None,
    summary="Approve or reject a pending community station",
)
async def moderate_station(
    station_id: UUID,
    payload: StationModerationUpdate,
    service: CommunityService = Depends(get_community_service),
) -> StationRead | None:
    """Approve (verify onto map) or reject (delete) a submitted charging station."""
    return await service.moderate_station(station_id, payload)


@router.post(
    "/stations/{station_id}/reviews",
    response_model=ReviewRead,
    status_code=status.HTTP_201_CREATED,
    summary="Submit a driver review and visit check-in",
)
async def submit_review(
    station_id: UUID,
    payload: ReviewCreate,
    service: CommunityService = Depends(get_community_service),
) -> ReviewRead:
    """Post driver review and recalculate station aggregate star ratings."""
    return await service.submit_review(station_id, user_id=None, data=payload)


@router.get(
    "/stations/{station_id}/reviews",
    response_model=list[ReviewRead],
    summary="List driver reviews for a station",
)
async def list_reviews(
    station_id: UUID,
    service: CommunityService = Depends(get_community_service),
) -> list[ReviewRead]:
    """Retrieve all submitted reviews and operational notes for a station."""
    return await service.list_reviews(station_id)


@router.post(
    "/stations/{station_id}/micro-survey",
    response_model=MicroSurveyConsensusRead,
    summary="Submit 1-tap Survei Mikro vote",
)
async def submit_micro_survey(
    station_id: UUID,
    payload: MicroSurveyCreate,
    service: CommunityService = Depends(get_community_service),
) -> MicroSurveyConsensusRead:
    """Record 1-tap telemetry and evaluate consensus rules (N >= 3 threshold)."""
    return await service.submit_survey_vote(station_id, user_id=None, data=payload)


@router.get(
    "/stations/{station_id}/micro-survey",
    response_model=MicroSurveyConsensusRead,
    summary="Get current Survei Mikro consensus metrics",
)
async def get_micro_survey_consensus(
    station_id: UUID,
    service: CommunityService = Depends(get_community_service),
) -> MicroSurveyConsensusRead:
    """Retrieve calculated consensus metrics along plug, parking, and access dimensions."""
    return await service.get_survey_consensus(station_id)
