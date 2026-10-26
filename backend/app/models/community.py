"""SQLAlchemy models for Station Reviews and Survei Mikro consensus voting."""

import uuid
from datetime import datetime

from sqlalchemy import (
    DateTime,
    ForeignKey,
    Integer,
    String,
    Text,
    Uuid,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base


class StationReview(Base):
    """Driver review and operational check-in record for an EV charging station."""

    __tablename__ = "station_reviews"

    # Primary Identifier
    id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
        index=True,
    )

    # Associated Charging Station & Author
    station_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("charging_stations.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    user_id: Mapped[uuid.UUID | None] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    author_name: Mapped[str] = mapped_column(
        String(120),
        nullable=False,
        default="EV Driver",
    )

    # Rating & Feedback Content
    rating: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
    )
    comment: Mapped[str] = mapped_column(
        Text,
        nullable=False,
    )
    working_status: Mapped[str] = mapped_column(
        String(40),
        nullable=False,
        default="working",
    )
    wait_time_minutes: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        default=0,
    )

    # Audit Timestamp
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
    )

    # Relational Association
    station: Mapped["ChargingStation"] = relationship("ChargingStation")  # noqa: F821

    def __repr__(self) -> str:
        """Diagnostic string representation of StationReview."""
        return (
            f"<StationReview(id={self.id}, station_id={self.station_id}, "
            f"rating={self.rating}, author='{self.author_name}')>"
        )


class MicroSurveyVote(Base):
    """Fast 1-tap community micro-survey consensus submission."""

    __tablename__ = "micro_survey_votes"

    # Primary Identifier
    id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
        index=True,
    )

    # Target Station & Submitter
    station_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("charging_stations.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    user_id: Mapped[uuid.UUID | None] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )

    # 1-Tap Consensus Telemetry Dimensions
    plug_working_status: Mapped[str] = mapped_column(
        String(40),
        nullable=False,
    )
    parking_fee_status: Mapped[str] = mapped_column(
        String(40),
        nullable=False,
    )
    access_difficulty: Mapped[str] = mapped_column(
        String(40),
        nullable=False,
    )

    # Submission Timestamp
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
    )

    # Relational Association
    station: Mapped["ChargingStation"] = relationship("ChargingStation")  # noqa: F821

    def __repr__(self) -> str:
        """Diagnostic string representation of MicroSurveyVote."""
        return (
            f"<MicroSurveyVote(id={self.id}, station_id={self.station_id}, "
            f"status='{self.plug_working_status}')>"
        )
