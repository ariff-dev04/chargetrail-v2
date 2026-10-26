"""Service layer orchestrating community contributions, reviews, and Survei Mikro consensus."""

from collections import Counter
from uuid import UUID

from fastapi import HTTPException, status

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
from app.services.station_service import StationService


class CommunityService:
    """Manages community station submissions, driver check-ins, and consensus threshold logic."""

    def __init__(
        self,
        community_repository: CommunityRepository,
        station_repository: StationRepository,
    ) -> None:
        """Initialize service with injected repositories."""
        self.community_repo = community_repository
        self.station_repo = station_repository

    async def submit_community_station(self, data: StationCreate) -> StationRead:
        """Create an unverified community station entry awaiting moderator review."""
        station = await self.community_repo.create_community_station(data)
        return StationService._entity_to_dto(station)

    async def list_pending_stations(self) -> list[StationRead]:
        """Fetch all unverified community station submissions."""
        pending = await self.community_repo.list_pending_stations()
        return [StationService._entity_to_dto(s) for s in pending]

    async def moderate_station(
        self,
        station_id: UUID,
        update: StationModerationUpdate,
    ) -> StationRead | None:
        """Approve and verify station onto live map, or reject and delete."""
        station = await self.station_repo.get_by_id(station_id)
        if station is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Station with ID '{station_id}' was not found.",
            )

        updated = await self.community_repo.moderate_station(station_id, update.approve)
        return StationService._entity_to_dto(updated) if updated is not None else None

    async def submit_review(
        self,
        station_id: UUID,
        user_id: UUID | None,
        data: ReviewCreate,
    ) -> ReviewRead:
        """Record driver review and automatically recalculate station star rating."""
        station = await self.station_repo.get_by_id(station_id)
        if station is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Station with ID '{station_id}' was not found.",
            )

        review = await self.community_repo.add_review(station_id, user_id, data)
        return ReviewRead.model_validate(review)

    async def list_reviews(self, station_id: UUID) -> list[ReviewRead]:
        """Retrieve all driver reviews and check-ins for a station."""
        reviews = await self.community_repo.list_reviews(station_id)
        return [ReviewRead.model_validate(r) for r in reviews]

    async def submit_survey_vote(
        self,
        station_id: UUID,
        user_id: UUID | None,
        data: MicroSurveyCreate,
    ) -> MicroSurveyConsensusRead:
        """Record 1-tap micro-survey vote and evaluate consensus rules."""
        station = await self.station_repo.get_by_id(station_id)
        if station is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Station with ID '{station_id}' was not found.",
            )

        await self.community_repo.add_survey_vote(station_id, user_id, data)
        return await self.get_survey_consensus(station_id)

    async def get_survey_consensus(self, station_id: UUID) -> MicroSurveyConsensusRead:
        """Compute consensus metrics across submitted micro-survey votes for a station."""
        station = await self.station_repo.get_by_id(station_id)
        if station is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Station with ID '{station_id}' was not found.",
            )

        votes = await self.community_repo.get_survey_votes(station_id)
        total_votes = len(votes)
        threshold = 3

        plug_counter: Counter[str] = Counter()
        parking_counter: Counter[str] = Counter()
        access_counter: Counter[str] = Counter()

        for v in votes:
            plug_counter[v.plug_working_status] += 1
            parking_counter[v.parking_fee_status] += 1
            access_counter[v.access_difficulty] += 1

        consensus_plug = None
        consensus_parking = None
        consensus_access = None
        auto_updated = False

        # 1. Plug Status Consensus Evaluation
        for status_val, count in plug_counter.most_common(1):
            if count >= threshold:
                consensus_plug = status_val
                if status_val == "out_of_order" and station.is_available:
                    station.is_available = False
                    auto_updated = True
                elif status_val == "working" and not station.is_available:
                    station.is_available = True
                    auto_updated = True

        # 2. Parking Fee Consensus Evaluation
        for status_val, count in parking_counter.most_common(1):
            if count >= threshold:
                consensus_parking = status_val
                if status_val == "free" and station.parking_fee_myr > 0.0:
                    station.parking_fee_myr = 0.0
                    auto_updated = True

        # 3. Access Navigation Consensus Evaluation
        for status_val, count in access_counter.most_common(1):
            if count >= threshold:
                consensus_access = status_val

        if auto_updated:
            await self.community_repo.session.commit()

        return MicroSurveyConsensusRead(
            station_id=station_id,
            total_votes=total_votes,
            consensus_threshold=threshold,
            consensus_plug_status=consensus_plug,
            consensus_parking_status=consensus_parking,
            consensus_access_difficulty=consensus_access,
            station_auto_updated=auto_updated,
        )
