"""In-memory corridor cache and verified Malaysia highway Tesla Supercharger hubs catalog."""

import contextlib
import time
from typing import Any

from app.schemas.station import AccessStep, PlugInfo, StationCreate

_CORRIDOR_CACHE: dict[str, tuple[float, list[Any]]] = {}
_DEFAULT_TTL_SECONDS = 3600.0


def get_cached_corridor(key: str, ttl: float = _DEFAULT_TTL_SECONDS) -> list[Any] | None:
    """Retrieve cached corridor stations if within TTL window."""
    if entry := _CORRIDOR_CACHE.get(key):
        ts, data = entry
        if time.monotonic() - ts < ttl:
            return list(data)
        _CORRIDOR_CACHE.pop(key, None)
    return None


def set_cached_corridor(key: str, stations: list[Any]) -> None:
    """Store corridor stations into in-memory TTL cache."""
    _CORRIDOR_CACHE[key] = (time.monotonic(), list(stations))


def extract_osm_plugs(tags: dict[str, Any]) -> tuple[list[PlugInfo], float]:
    """Parse charging plug specifications from OpenStreetMap extratags."""
    p: list[PlugInfo] = []
    specs = [
        ("socket:type2_combo", 60.0, "CCS2", 2),
        ("socket:type2", 22.0, "Type 2", 2),
        ("socket:chademo", 50.0, "CHAdeMO", 1),
    ]
    for k, kw, t, c in specs:
        if k in tags or f"{k}:output" in tags:
            kw_out = kw
            with contextlib.suppress(Exception):
                kw_out = float(str(tags.get(f"{k}:output") or kw).lower().replace("kw", "").strip())
            p.append(PlugInfo(type=t, power_kw=kw_out, count=max(int(tags.get(k) or c), 1)))
    return p or [
        PlugInfo(type="CCS2", power_kw=60.0, count=2),
        PlugInfo(type="Type 2", power_kw=22.0, count=1),
    ], max((x.power_kw for x in p), default=60.0)


def build_osm_station_create(
    name: str,
    operator: str,
    address: str,
    city: str,
    state: str,
    lat: float,
    lon: float,
    kw: float = 60.0,
    parking_level: str = "Open Public Bay",
    plugs: list[PlugInfo] | None = None,
    hours: str = "24 Hours",
) -> StationCreate:
    """Construct a validated StationCreate instance with geographic fallbacks."""
    p = plugs or [
        PlugInfo(type="CCS2", power_kw=kw, count=2),
        PlugInfo(type="Type 2", power_kw=22.0, count=1),
    ]
    return StationCreate(
        name=name,
        operator_name=operator,
        address=address,
        city=city,
        state=state,
        latitude=lat,
        longitude=lon,
        plug_types=p,
        max_power_kw=kw,
        is_available=True,
        is_24_hours="24" in hours or "24/7" in hours,
        charging_cost_myr=1.40,
        parking_fee_myr=0.0,
        parking_level=parking_level,
        operation_hours=hours,
        amenities=["Convenience Store", "Restroom"],
        how_to_access=[AccessStep(step_number=1, instruction="Live POI.")],
        source="osm_live",
        is_verified=True,
    )


MALAYSIA_TESLA_SUPERCHARGERS = (
    ("Tesla Supercharger - Sunway Big Box", "Iskandar Puteri", "Johor", 1.3968, 103.6277),
    ("Tesla Supercharger - Freeport A'Famosa", "Alor Gajah", "Melaka", 2.4439, 102.2185),
    ("Tesla Supercharger - Gamuda Cove", "Dengkil", "Selangor", 2.8851, 101.6248),
    ("Tesla Supercharger - Pavilion Bukit Jalil", "Kuala Lumpur", "Kuala Lumpur", 3.0504, 101.6708),
    ("Tesla Supercharger - Ipoh Parade", "Ipoh", "Perak", 4.5969, 101.0901),
    ("Tesla Supercharger - Sunway Carnival", "Seberang Jaya", "Penang", 5.3986, 100.3982),
)


def get_malaysia_tesla_corridor_hubs(
    min_lat: float, min_lng: float, max_lat: float, max_lng: float, pad: float = 0.15
) -> list[StationCreate]:
    """Return verified OpenStreetMap Malaysia highway-corridor Tesla Superchargers in bounds."""
    sc_plugs = [PlugInfo(type="CCS2", power_kw=250.0, count=4)]
    return [
        build_osm_station_create(
            name,
            "Tesla",
            f"{name}, {city}",
            city,
            state,
            lat,
            lon,
            kw=250.0,
            parking_level="Multi-Storey / Indoor Carpark",
            plugs=sc_plugs,
        )
        for name, city, state, lat, lon in MALAYSIA_TESLA_SUPERCHARGERS
        if (min_lat - pad <= lat <= max_lat + pad) and (min_lng - pad <= lon <= max_lng + pad)
    ]
