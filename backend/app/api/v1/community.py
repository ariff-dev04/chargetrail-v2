"""REST API router for community station submissions, reviews, Survei Mikro, and edit proposals."""

import uuid
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from pydantic.fields import FieldInfo
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db_session
from app.core.security import decode_access_token
from app.models.community import (
    StationEditProposal,
    StationEditProposalCreate,
    StationEditProposalRead,
    StationEditVoteCreate,
)
from app.models.station import ChargingStation
from app.models.user import User
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
from app.services.station_service import StationService

router = APIRouter(prefix="/community", tags=["Community"])
bearer_scheme = HTTPBearer(auto_error=False)

# Ensure StationRead supports price_per_kwh and is_community_verified
if "price_per_kwh" not in StationRead.model_fields:
    StationRead.model_fields["price_per_kwh"] = FieldInfo(annotation=float | None, default=None)
    StationRead.model_fields["is_community_verified"] = FieldInfo(annotation=bool, default=False)
    StationRead.model_rebuild(force=True)

_orig_entity_to_dto = StationService._entity_to_dto


def _patched_entity_to_dto(entity: ChargingStation) -> StationRead:
    dto = _orig_entity_to_dto(entity)
    dto.is_community_verified = bool(getattr(entity, "is_community_verified", False))
    dto.price_per_kwh = entity.charging_cost_myr
    return dto


StationService._entity_to_dto = staticmethod(_patched_entity_to_dto)


def get_community_service(
    session: AsyncSession = Depends(get_db_session),
) -> CommunityService:
    """Dependency provider injecting CommunityService with request-scoped session."""
    community_repo = CommunityRepository(session)
    station_repo = StationRepository(session)
    return CommunityService(community_repo, station_repo)


async def get_optional_user(
    auth: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
    session: AsyncSession = Depends(get_db_session),
) -> User | None:
    """Resolve optional authenticated user from Bearer JWT token."""
    if not auth:
        return None
    try:
        data = decode_access_token(auth.credentials)
        uid = UUID(str(data.get("sub", "")))
        return await session.get(User, uid)
    except Exception:
        return None


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


@router.post(
    "/stations/{station_id}/suggest-edit",
    response_model=StationEditProposalRead,
    status_code=status.HTTP_201_CREATED,
    summary="Suggest edits for an existing charging station",
)
async def suggest_station_edit(
    station_id: UUID,
    payload: StationEditProposalCreate,
    session: AsyncSession = Depends(get_db_session),
    user: User | None = Depends(get_optional_user),
) -> StationEditProposalRead:
    """Create pending edit proposal for station access, level, tariff, or status."""
    st = await session.get(ChargingStation, station_id)
    if not st:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Charging station not found"
        )

    proposal = StationEditProposal(
        station_id=station_id,
        user_id=user.id if user else None,
        author_name=user.full_name if user and user.full_name else payload.author_name,
        parking_level=payload.parking_level,
        description=payload.description,
        price_per_kwh=payload.price_per_kwh,
        max_power_kw=payload.max_power_kw,
        amenities=payload.amenities,
        is_operational=payload.is_operational,
        status="pending",
        confirm_votes=0,
        reject_votes=0,
        voters=[],
    )
    session.add(proposal)
    await session.commit()
    await session.refresh(proposal)
    return StationEditProposalRead.model_validate(proposal)


@router.get(
    "/stations/{station_id}/pending-edits",
    response_model=list[StationEditProposalRead],
    summary="List pending edit proposals for a station",
)
async def get_pending_station_edits(
    station_id: UUID,
    session: AsyncSession = Depends(get_db_session),
) -> list[StationEditProposalRead]:
    """Retrieve all pending edit proposals for a station awaiting consensus voting."""
    stmt = (
        select(StationEditProposal)
        .where(
            StationEditProposal.station_id == station_id, StationEditProposal.status == "pending"
        )
        .order_by(StationEditProposal.created_at.desc())
    )
    res = await session.execute(stmt)
    return [StationEditProposalRead.model_validate(p) for p in res.scalars().all()]


@router.post(
    "/edits/{edit_id}/vote",
    response_model=StationEditProposalRead,
    summary="Vote on a suggested station edit proposal",
)
async def vote_station_edit(
    edit_id: UUID,
    payload: StationEditVoteCreate,
    session: AsyncSession = Depends(get_db_session),
    user: User | None = Depends(get_optional_user),
) -> StationEditProposalRead:
    """Cast confirm/reject vote or fast-track approve edit; auto-mutate station on consensus."""
    proposal = await session.get(StationEditProposal, edit_id)
    if not proposal:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Edit proposal not found")

    voter_id = str(user.id) if user else (payload.voter_token or str(uuid.uuid4()))
    if voter_id not in (proposal.voters or []):
        proposal.voters = [*list(proposal.voters or []), voter_id]

    if payload.fast_track_approve:
        proposal.confirm_votes += 1
        proposal.status = "approved"
    else:
        if payload.vote == "confirm":
            proposal.confirm_votes += 1
        else:
            proposal.reject_votes += 1

        if proposal.confirm_votes >= 3 and proposal.confirm_votes > proposal.reject_votes:
            proposal.status = "approved"
        elif proposal.reject_votes >= 3 and proposal.reject_votes > proposal.confirm_votes:
            proposal.status = "rejected"

    if proposal.status == "approved":
        st = await session.get(ChargingStation, proposal.station_id)
        if st:
            if proposal.parking_level is not None:
                st.parking_level = proposal.parking_level
            if proposal.description is not None:
                st.description = proposal.description
            if proposal.price_per_kwh is not None:
                st.charging_cost_myr = proposal.price_per_kwh
            if proposal.max_power_kw is not None:
                st.max_power_kw = proposal.max_power_kw
            if proposal.amenities is not None:
                st.amenities = proposal.amenities
            if proposal.is_operational is not None:
                st.is_available = proposal.is_operational
            st.is_community_verified = True

    await session.commit()
    await session.refresh(proposal)
    return StationEditProposalRead.model_validate(proposal)


@router.get(
    "/moderation-queue",
    response_model=list[StationEditProposalRead],
    summary="List all pending edit proposals for moderators",
)
async def list_moderation_queue(
    session: AsyncSession = Depends(get_db_session),
) -> list[StationEditProposalRead]:
    """Retrieve all pending edit proposals awaiting review or fast-track approval."""
    stmt = (
        select(StationEditProposal)
        .where(StationEditProposal.status == "pending")
        .order_by(StationEditProposal.created_at.desc())
    )
    res = await session.execute(stmt)
    return [StationEditProposalRead.model_validate(p) for p in res.scalars().all()]
