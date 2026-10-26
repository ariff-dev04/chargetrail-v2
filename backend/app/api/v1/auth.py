"""REST API endpoints for user authentication, profile management, and bookmarks."""

from uuid import UUID

from fastapi import APIRouter, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db_session
from app.core.security import get_current_user
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
from app.services.auth_service import AuthService

auth_router = APIRouter(prefix="/auth", tags=["Authentication"])
users_router = APIRouter(prefix="/users", tags=["Users"])


def get_auth_service(session: AsyncSession = Depends(get_db_session)) -> AuthService:
    """Dependency provider injecting AuthService with request-scoped session."""
    user_repo = UserRepository(session)
    station_repo = StationRepository(session)
    return AuthService(user_repo, station_repo)


@auth_router.post(
    "/register",
    response_model=TokenResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Register a new driver account",
)
async def register(
    payload: UserRegister,
    service: AuthService = Depends(get_auth_service),
) -> TokenResponse:
    """Create a new user account and return signed JWT access token."""
    return await service.register_user(payload)


@auth_router.post(
    "/login",
    response_model=TokenResponse,
    summary="Log into existing driver account",
)
async def login(
    payload: UserLogin,
    service: AuthService = Depends(get_auth_service),
) -> TokenResponse:
    """Verify email and password credentials, returning signed JWT access token."""
    return await service.authenticate_user(payload)


@users_router.get(
    "/me",
    response_model=UserProfileRead,
    summary="Get current user profile and saved bookmarks",
)
async def get_my_profile(
    current_user: User = Depends(get_current_user),
    service: AuthService = Depends(get_auth_service),
) -> UserProfileRead:
    """Retrieve authenticated user's profile and saved station IDs."""
    return await service.get_profile(current_user)


@users_router.patch(
    "/me",
    response_model=UserProfileRead,
    summary="Update current user profile details",
)
async def update_my_profile(
    payload: UserProfileUpdate,
    current_user: User = Depends(get_current_user),
    service: AuthService = Depends(get_auth_service),
) -> UserProfileRead:
    """Update display name, contact phone, or preferred EV connector standard."""
    return await service.update_profile(current_user, payload)


@users_router.post(
    "/me/bookmarks/{station_id}",
    response_model=BookmarkToggleResponse,
    summary="Toggle saved favorite station bookmark",
)
async def toggle_station_bookmark(
    station_id: UUID,
    current_user: User = Depends(get_current_user),
    service: AuthService = Depends(get_auth_service),
) -> BookmarkToggleResponse:
    """Add or remove station from current user's bookmarked list."""
    return await service.toggle_bookmark(current_user, station_id)


@users_router.get(
    "/me/bookmarks",
    response_model=list[StationRead],
    summary="List all bookmarked charging stations",
)
async def list_bookmarked_stations(
    current_user: User = Depends(get_current_user),
    service: AuthService = Depends(get_auth_service),
) -> list[StationRead]:
    """Retrieve full station details for all stations saved by current user."""
    return await service.list_bookmarked_stations(current_user)
