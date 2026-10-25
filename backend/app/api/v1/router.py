"""API v1 master router module.

Consolidates all feature-specific routers under the /api/v1 prefix.
"""

from fastapi import APIRouter

from app.api.v1.health import router as health_router

api_router = APIRouter()

api_router.include_router(health_router)
