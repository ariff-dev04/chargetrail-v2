"""API v1 master router module.

Consolidates all feature-specific routers under the /api/v1 prefix.
"""

from fastapi import APIRouter

from app.api.v1.auth import auth_router, users_router
from app.api.v1.community import router as community_router
from app.api.v1.health import router as health_router
from app.api.v1.stations import router as stations_router
from app.api.v1.vehicles import router as vehicles_router

api_router = APIRouter()

api_router.include_router(health_router)
api_router.include_router(stations_router)
api_router.include_router(auth_router)
api_router.include_router(users_router)
api_router.include_router(community_router)
api_router.include_router(vehicles_router)
