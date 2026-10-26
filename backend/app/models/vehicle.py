"""SQLAlchemy model definition for User EV Vehicle Profiles and Battery Specs."""

import uuid
from datetime import datetime

from sqlalchemy import (
    Boolean,
    DateTime,
    Float,
    ForeignKey,
    Integer,
    String,
    Uuid,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base


class VehicleProfile(Base):
    """User EV specification model supporting battery capacity, range, and charge curves."""

    __tablename__ = "vehicle_profiles"

    # Primary Identifier
    id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
        index=True,
    )

    # User Ownership (Nullable for Guest / Local Demo sessions)
    user_id: Mapped[uuid.UUID | None] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=True,
        index=True,
    )

    # Vehicle Identity
    brand: Mapped[str] = mapped_column(
        String(80),
        nullable=False,
        index=True,
    )
    model_name: Mapped[str] = mapped_column(
        String(120),
        nullable=False,
    )
    nickname: Mapped[str | None] = mapped_column(
        String(100),
        nullable=True,
    )

    # Battery & Range Physics
    battery_capacity_kwh: Mapped[float] = mapped_column(
        Float,
        nullable=False,
    )
    usable_range_km: Mapped[float] = mapped_column(
        Float,
        nullable=False,
    )
    efficiency_wh_per_km: Mapped[float] = mapped_column(
        Float,
        nullable=False,
    )
    max_dc_charge_kw: Mapped[float] = mapped_column(
        Float,
        nullable=False,
    )
    connector_type: Mapped[str] = mapped_column(
        String(40),
        nullable=False,
        default="CCS2",
    )

    # Safety Buffer for Battery-Aware Routing
    reserve_soc_percent: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        default=15,
    )
    is_primary: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=False,
        index=True,
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

    # Relational Association
    user: Mapped["User"] = relationship("User")  # noqa: F821

    def __repr__(self) -> str:
        """Diagnostic string representation of VehicleProfile."""
        return (
            f"<VehicleProfile(id={self.id}, brand='{self.brand}', "
            f"model='{self.model_name}', battery={self.battery_capacity_kwh}kWh)>"
        )
