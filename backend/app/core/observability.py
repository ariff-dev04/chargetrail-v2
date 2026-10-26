"""Observability and telemetry middleware tracking request timings and throughput."""

import time
from collections.abc import Callable
from dataclasses import dataclass, field

from fastapi import Request, Response
from starlette.middleware.base import BaseHTTPMiddleware


@dataclass
class ObservabilityStore:
    """In-memory telemetry container for request counts, latencies, and route metrics."""

    start_time: float = field(default_factory=time.time)
    total_requests: int = 0
    total_errors: int = 0
    total_duration_ms: float = 0.0
    per_route_counts: dict[str, int] = field(default_factory=dict)

    def record_request(self, path: str, duration_ms: float, is_error: bool = False) -> None:
        """Increment telemetry counters for an executed HTTP transaction."""
        self.total_requests += 1
        self.total_duration_ms += duration_ms
        self.per_route_counts[path] = self.per_route_counts.get(path, 0) + 1
        if is_error:
            self.total_errors += 1

    @property
    def uptime_seconds(self) -> float:
        """Return total elapsed server uptime in seconds."""
        return round(time.time() - self.start_time, 1)

    @property
    def average_latency_ms(self) -> float:
        """Return cumulative mean request processing latency in milliseconds."""
        if self.total_requests == 0:
            return 0.0
        return round(self.total_duration_ms / self.total_requests, 2)


# Global singleton metrics store
observability_store = ObservabilityStore()


class RequestTimingMiddleware(BaseHTTPMiddleware):
    """Starlette middleware appending X-Process-Time-Ms and recording operational telemetry."""

    async def dispatch(self, request: Request, call_next: Callable) -> Response:
        """Measure request wall-clock execution time and attach response header."""
        start_tick = time.perf_counter()
        is_error = False

        try:
            response: Response = await call_next(request)
            return response
        except Exception:
            is_error = True
            raise
        finally:
            elapsed_ms = (time.perf_counter() - start_tick) * 1000.0
            observability_store.record_request(
                path=request.url.path,
                duration_ms=elapsed_ms,
                is_error=is_error,
            )
            # If a response object was generated, attach timing header
            if "response" in locals() and isinstance(response, Response):
                response.headers["X-Process-Time-Ms"] = f"{elapsed_ms:.2f}"
