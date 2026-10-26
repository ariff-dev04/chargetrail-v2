"""Main FastAPI application entrypoint for ChargeTrail v2.

Configures middleware, API routers, and application lifecycle events.
"""

import logging
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.v1.health import router as health_router
from app.api.v1.router import api_router
from app.core.config import get_settings
from app.core.database import engine
from app.core.observability import RequestTimingMiddleware

logger = logging.getLogger("chargetrail")
settings = get_settings()


@asynccontextmanager
async def lifespan(_app: FastAPI) -> AsyncIterator[None]:
    """Manage application startup and shutdown lifecycle events."""
    logger.info("Starting up %s v%s...", settings.PROJECT_NAME, settings.VERSION)
    yield
    logger.info("Shutting down %s...", settings.PROJECT_NAME)
    await engine.dispose()
    logger.info("Database connection pool closed.")


def create_application() -> FastAPI:
    """Build and configure the FastAPI application instance."""
    app = FastAPI(
        title=settings.PROJECT_NAME,
        version=settings.VERSION,
        description=settings.DESCRIPTION,
        lifespan=lifespan,
        docs_url="/docs",
        redoc_url="/redoc",
        openapi_url=f"{settings.API_V1_STR}/openapi.json",
    )

    # Register Observability Request Timing Middleware
    app.add_middleware(RequestTimingMiddleware)

    # Configure Cross-Origin Resource Sharing (CORS)
    if settings.BACKEND_CORS_ORIGINS:
        app.add_middleware(
            CORSMiddleware,
            allow_origins=settings.BACKEND_CORS_ORIGINS,
            allow_credentials=True,
            allow_methods=["*"],
            allow_headers=["*"],
        )

    # Mount API v1 router
    app.include_router(api_router, prefix=settings.API_V1_STR)

    # Mount top-level health router for standard container probes
    app.include_router(health_router)

    return app


app = create_application()
