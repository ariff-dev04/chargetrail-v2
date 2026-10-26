"""Health check and observability telemetry endpoints."""

from fastapi import APIRouter, Depends
from pydantic import BaseModel, Field
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.database import check_database_health, get_db_session
from app.core.observability import observability_store
from app.models.station import ChargingStation

router = APIRouter(tags=["Health"])
settings = get_settings()


class HealthResponse(BaseModel):
    """Schema for service health check status response."""

    status: str = Field(description="Operational status of the service", examples=["ok"])
    app_name: str = Field(description="Application title", examples=["ChargeTrail v2 API"])
    version: str = Field(description="Semantic version string", examples=["0.1.0"])
    environment: str = Field(description="Deployment environment", examples=["development"])
    database: str = Field(
        default="not_checked",
        description="Database connectivity status",
        examples=["connected"],
    )


class SystemMetricsResponse(BaseModel):
    """Schema for runtime observability telemetry and database station statistics."""

    status: str = Field(default="healthy", description="System operational health")
    uptime_seconds: float = Field(description="Server process uptime in seconds")
    total_requests: int = Field(description="Total requests recorded by middleware")
    average_latency_ms: float = Field(description="Average request processing duration in ms")
    verified_stations_count: int = Field(description="Total verified stations in database")
    pending_stations_count: int = Field(description="Total unverified community contributions")
    architecture: str = Field(
        default="3-Layer Clean Architecture (FastAPI + PostGIS/SQLite + Flutter Riverpod)",
        description="Software architecture specification",
    )


@router.get("/health", response_model=HealthResponse)
async def get_health(check_db: bool = False) -> HealthResponse:
    """Return basic liveness status, optionally validating database connectivity."""
    db_status = "not_checked"
    if check_db:
        is_healthy = await check_database_health()
        db_status = "connected" if is_healthy else "disconnected"

    return HealthResponse(
        status="ok",
        app_name=settings.PROJECT_NAME,
        version=settings.VERSION,
        environment=settings.ENVIRONMENT,
        database=db_status,
    )


@router.get("/health/ready", response_model=HealthResponse)
async def get_readiness() -> HealthResponse:
    """Readiness probe verifying that dependencies like PostgreSQL are operational."""
    is_healthy = await check_database_health()
    overall_status = "ok" if is_healthy else "degraded"
    db_status = "connected" if is_healthy else "disconnected"

    return HealthResponse(
        status=overall_status,
        app_name=settings.PROJECT_NAME,
        version=settings.VERSION,
        environment=settings.ENVIRONMENT,
        database=db_status,
    )


@router.get(
    "/metrics",
    response_model=SystemMetricsResponse,
    summary="Retrieve system observability metrics and station inventory",
)
async def get_system_metrics(
    session: AsyncSession = Depends(get_db_session),
) -> SystemMetricsResponse:
    """Retrieve runtime process telemetry, request latencies, and database inventory."""
    result = await session.execute(
        select(
            func.count(ChargingStation.id).filter(ChargingStation.is_verified.is_(True)),
            func.count(ChargingStation.id).filter(ChargingStation.is_verified.is_(False)),
        )
    )
    verified_count, pending_count = result.one()

    return SystemMetricsResponse(
        status="healthy",
        uptime_seconds=observability_store.uptime_seconds,
        total_requests=observability_store.total_requests,
        average_latency_ms=observability_store.average_latency_ms,
        verified_stations_count=verified_count or 0,
        pending_stations_count=pending_count or 0,
    )
