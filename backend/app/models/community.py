"""SQLAlchemy models and Pydantic schemas for Reviews, Survei Mikro, and Edit Consensus."""

import uuid
from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict
from sqlalchemy import (
    JSON,
    Boolean,
    DateTime,
    Float,
    ForeignKey,
    Integer,
    String,
    Text,
    Uuid,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base
from app.models.station import ChargingStation


class StationReview(Base):
    """Driver review and operational check-in record for an EV charging station."""

    __tablename__ = "station_reviews"

    id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True), primary_key=True, default=uuid.uuid4, index=True
    )
    station_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("charging_stations.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    user_id: Mapped[uuid.UUID | None] = mapped_column(
        Uuid(as_uuid=True), ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True
    )
    author_name: Mapped[str] = mapped_column(String(120), nullable=False, default="EV Driver")
    rating: Mapped[int] = mapped_column(Integer, nullable=False)
    comment: Mapped[str] = mapped_column(Text, nullable=False)
    working_status: Mapped[str] = mapped_column(String(40), nullable=False, default="working")
    wait_time_minutes: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )

    station: Mapped["ChargingStation"] = relationship("ChargingStation")

    def __repr__(self) -> str:
        return f"<StationReview(id={self.id}, station_id={self.station_id}, rating={self.rating})>"


class MicroSurveyVote(Base):
    """Fast 1-tap community micro-survey consensus submission."""

    __tablename__ = "micro_survey_votes"

    id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True), primary_key=True, default=uuid.uuid4, index=True
    )
    station_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("charging_stations.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    user_id: Mapped[uuid.UUID | None] = mapped_column(
        Uuid(as_uuid=True), ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True
    )
    plug_working_status: Mapped[str] = mapped_column(String(40), nullable=False)
    parking_fee_status: Mapped[str] = mapped_column(String(40), nullable=False)
    access_difficulty: Mapped[str] = mapped_column(String(40), nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )

    station: Mapped["ChargingStation"] = relationship("ChargingStation")

    def __repr__(self) -> str:
        return f"<MicroSurveyVote(id={self.id}, station_id={self.station_id})>"


class StationEditProposal(Base):
    """Community-submitted edit proposal for an existing charging station with consensus tracking."""

    __tablename__ = "station_edit_proposals"

    id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True), primary_key=True, default=uuid.uuid4, index=True
    )
    station_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("charging_stations.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    user_id: Mapped[uuid.UUID | None] = mapped_column(
        Uuid(as_uuid=True), ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True
    )
    author_name: Mapped[str] = mapped_column(String(120), nullable=False, default="EV Driver")

    parking_level: Mapped[str | None] = mapped_column(String(100), nullable=True)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    price_per_kwh: Mapped[float | None] = mapped_column(Float, nullable=True)
    max_power_kw: Mapped[float | None] = mapped_column(Float, nullable=True)
    amenities: Mapped[list[str] | None] = mapped_column(JSON, nullable=True)
    is_operational: Mapped[bool | None] = mapped_column(Boolean, nullable=True)

    confirm_votes: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    reject_votes: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    status: Mapped[str] = mapped_column(String(30), nullable=False, default="pending", index=True)
    voters: Mapped[list[str]] = mapped_column(JSON, nullable=False, default=list)

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now(), onupdate=func.now()
    )

    station: Mapped["ChargingStation"] = relationship("ChargingStation")

    def __repr__(self) -> str:
        return f"<StationEditProposal(id={self.id}, station_id={self.station_id}, status='{self.status}')>"


# Pydantic schemas for edit proposals and consensus voting
class StationEditProposalCreate(BaseModel):
    parking_level: str | None = None
    description: str | None = None
    price_per_kwh: float | None = None
    max_power_kw: float | None = None
    amenities: list[str] | None = None
    is_operational: bool | None = None
    author_name: str = "EV Driver"


class StationEditProposalRead(BaseModel):
    id: uuid.UUID
    station_id: uuid.UUID
    user_id: uuid.UUID | None = None
    author_name: str
    parking_level: str | None = None
    description: str | None = None
    price_per_kwh: float | None = None
    max_power_kw: float | None = None
    amenities: list[str] | None = None
    is_operational: bool | None = None
    confirm_votes: int = 0
    reject_votes: int = 0
    status: str = "pending"
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


class StationEditVoteCreate(BaseModel):
    vote: Literal["confirm", "reject"] = "confirm"
    fast_track_approve: bool = False
    voter_token: str | None = None


# Ensure ChargingStation supports is_community_verified column
if not hasattr(ChargingStation, "is_community_verified"):
    ChargingStation.is_community_verified = mapped_column(Boolean, nullable=False, default=False)
