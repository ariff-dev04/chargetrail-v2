"""Pydantic schemas for user registration, authentication, profiles, and bookmarks."""

import re
from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator

EMAIL_REGEX = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")


class UserRegister(BaseModel):
    """Payload schema for user registration."""

    email: str = Field(
        description="Unique user email address",
        examples=["driver@chargetrail.my"],
    )
    password: str = Field(
        min_length=6,
        description="Raw user password with minimum 6 characters",
        examples=["SecurePass123!"],
    )
    full_name: str = Field(
        min_length=2,
        max_length=150,
        description="User full display name",
        examples=["Ariff Azman"],
    )
    phone_number: str | None = Field(
        default=None,
        max_length=40,
        description="Optional Malaysian contact phone number",
        examples=["+60123456789"],
    )
    preferred_connector: str = Field(
        default="CCS2",
        description="Primary EV charging standard used by user's vehicle",
        examples=["CCS2"],
    )

    @field_validator("email")
    @classmethod
    def validate_email(cls, value: str) -> str:
        """Ensure email conforms to standard address structure."""
        cleaned = value.strip().lower()
        if not EMAIL_REGEX.match(cleaned):
            raise ValueError("Invalid email address format.")
        return cleaned


class UserLogin(BaseModel):
    """Payload schema for user authentication."""

    email: str = Field(
        description="User registered email address",
        examples=["driver@chargetrail.my"],
    )
    password: str = Field(
        description="Account password",
        examples=["SecurePass123!"],
    )

    @field_validator("email")
    @classmethod
    def validate_email(cls, value: str) -> str:
        """Normalize login email address."""
        cleaned = value.strip().lower()
        if not EMAIL_REGEX.match(cleaned):
            raise ValueError("Invalid email address format.")
        return cleaned


class UserProfileUpdate(BaseModel):
    """Payload schema for updating user profile details."""

    full_name: str | None = Field(
        default=None,
        min_length=2,
        max_length=150,
        description="Updated full name",
    )
    phone_number: str | None = Field(
        default=None,
        max_length=40,
        description="Updated phone number",
    )
    preferred_connector: str | None = Field(
        default=None,
        description="Updated preferred charging standard",
    )


class UserProfileRead(BaseModel):
    """Response schema representing a public or authenticated user profile."""

    id: UUID = Field(description="Unique system user UUID")
    email: str = Field(description="User email address")
    full_name: str = Field(description="User full display name")
    phone_number: str | None = Field(default=None, description="Contact phone number")
    preferred_connector: str = Field(
        default="CCS2",
        description="Preferred connector standard",
    )
    role: str = Field(default="user", description="Account privilege role")
    is_active: bool = Field(default=True, description="Account active status")
    saved_station_ids: list[UUID] = Field(
        default_factory=list,
        description="List of bookmarked charging station IDs",
    )
    created_at: datetime | None = Field(default=None, description="Account creation timestamp")

    model_config = ConfigDict(from_attributes=True)


class TokenResponse(BaseModel):
    """Response schema returned upon successful registration or login."""

    access_token: str = Field(description="Signed JWT access bearer token")
    token_type: str = Field(default="bearer", description="Token schema type")
    user: UserProfileRead = Field(description="Authenticated user profile details")


class BookmarkToggleResponse(BaseModel):
    """Response schema returned after toggling a saved station bookmark."""

    station_id: UUID = Field(description="Target charging station UUID")
    is_saved: bool = Field(description="Updated bookmark status for the station")
    saved_station_ids: list[UUID] = Field(
        description="Updated full list of bookmarked station IDs",
    )
