"""Repository handling community submissions, reviews, and micro-survey consensus votes."""

from uuid import UUID

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.community import MicroSurveyVote, StationReview
from app.models.station import ChargingStation
from app.schemas.community import MicroSurveyCreate, ReviewCreate
from app.schemas.station import StationCreate


class CommunityRepository:
    """Encapsulates database operations for community reviews, stations, and survey votes."""

    def __init__(self, session: AsyncSession) -> None:
        """Initialize repository with an active asynchronous database session."""
        self.session = session

    async def create_community_station(self, data: StationCreate) -> ChargingStation:
        """Persist an unverified community-submitted charging station for moderation."""
        station_dict = data.model_dump()
        station_dict["plug_types"] = [
            p.model_dump() if hasattr(p, "model_dump") else p for p in data.plug_types
        ]
        station_dict["how_to_access"] = [
            s.model_dump() if hasattr(s, "model_dump") else s for s in data.how_to_access
        ]
        station_dict["location"] = f"SRID=4326;POINT({data.longitude} {data.latitude})"
        station_dict["source"] = "community"
        station_dict["is_verified"] = False

        station = ChargingStation(**station_dict)
        self.session.add(station)
        await self.session.commit()
        await self.session.refresh(station)
        return station

    async def list_pending_stations(self) -> list[ChargingStation]:
        """Fetch all unverified stations awaiting moderator approval."""
        query = (
            select(ChargingStation)
            .where(ChargingStation.is_verified.is_(False))
            .order_by(ChargingStation.created_at.desc())
        )
        result = await self.session.execute(query)
        return list(result.scalars().all())

    async def moderate_station(
        self,
        station_id: UUID,
        approve: bool,
    ) -> ChargingStation | None:
        """Approve and verify station onto live map, or reject and remove from database."""
        query = select(ChargingStation).where(ChargingStation.id == station_id)
        result = await self.session.execute(query)
        station = result.scalar_one_or_none()
        if station is None:
            return None

        if approve:
            station.is_verified = True
            await self.session.commit()
            await self.session.refresh(station)
            return station

        await self.session.delete(station)
        await self.session.commit()
        return None

    async def add_review(
        self,
        station_id: UUID,
        user_id: UUID | None,
        data: ReviewCreate,
    ) -> StationReview:
        """Persist driver review and update aggregate station rating."""
        review = StationReview(
            station_id=station_id,
            user_id=user_id,
            author_name=data.author_name.strip() or "EV Driver",
            rating=data.rating,
            comment=data.comment.strip(),
            working_status=data.working_status.strip(),
            wait_time_minutes=data.wait_time_minutes,
        )
        self.session.add(review)
        await self.session.commit()
        await self.session.refresh(review)

        # Recalculate station aggregated rating & review count
        await self.recalculate_station_rating(station_id)
        return review

    async def list_reviews(self, station_id: UUID) -> list[StationReview]:
        """Fetch all submitted reviews for a specific station, newest first."""
        query = (
            select(StationReview)
            .where(StationReview.station_id == station_id)
            .order_by(StationReview.created_at.desc())
        )
        result = await self.session.execute(query)
        return list(result.scalars().all())

    async def recalculate_station_rating(self, station_id: UUID) -> None:
        """Recompute average driver rating and total review count on ChargingStation."""
        query = select(
            func.coalesce(func.avg(StationReview.rating), 0.0),
            func.count(StationReview.id),
        ).where(StationReview.station_id == station_id)

        result = await self.session.execute(query)
        avg_rating, count = result.one()

        station_query = select(ChargingStation).where(ChargingStation.id == station_id)
        station_res = await self.session.execute(station_query)
        station = station_res.scalar_one_or_none()

        if station is not None:
            station.rating = round(float(avg_rating), 1)
            station.review_count = int(count)
            await self.session.commit()

    async def add_survey_vote(
        self,
        station_id: UUID,
        user_id: UUID | None,
        data: MicroSurveyCreate,
    ) -> MicroSurveyVote:
        """Record a single 1-tap community micro-survey vote."""
        vote = MicroSurveyVote(
            station_id=station_id,
            user_id=user_id,
            plug_working_status=data.plug_working_status.strip().lower(),
            parking_fee_status=data.parking_fee_status.strip().lower(),
            access_difficulty=data.access_difficulty.strip().lower(),
        )
        self.session.add(vote)
        await self.session.commit()
        await self.session.refresh(vote)
        return vote

    async def get_survey_votes(self, station_id: UUID) -> list[MicroSurveyVote]:
        """Retrieve all recorded micro-survey votes for a station."""
        query = select(MicroSurveyVote).where(MicroSurveyVote.station_id == station_id)
        result = await self.session.execute(query)
        return list(result.scalars().all())
