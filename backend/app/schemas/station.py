"""Pydantic schemas for EV Charging Station domain entities and query filters.

Provides request/response schemas, plug configurations, Malaysian access steps,
and spatial filtering parameter contracts.
"""

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


class PlugInfo(BaseModel):
    """Schema representing an EV charging connector standard and output rating."""

    type: str = Field(
        description="Connector standard (e.g., CCS2, Type 2, CHAdeMO)",
        examples=["CCS2"],
    )
    power_kw: float = Field(
        gt=0.0,
        description="Maximum rated power delivery per gun in kW",
        examples=[180.0],
    )
    count: int = Field(
        default=1,
        ge=1,
        description="Number of physical charging bays or plugs available",
        examples=[2],
    )


class AccessStep(BaseModel):
    """Visual or textual waypoint guiding drivers to hidden or complex charging bays."""

    step_number: int = Field(
        ge=1,
        description="Sequential ordering number of the instruction step",
        examples=[1],
    )
    instruction: str = Field(
        description="Explicit driving or parking navigation direction",
        examples=["Enter via Basement 1 ramp next to Tower 2 lobby."],
    )
    photo_url: str | None = Field(
        default=None,
        description="Optional image URL showing landmark, ramp, or pillar marker",
        examples=["https://images.chargetrail.my/steps/klcc_b1_pillar12.jpg"],
    )


class StationBase(BaseModel):
    """Shared baseline attributes for charging station entities."""

    name: str = Field(
        min_length=2,
        max_length=255,
        description="Publicly recognized name of the charging hub or station",
        examples=["Suria KLCC Gentari Charging Hub"],
    )
    operator_name: str | None = Field(
        default=None,
        max_length=120,
        description="Charge Point Operator (CPO) name or Community",
        examples=["Gentari"],
    )
    address: str = Field(
        min_length=5,
        max_length=500,
        description="Street and building location address",
        examples=["241, Suria KLCC, Kuala Lumpur City Centre, 50088 Kuala Lumpur"],
    )
    city: str = Field(
        min_length=2,
        max_length=100,
        description="City or municipality",
        examples=["Kuala Lumpur"],
    )
    state: str = Field(
        min_length=2,
        max_length=100,
        description="Malaysian state or federal territory",
        examples=["Wilayah Persekutuan Kuala Lumpur"],
    )
    latitude: float = Field(
        ge=-90.0,
        le=90.0,
        description="WGS84 latitude coordinate",
        examples=[3.1578],
    )
    longitude: float = Field(
        ge=-180.0,
        le=180.0,
        description="WGS84 longitude coordinate",
        examples=[101.7118],
    )
    plug_types: list[PlugInfo] = Field(
        default_factory=list,
        description="List of available connector types and power tiers",
    )
    max_power_kw: float = Field(
        ge=0.0,
        description="Peak power output among all station connectors in kW",
        examples=[180.0],
    )
    is_available: bool = Field(
        default=True,
        description="Operational availability flag for the facility",
    )
    is_24_hours: bool = Field(
        default=False,
        description="Indicates whether the charging bays are accessible 24/7",
    )
    charging_cost_myr: float = Field(
        default=0.0,
        ge=0.0,
        description="Tariff rate per kWh or per minute in Ringgit Malaysia (MYR)",
        examples=[1.40],
    )
    parking_fee_myr: float = Field(
        default=0.0,
        ge=0.0,
        description="Initial entry or hourly parking tariff in MYR",
        examples=[5.00],
    )
    parking_level: str | None = Field(
        default=None,
        max_length=100,
        description="Floor, basement level, or pillar designation",
        examples=["Basement B1, Pillar B12"],
    )
    operation_hours: str = Field(
        default="24 Hours",
        max_length=120,
        description="Human-readable operational schedule",
        examples=["24 Hours"],
    )
    amenities: list[str] = Field(
        default_factory=list,
        description="Nearby facilities (e.g., Dining, Restroom, Shopping, Surau)",
        examples=[["Dining", "Restroom", "Shopping", "Surau"]],
    )
    how_to_access: list[AccessStep] = Field(
        default_factory=list,
        description="Community-curated access instructions and pillar photos",
    )
    description: str | None = Field(
        default=None,
        description="Contextual remarks, payment app notes, or gate pass requirements",
    )
    source: str = Field(
        default="community",
        max_length=50,
        description="Data provenance (e.g., community, openchargemap)",
        examples=["community"],
    )
    is_verified: bool = Field(
        default=True,
        description="Community consensus verification status",
    )


