"""Tests for backend observability middleware, response headers, and metrics."""

import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_request_timing_middleware_header(async_client: AsyncClient) -> None:
    """Verify that incoming requests append the X-Process-Time-Ms execution header."""
    res = await async_client.get("/api/v1/health")
    assert res.status_code == 200
    assert "x-process-time-ms" in res.headers

    timing_val = float(res.headers["x-process-time-ms"])
    assert timing_val >= 0.0


@pytest.mark.asyncio
async def test_get_system_metrics_endpoint(async_client: AsyncClient) -> None:
    """Verify that /api/v1/metrics returns runtime telemetry and database station counts."""
    # Seed stations first
    await async_client.post("/api/v1/stations/seed-sample")

    # Fetch system metrics
    res = await async_client.get("/api/v1/metrics")
    assert res.status_code == 200
    metrics = res.json()

    assert metrics["status"] == "healthy"
    assert metrics["uptime_seconds"] >= 0.0
    assert metrics["total_requests"] >= 1
    assert metrics["average_latency_ms"] >= 0.0
    assert metrics["verified_stations_count"] >= 12
    assert metrics["pending_stations_count"] == 0
    assert "Clean Architecture" in metrics["architecture"]
