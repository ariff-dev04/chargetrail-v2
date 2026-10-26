"""Service layer orchestrating authentication, profile management, and station bookmarks."""

from uuid import UUID

from fastapi import HTTPException, status

from app.core.security import create_access_token, hash_password, verify_password
from app.models.user import User
from app.repositories.station_repository import StationRepository
from app.repositories.user_repository import UserRepository
from app.schemas.station import StationRead
from app.schemas.user import (
    BookmarkToggleResponse,
    TokenResponse,
    UserLogin,
    UserProfileRead,
    UserProfileUpdate,
    UserRegister,
)
from app.services.station_service import StationService


class AuthService:
    """Coordinates credential verification, JWT issuance, profile updates, and bookmarks."""

    def __init__(
        self,
        user_repository: UserRepository,
        station_repository: StationRepository,
    ) -> None:
        """Initialize service with injected repositories."""
        self.user_repo = user_repository
        self.station_repo = station_repository

    async def register_user(self, payload: UserRegister) -> TokenResponse:
        """Register a new user account or raise 409 Conflict if email is taken."""
        existing = await self.user_repo.get_by_email(payload.email)
        if existing is not None:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="An account with this email address already exists.",
            )

        hashed = hash_password(payload.password)
        user = await self.user_repo.create_user(
            email=payload.email,
            hashed_password=hashed,
            full_name=payload.full_name,
            phone_number=payload.phone_number,
            preferred_connector=payload.preferred_connector,
        )

        token = create_access_token(user.id)
        profile = await self.get_profile(user)
        return TokenResponse(access_token=token, token_type="bearer", user=profile)

    async def authenticate_user(self, payload: UserLogin) -> TokenResponse:
        """Authenticate user credentials and issue signed JWT access token."""
        user = await self.user_repo.get_by_email(payload.email)
        if user is None or not verify_password(payload.password, user.hashed_password):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid email or password credentials.",
                headers={"WWW-Authenticate": "Bearer"},
            )

        if not user.is_active:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="User account is deactivated.",
                headers={"WWW-Authenticate": "Bearer"},
            )

        token = create_access_token(user.id)
        profile = await self.get_profile(user)
        return TokenResponse(access_token=token, token_type="bearer", user=profile)

    async def get_profile(self, user: User) -> UserProfileRead:
        """Construct user profile DTO including active bookmarked station IDs."""
        saved_ids = await self.user_repo.get_saved_station_ids(user.id)
        return UserProfileRead(
            id=user.id,
            email=user.email,
            full_name=user.full_name,
            phone_number=user.phone_number,
            preferred_connector=user.preferred_connector,
            role=user.role,
            is_active=user.is_active,
            saved_station_ids=saved_ids,
            created_at=user.created_at,
        )

    async def update_profile(
        self,
        user: User,
        payload: UserProfileUpdate,
    ) -> UserProfileRead:
        """Update mutable fields on current user profile."""
        updated = await self.user_repo.update_user(
            user=user,
            full_name=payload.full_name,
            phone_number=payload.phone_number,
            preferred_connector=payload.preferred_connector,
        )
        return await self.get_profile(updated)

    async def toggle_bookmark(
        self,
        user: User,
        station_id: UUID,
    ) -> BookmarkToggleResponse:
        """Toggle bookmark for a station, validating station existence."""
        station = await self.station_repo.get_by_id(station_id)
        if station is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Charging station with ID '{station_id}' was not found.",
            )

        is_saved = await self.user_repo.toggle_saved_station(user.id, station_id)
        updated_ids = await self.user_repo.get_saved_station_ids(user.id)
        return BookmarkToggleResponse(
            station_id=station_id,
            is_saved=is_saved,
            saved_station_ids=updated_ids,
        )

    async def list_bookmarked_stations(self, user: User) -> list[StationRead]:
        """Fetch full station entities saved by the user."""
        stations = await self.user_repo.get_saved_stations(user.id)
        return [StationService._entity_to_dto(s) for s in stations]