class StationCreate(StationBase):
    """Schema used when authoring or seeding a new charging station."""

    pass


class StationRead(StationBase):
    """Schema returned for station listings and detailed inspector views."""

    id: UUID = Field(description="Unique system UUID of the charging station")
    rating: float = Field(
        default=0.0,
        ge=0.0,
        le=5.0,
        description="Aggregated user review score",
        examples=[4.8],
    )
    review_count: int = Field(
        default=0,
        ge=0,
        description="Total submitted and approved driver reviews",
        examples=[42],
    )
    distance_km: float | None = Field(
        default=None,
        ge=0.0,
        description="Calculated distance in km when origin coordinates are supplied",
        examples=[2.34],
    )
    created_at: datetime | None = Field(
        default=None,
        description="Creation timestamp in UTC",
    )
    updated_at: datetime | None = Field(
        default=None,
        description="Last modification timestamp in UTC",
    )

    model_config = ConfigDict(from_attributes=True)


class StationFilterParams(BaseModel):
    """Query parameter container for viewport bounding box and radial station discovery."""

    min_lat: float | None = Field(
        default=None,
        ge=-90.0,
        le=90.0,
        description="Southern boundary latitude of the map viewport",
    )
    min_lng: float | None = Field(
        default=None,
        ge=-180.0,
        le=180.0,
        description="Western boundary longitude of the map viewport",
    )
    max_lat: float | None = Field(
        default=None,
        ge=-90.0,
        le=90.0,
        description="Northern boundary latitude of the map viewport",
    )
    max_lng: float | None = Field(
        default=None,
        ge=-180.0,
        le=180.0,
        description="Eastern boundary longitude of the map viewport",
    )
    lat: float | None = Field(
        default=None,
        ge=-90.0,
        le=90.0,
        description="Origin latitude for proximity search",
    )
    lng: float | None = Field(
        default=None,
        ge=-180.0,
        le=180.0,
        description="Origin longitude for proximity search",
    )
    radius_km: float = Field(
        default=10.0,
        gt=0.0,
        le=500.0,
        description="Search radius around origin coordinates in kilometers",
    )
    connector_type: str | None = Field(
        default=None,
        description="Filter stations offering this connector type (e.g., CCS2, Type 2, CHAdeMO)",
    )
    min_kw: float | None = Field(
        default=None,
        ge=0.0,
        description="Minimum peak power requirement in kW",
    )
    amenity: str | None = Field(
        default=None,
        description="Required amenity at or near the station (e.g., Dining, Surau)",
    )
    is_24_hours: bool | None = Field(
        default=None,
        description="Filter for stations operating 24 hours daily",
    )
    min_rating: float | None = Field(
        default=None,
        ge=0.0,
        le=5.0,
        description="Minimum average driver rating",
    )
    limit: int = Field(
        default=50,
        ge=1,
        le=200,
        description="Maximum number of stations to return",
    )
    offset: int = Field(
        default=0,
        ge=0,
        description="Pagination offset for results",
    )


class SeedResponse(BaseModel):
    """Schema returned after executing a Malaysian sample data seeding job."""

    inserted_count: int = Field(
        description="Number of newly inserted charging stations",
        examples=[6],
    )
    total_count: int = Field(
        description="Total charging stations present in the database after seeding",
        examples=[6],
    )
    message: str = Field(
        description="Human-readable execution summary",
        examples=["Successfully seeded 6 Malaysian charging stations."],
    )
