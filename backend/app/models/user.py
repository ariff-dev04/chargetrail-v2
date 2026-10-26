"""SQLAlchemy models for User accounts and Saved Station bookmarks."""

import uuid
from datetime import datetime

from sqlalchemy import (
    Boolean,
    DateTime,
    ForeignKey,
    String,
    UniqueConstraint,
    Uuid,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base


class User(Base):
    """User profile entity with authentication credentials and vehicle charging preferences."""

    __tablename__ = "users"

    # Primary Identifier
    id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
        index=True,
    )

    # Authentication & Personal Attributes
    email: Mapped[str] = mapped_column(
        String(255),
        unique=True,
        index=True,
        nullable=False,
    )
    hashed_password: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
    )
    full_name: Mapped[str] = mapped_column(
        String(150),
        nullable=False,
    )
    phone_number: Mapped[str | None] = mapped_column(
        String(40),
        nullable=True,
    )

    # EV Charging Preferences
    preferred_connector: Mapped[str] = mapped_column(
        String(50),
        nullable=False,
        default="CCS2",
    )
    role: Mapped[str] = mapped_column(
        String(30),
        nullable=False,
        default="user",
    )
    is_active: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=True,
    )

    # Audit Timestamps
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
        onupdate=func.now(),
    )

    # Relational Associations
    saved_bookmarks: Mapped[list["SavedStation"]] = relationship(
        "SavedStation",
        back_populates="user",
        cascade="all, delete-orphan",
    )

    def __repr__(self) -> str:
        """Return diagnostic string representation of User."""
        return f"<User(id={self.id}, email='{self.email}', name='{self.full_name}')>"


class SavedStation(Base):
    """Bookmarked charging station association for personalized quick access."""

    __tablename__ = "saved_stations"

    __table_args__ = (UniqueConstraint("user_id", "station_id", name="uq_user_saved_station"),)

    # Primary Identifier
    id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
        index=True,
    )

    # Foreign Key References
    user_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    station_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("charging_stations.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    # Timestamp
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
    )

    # Relational Associations
    user: Mapped["User"] = relationship("User", back_populates="saved_bookmarks")
    station: Mapped["ChargingStation"] = relationship("ChargingStation")  # noqa: F821

    def __repr__(self) -> str:
        """Return diagnostic string representation of SavedStation."""
        return f"<SavedStation(user_id={self.user_id}, station_id={self.station_id})>"
