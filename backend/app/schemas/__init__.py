"""Pydantic schemas package."""

from app.schemas.community import (
    MicroSurveyConsensusRead,
    MicroSurveyCreate,
    ReviewCreate,
    ReviewRead,
    StationModerationUpdate,
)
from app.schemas.routing import (
    ChargingStopRecommendation,
    LatLngPoint,
    PlaceSuggestion,
    RoutePlanRequest,
    RoutePlanResponse,
)
from app.schemas.station import (
    AccessStep,
    PlugInfo,
    SeedResponse,
    StationBase,
    StationCreate,
    StationFilterParams,
    StationRead,
)
from app.schemas.user import (
    BookmarkToggleResponse,
    TokenResponse,
    UserLogin,
    UserProfileRead,
    UserProfileUpdate,
    UserRegister,
)
from app.schemas.vehicle import (
    VehicleCreate,
    VehiclePresetRead,
    VehicleRead,
    VehicleUpdate,
)

__all__ = [
    "AccessStep",
    "BookmarkToggleResponse",
    "ChargingStopRecommendation",
    "LatLngPoint",
    "MicroSurveyConsensusRead",
    "MicroSurveyCreate",
    "PlaceSuggestion",
    "PlugInfo",
    "ReviewCreate",
    "ReviewRead",
    "RoutePlanRequest",
    "RoutePlanResponse",
    "SeedResponse",
    "StationBase",
    "StationCreate",
    "StationFilterParams",
    "StationModerationUpdate",
    "StationRead",
    "TokenResponse",
    "UserLogin",
    "UserProfileRead",
    "UserProfileUpdate",
    "UserRegister",
    "VehicleCreate",
    "VehiclePresetRead",
    "VehicleRead",
    "VehicleUpdate",
]
