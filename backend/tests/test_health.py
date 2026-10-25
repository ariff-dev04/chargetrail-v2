"""Unit and integration tests for service health check endpoints."""

import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_api_v1_health_endpoint(async_client: AsyncClient) -> None:
    """Verify that the /api/v1/health endpoint returns status ok and metadata."""
    response = await async_client.get("/api/v1/health")
    assert response.status_code == 200

    data = response.json()
    assert data["status"] == "ok"
    assert data["app_name"] == "ChargeTrail v2 API"
    assert data["version"] == "0.1.0"
    assert data["environment"] == "development"
    assert data["database"] == "not_checked"


@pytest.mark.asyncio
async def test_top_level_health_endpoint(async_client: AsyncClient) -> None:
    """Verify that the top-level /health endpoint is operational for container probes."""
    response = await async_client.get("/health")
    assert response.status_code == 200

    data = response.json()
    assert data["status"] == "ok"
    assert "version" in data


@pytest.mark.asyncio
async def test_health_with_database_check_connected(
    async_client: AsyncClient,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """Verify health endpoint when database connectivity is reported as active."""

    async def mock_check_db_true() -> bool:
        return True

    monkeypatch.setattr("app.api.v1.health.check_database_health", mock_check_db_true)

    response = await async_client.get("/api/v1/health?check_db=true")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "ok"
    assert data["database"] == "connected"

    ready_response = await async_client.get("/health/ready")
    assert ready_response.status_code == 200
    ready_data = ready_response.json()
    assert ready_data["status"] == "ok"
    assert ready_data["database"] == "connected"


@pytest.mark.asyncio
async def test_health_readiness_degraded_when_database_unreachable(
    async_client: AsyncClient,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """Verify readiness returns degraded status when database is disconnected."""

    async def mock_check_db_false() -> bool:
        return False

    monkeypatch.setattr("app.api.v1.health.check_database_health", mock_check_db_false)

    response = await async_client.get("/health/ready")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "degraded"
    assert data["database"] == "disconnected"
