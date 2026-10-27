"""Live OpenStreetMap (Overpass API + Photon POI) EV charging station harvester service.

Harvests real-world Malaysian EV charging infrastructure, deduplicates against existing
records, and persists stations into the PostgreSQL/SQLite database.
"""

import asyncio
import logging
from typing import Any, ClassVar

import httpx

from app.models.station import ChargingStation
from app.repositories.station_repository import StationRepository
from app.schemas.routing import LatLngPoint
from app.schemas.station import AccessStep, PlugInfo, StationCreate, StationFilterParams
from app.services.station_service import haversine_distance_km

logger = logging.getLogger("chargetrail.harvester")

OVERPASS_MIRRORS = [
    "https://lz4.overpass-api.de/api/interpreter",
    "https://overpass.kumi.systems/api/interpreter",
    "https://overpass-api.de/api/interpreter",
]
PHOTON_API_URL = "https://photon.komoot.io/api"
OSM_HEADERS = {
    "Accept": "*/*",
    "User-Agent": "ChargeTrailV2/1.0 (https://github.com/ariff-dev04/chargetrail-v2)",
}


class OsmHarvesterService:
    """Discovers, parses, and persists live OpenStreetMap charging stations."""

    _scanned_cells: ClassVar[set[str]] = set()

    @classmethod
    async def harvest_viewport(
        cls,
        repository: StationRepository,
        min_lat: float,
        min_lng: float,
        max_lat: float,
        max_lng: float,
        center_lat: float | None = None,
        center_lng: float | None = None,
    ) -> list[ChargingStation]:
        """Harvest live OSM stations in viewport and persist into database."""
        c_lat = center_lat if center_lat is not None else (min_lat + max_lat) / 2.0
        c_lng = center_lng if center_lng is not None else (min_lng + max_lng) / 2.0

        cell_key = f"{round(c_lat * 20)}_{round(c_lng * 20)}"
        if cell_key in cls._scanned_cells:
            return await repository.list_stations(
                StationFilterParams(
                    min_lat=min_lat, min_lng=min_lng, max_lat=max_lat, max_lng=max_lng
                )
            )

        cls._scanned_cells.add(cell_key)
        existing = await repository.list_stations(
            StationFilterParams(
                min_lat=min_lat - 0.05,
                min_lng=min_lng - 0.05,
                max_lat=max_lat + 0.05,
                max_lng=max_lng + 0.05,
            )
        )

        candidates: list[StationCreate] = []

        # 1. Fetch Overpass and Photon in parallel
        overpass_task = cls._fetch_overpass(min_lat, min_lng, max_lat, max_lng, c_lat, c_lng)
        photon_task = cls._fetch_photon(c_lat, c_lng)
        results = await asyncio.gather(overpass_task, photon_task, return_exceptions=True)

        if isinstance(results[0], list):
            candidates.extend(results[0])
        if isinstance(results[1], list):
            candidates.extend(results[1])

        # 2. Deduplicate against existing stations and within candidate batch
        to_insert: list[StationCreate] = []
        for cand in candidates:
            if cls._is_near_existing(cand.latitude, cand.longitude, existing, to_insert):
                continue
            to_insert.append(cand)

        if to_insert:
            logger.info("Persisting %d live OSM charging stations to database...", len(to_insert))
            await repository.upsert_seed_stations(to_insert)

        return await repository.list_stations(
            StationFilterParams(min_lat=min_lat, min_lng=min_lng, max_lat=max_lat, max_lng=max_lng)
        )

    @classmethod
    async def harvest_route_corridor(
        cls,
        repository: StationRepository,
        polyline_points: list[LatLngPoint],
    ) -> int:
        """Harvest OSM chargers at checkpoints along an OSRM highway route."""
        if len(polyline_points) < 6:
            return 0

        # Sample checkpoints at ~20%, 40%, 60%, 80% along route
        indices = [
            int(len(polyline_points) * 0.20),
            int(len(polyline_points) * 0.40),
            int(len(polyline_points) * 0.60),
            int(len(polyline_points) * 0.80),
        ]

        total_harvested = 0
        for idx in indices:
            pt = polyline_points[idx]
            stations = await cls.harvest_viewport(
                repository=repository,
                min_lat=pt.latitude - 0.20,
                min_lng=pt.longitude - 0.20,
                max_lat=pt.latitude + 0.20,
                max_lng=pt.longitude + 0.20,
                center_lat=pt.latitude,
                center_lng=pt.longitude,
            )
            total_harvested += len(stations)

        return total_harvested

    @classmethod
    def _is_near_existing(
        cls,
        lat: float,
        lng: float,
        existing: list[ChargingStation],
        candidates: list[StationCreate],
    ) -> bool:
        """Check if coordinates are within 120m of any existing or pending station."""
        for s in existing:
            if haversine_distance_km(lat, lng, s.latitude, s.longitude) < 0.12:
                return True
        for c in candidates:
            if haversine_distance_km(lat, lng, c.latitude, c.longitude) < 0.12:
                return True
        return False

    @classmethod
    async def _fetch_overpass(
        cls,
        min_lat: float,
        min_lng: float,
        max_lat: float,
        max_lng: float,
        c_lat: float,
        c_lng: float,
    ) -> list[StationCreate]:
        """Query Overpass API with multi-mirror failover."""
        query = (
            f"[out:json][timeout:8];"
            f'(node["amenity"="charging_station"]({min_lat},{min_lng},{max_lat},{max_lng});'
            f'way["amenity"="charging_station"]({min_lat},{min_lng},{max_lat},{max_lng});'
            f'node["amenity"="charging_station"](around:15000,{c_lat},{c_lng}););'
            f"out center 40;"
        )

        async with httpx.AsyncClient(headers=OSM_HEADERS, timeout=7.0) as client:
            for mirror in OVERPASS_MIRRORS:
                try:
                    res = await client.post(mirror, data={"data": query})
                    if res.status_code == 200:
                        data = res.json()
                        elements = data.get("elements", [])
                        return [
                            cls._parse_osm_element(el) for el in elements if cls._is_valid_el(el)
                        ]
                except Exception as exc:
                    logger.debug("Overpass mirror %s failed: %s", mirror, exc)
        return []

    @classmethod
    async def _fetch_photon(cls, c_lat: float, c_lng: float) -> list[StationCreate]:
        """Query Photon Komoot for charging station POIs around coordinates."""
        queries = ["charging station", "Gentari", "JomCharge", "TNB Electron"]
        results: list[StationCreate] = []

        async with httpx.AsyncClient(headers=OSM_HEADERS, timeout=6.0) as client:
            for q in queries:
                try:
                    res = await client.get(
                        PHOTON_API_URL,
                        params={"q": q, "lat": c_lat, "lon": c_lng, "limit": 10},
                    )
                    if res.status_code == 200:
                        features = res.json().get("features", [])
                        for f in features:
                            st = cls._parse_photon_feature(f)
                            if st and 1.0 <= st.latitude <= 7.5 and 99.0 <= st.longitude <= 120.0:
                                results.append(st)
                except Exception as exc:
                    logger.debug("Photon query '%s' failed: %s", q, exc)
        return results

    @staticmethod
    def _is_valid_el(el: dict[str, Any]) -> bool:
        lat = el.get("lat") or el.get("center", {}).get("lat")
        lon = el.get("lon") or el.get("center", {}).get("lon")
        return lat is not None and lon is not None and 1.0 <= lat <= 7.5 and 99.0 <= lon <= 120.0

    @classmethod
    def _parse_osm_element(cls, el: dict[str, Any]) -> StationCreate:
        lat = float(el.get("lat") or el.get("center", {}).get("lat", 0.0))
        lon = float(el.get("lon") or el.get("center", {}).get("lon", 0.0))
        tags = el.get("tags", {})

        name = tags.get("name") or tags.get("operator") or "EV Charging Station (OSM)"
        operator = tags.get("operator") or "OpenStreetMap Live"
        city = tags.get("addr:city") or "Peninsular Malaysia"
        state = tags.get("addr:state") or "Malaysia"
        street = tags.get("addr:street") or name

        plugs = [PlugInfo(type="CCS2", power_kw=60.0, count=2)]
        hours = tags.get("opening_hours") or "24 Hours"
        is_24h = "24" in hours or "24/7" in hours

        return StationCreate(
            name=name,
            operator_name=operator,
            address=f"{street}, {city}",
            city=city,
            state=state,
            latitude=lat,
            longitude=lon,
            plug_types=plugs,
            max_power_kw=60.0,
            is_available=True,
            is_24_hours=is_24h,
            charging_cost_myr=1.40,
            parking_fee_myr=0.0,
            parking_level="Street / Open Carpark",
            operation_hours=hours,
            amenities=["Convenience Store", "Restroom"],
            how_to_access=[
                AccessStep(step_number=1, instruction="Located via OpenStreetMap live network.")
            ],
            source="osm_live",
            is_verified=True,
        )

    @classmethod
    def _parse_photon_feature(cls, f: dict[str, Any]) -> StationCreate | None:
        coords = f.get("geometry", {}).get("coordinates", [])
        if len(coords) < 2:
            return None
        lon, lat = float(coords[0]), float(coords[1])
        props = f.get("properties", {})

        name = props.get("name") or "EV Charging Point"
        city = props.get("city") or props.get("county") or "Malaysia"
        state = props.get("state") or "Malaysia"
        street = props.get("street") or name

        return StationCreate(
            name=name,
            operator_name="Photon Open POI",
            address=f"{street}, {city}",
            city=city,
            state=state,
            latitude=lat,
            longitude=lon,
            plug_types=[PlugInfo(type="CCS2", power_kw=60.0, count=2)],
            max_power_kw=60.0,
            is_available=True,
            is_24_hours=True,
            charging_cost_myr=1.40,
            parking_fee_myr=0.0,
            parking_level="Ground / Open Bay",
            operation_hours="24 Hours",
            amenities=["Convenience Store", "Dining"],
            how_to_access=[
                AccessStep(step_number=1, instruction="Discovered via live geographic open index.")
            ],
            source="osm_live",
            is_verified=True,
        )
