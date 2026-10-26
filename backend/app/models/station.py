"""SQLAlchemy model definition for EV Charging Stations.

Provides spatial point geometry (GeoAlchemy2 / PostGIS) with SQLite fallback,
plug configurations, Malaysian access guides, amenities, and operational metadata.
"""

import uuid
from datetime import datetime
from typing import Any

from geoalchemy2 import Geometry
from geoalchemy2.admin.dialects import sqlite as geo_sqlite
from sqlalchemy import (
    JSON,
    Boolean,
    DateTime,
    Float,
    Index,
    Integer,
    String,
    Text,
    Uuid,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


# Gracefully disable SpatiaLite DDL triggers on standard SQLite (used during unit testing)
def _noop(*_args: Any, **_kwargs: Any) -> None:
    pass


geo_sqlite.after_create = _noop
geo_sqlite.before_create = _noop
geo_sqlite.before_drop = _noop
geo_sqlite.after_drop = _noop


class ChargingStation(Base):
    """Charging station entity supporting PostGIS spatial search and Malaysian metadata."""

    __tablename__ = "charging_stations"

    # Primary Identifier
    id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
        index=True,
    )

    # Core Station Identification
    name: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
        index=True,
    )
    operator_name: Mapped[str | None] = mapped_column(
        String(120),
        nullable=True,
        index=True,
    )

    # Geographic Location & Postal Address
    address: Mapped[str] = mapped_column(
        String(500),
        nullable=False,
    )
    city: Mapped[str] = mapped_column(
        String(100),
        nullable=False,
        index=True,
    )
    state: Mapped[str] = mapped_column(
        String(100),
        nullable=False,
        index=True,
    )
    latitude: Mapped[float] = mapped_column(
        Float,
        nullable=False,
        index=True,
    )
    longitude: Mapped[float] = mapped_column(
        Float,
        nullable=False,
        index=True,
    )

    # Spatial Geometry (PostGIS SRID 4326 Point, falls back to Text on SQLite)
    location: Mapped[Any] = mapped_column(
        Geometry(
            geometry_type="POINT",
            srid=4326,
            spatial_index=False,
        ).with_variant(Text, "sqlite"),
        nullable=True,
    )

    __table_args__ = (Index("idx_charging_stations_location", "location", postgresql_using="gist"),)

    # Technical Charging Specifications
    plug_types: Mapped[list[dict[str, Any]]] = mapped_column(
        JSON,
        nullable=False,
        default=list,
    )
    max_power_kw: Mapped[float] = mapped_column(
        Float,
        nullable=False,
        index=True,
    )

    # Operational Status & Tariffs
    is_available: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=True,
    )
    is_24_hours: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=False,
        index=True,
    )
    charging_cost_myr: Mapped[float] = mapped_column(
        Float,
        nullable=False,
        default=0.0,
    )
    parking_fee_myr: Mapped[float] = mapped_column(
        Float,
        nullable=False,
        default=0.0,
    )

    # Malaysian Navigational Context & Access Guide
    parking_level: Mapped[str | None] = mapped_column(
        String(100),
        nullable=True,
    )
    operation_hours: Mapped[str] = mapped_column(
        String(120),
        nullable=False,
        default="24 Hours",
    )
    amenities: Mapped[list[str]] = mapped_column(
        JSON,
        nullable=False,
        default=list,
    )
    how_to_access: Mapped[list[dict[str, Any]]] = mapped_column(
        JSON,
        nullable=False,
        default=list,
    )
    description: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
    )

    # Community Moderation & Verification
    rating: Mapped[float] = mapped_column(
        Float,
        nullable=False,
        default=0.0,
        index=True,
    )
    review_count: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        default=0,
    )
    source: Mapped[str] = mapped_column(
        String(50),
        nullable=False,
        default="community",
    )
    is_verified: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=True,
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

    def __repr__(self) -> str:
        """Return diagnostic string representation of ChargingStation."""
        return (
            f"<ChargingStation(id={self.id}, name='{self.name}', "
            f"operator='{self.operator_name}', city='{self.city}')>"
        )
