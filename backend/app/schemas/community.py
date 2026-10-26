"""Pydantic schemas for station reviews, micro-survey votes, and consensus telemetry."""

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


class ReviewCreate(BaseModel):
    """Payload schema for submitting a station review or live visit check-in."""

    rating: int = Field(
        ge=1,
        le=5,
        description="Rating score between 1 and 5 stars",
        examples=[5],
    )
    comment: str = Field(
        min_length=2,
        max_length=1000,
        description="Driver comments regarding charging speed, bay condition, or access",
        examples=[
            "Fast 180kW charging. Basement bay was easy to find following Pillar B12 markings."
        ],
    )
    working_status: str = Field(
        default="working",
        description="Operational status observed: working, partial, or out_of_order",
        examples=["working"],
    )
    wait_time_minutes: int = Field(
        default=0,
        ge=0,
        description="Observed vehicle queue wait duration in minutes",
        examples=[0],
    )
    author_name: str = Field(
        default="EV Driver",
        max_length=120,
        description="Display name of the author",
        examples=["Ahmad Faiz"],
    )


class ReviewRead(BaseModel):
    """Response schema for a single station review entry."""

    id: UUID = Field(description="Unique review identifier")
    station_id: UUID = Field(description="Associated charging station UUID")
    author_name: str = Field(description="Review author display name")
    rating: int = Field(description="Numerical rating (1-5)")
    comment: str = Field(description="User review commentary")
    working_status: str = Field(description="Operational status at time of review")
    wait_time_minutes: int = Field(description="Queue wait time in minutes")
    created_at: datetime = Field(description="Submission timestamp in UTC")

    model_config = ConfigDict(from_attributes=True)


class MicroSurveyCreate(BaseModel):
    """Payload schema for submitting 1-tap community micro-survey consensus telemetry."""

    plug_working_status: str = Field(
        description="Plug status: working, partial, or out_of_order",
        examples=["working"],
    )
    parking_fee_status: str = Field(
        description="Parking tariff status: free or paid",
        examples=["paid"],
    )
    access_difficulty: str = Field(
        description="Access navigation ease: easy, moderate, or hard_underground",
        examples=["moderate"],
    )


class MicroSurveyConsensusRead(BaseModel):
    """Aggregated consensus metrics computed across community micro-survey votes."""

    station_id: UUID = Field(description="Associated charging station UUID")
    total_votes: int = Field(description="Cumulative number of micro-survey votes submitted")
    consensus_threshold: int = Field(
        default=3,
        description="Minimum votes required along a dimension to lock consensus",
    )
    consensus_plug_status: str | None = Field(
        default=None,
        description="Consensus plug status if threshold reached (working, partial, out_of_order)",
    )
    consensus_parking_status: str | None = Field(
        default=None,
        description="Consensus parking tariff status if threshold reached (free, paid)",
    )
    consensus_access_difficulty: str | None = Field(
        default=None,
        description="Consensus navigation difficulty if threshold reached",
    )
    station_auto_updated: bool = Field(
        default=False,
        description="Indicates whether station record was automatically updated by consensus",
    )


class StationModerationUpdate(BaseModel):
    """Payload schema used by community moderators to approve or reject pending stations."""

    approve: bool = Field(
        description="True to verify and publish station to map, False to reject",
        examples=[True],
    )
    rejection_reason: str | None = Field(
        default=None,
        description="Optional moderator feedback reason if rejected",
        examples=["Duplicate station entry"],
    )
