"""Live OpenStreetMap (Nominatim API + Photon POI) EV charging station harvester service."""

import asyncio
import contextlib
import logging
from typing import Any, ClassVar

import httpx

from app.models.station import ChargingStation
from app.repositories.station_repository import StationRepository
from app.schemas.routing import LatLngPoint
from app.schemas.station import AccessStep, PlugInfo, StationCreate, StationFilterParams
from app.services.station_service import haversine_distance_km

logger = logging.getLogger("chargetrail.harvester")

NOMINATIM_API_URL = "https://nominatim.openstreetmap.org/search"
PHOTON_API_URL = "https://photon.komoot.io/api/"
OSM_HEADERS = {
    "Accept": "application/json",
    "User-Agent": "ChargeTrailV2/1.0 (https://github.com/ariff-dev04/chargetrail-v2)",
}


def _make_ipv4_client(timeout: float = 5.0) -> httpx.AsyncClient:
    """Create httpx AsyncClient using IPv4 transport to avoid IPv6 blackholes."""
    transport = httpx.AsyncHTTPTransport(local_address="0.0.0.0")
    return httpx.AsyncClient(
        headers=OSM_HEADERS, transport=transport, follow_redirects=True, timeout=timeout
    )


def _extract_plugs(tags: dict[str, Any]) -> tuple[list[PlugInfo], float]:
    """Parse plug types and power kW from OpenStreetMap tags with robust fallbacks."""
    plugs: list[PlugInfo] = []
    specs = [
        ("socket:type2_combo", 60.0, "CCS2", 2),
        ("socket:type2", 22.0, "Type 2", 2),
        ("socket:chademo", 50.0, "CHAdeMO", 1),
    ]
    for key, kw_def, ptype, cnt_def in specs:
        if key in tags or f"{key}:output" in tags:
            kw, count = kw_def, cnt_def
            if tags.get(f"{key}:output"):
                with contextlib.suppress(ValueError):
                    kw = float(str(tags[f"{key}:output"]).lower().replace("kw", "").strip())
            if tags.get(key):
                with contextlib.suppress(ValueError):
                    count = int(tags[key])
            plugs.append(PlugInfo(type=ptype, power_kw=kw, count=max(count, 1)))
    if not plugs:
        plugs = [
            PlugInfo(type="CCS2", power_kw=60.0, count=2),
            PlugInfo(type="Type 2", power_kw=22.0, count=1),
        ]
    return plugs, max((p.power_kw for p in plugs), default=60.0)


class OsmHarvesterService:
    """Discovers, parses, and persists live OpenStreetMap charging stations."""

    _harvest_cache: ClassVar[dict[str, list[StationCreate]]] = {}

    @classmethod
    async def harvest_viewport(
        cls,
        min_lat: float,
        min_lng: float,
        max_lat: float,
        max_lng: float,
        center_lat: float | None = None,
        center_lng: float | None = None,
        repository: StationRepository | None = None,
        persist: bool = False,
    ) -> list[StationCreate]:
        """Harvest live OSM and Photon stations in viewport bounds."""
        c_lat = center_lat if center_lat is not None else (min_lat + max_lat) / 2.0
        c_lng = center_lng if center_lng is not None else (min_lng + max_lng) / 2.0
        cell_key = f"{round(c_lat * 20)}_{round(c_lng * 20)}"
        if cell_key in cls._harvest_cache and not persist:
            return cls._harvest_cache[cell_key]

        candidates: list[StationCreate] = []
        t_nom = cls._fetch_nominatim(min_lat, min_lng, max_lat, max_lng)
        t_pho = cls._fetch_photon(c_lat, c_lng, min_lat, min_lng, max_lat, max_lng)
        results = await asyncio.gather(t_nom, t_pho, return_exceptions=True)

        for r in results:
            if isinstance(r, list):
                candidates.extend(r)

        unique: list[StationCreate] = []
        for cand in candidates:
            if not cls._is_near_candidates(cand.latitude, cand.longitude, unique):
                unique.append(cand)
        cls._harvest_cache[cell_key] = unique

        if persist and repository and unique:
            existing = await repository.list_stations(
                StationFilterParams(
                    min_lat=min_lat - 0.05,
                    min_lng=min_lng - 0.05,
                    max_lat=max_lat + 0.05,
                    max_lng=max_lng + 0.05,
                )
            )
            to_insert = [
                c for c in unique if not cls._is_near_existing(c.latitude, c.longitude, existing)
            ]
            if to_insert:
                logger.info("Persisting %d live OSM charging stations...", len(to_insert))
                await repository.upsert_seed_stations(to_insert)

        return unique

    @classmethod
    async def harvest_route_corridor(
        cls, repository: StationRepository, polyline_points: list[LatLngPoint]
    ) -> int:
        """Harvest OSM chargers at checkpoints along an OSRM highway route."""
        if len(polyline_points) < 6:
            return 0
        indices = [int(len(polyline_points) * f) for f in (0.15, 0.30, 0.45, 0.60, 0.75, 0.90)]
        total = 0
        for idx in indices:
            pt = polyline_points[idx]
            st = await cls.harvest_viewport(
                min_lat=pt.latitude - 0.30,
                min_lng=pt.longitude - 0.30,
                max_lat=pt.latitude + 0.30,
                max_lng=pt.longitude + 0.30,
                center_lat=pt.latitude,
                center_lng=pt.longitude,
                repository=repository,
                persist=True,
            )
            total += len(st)
        return total

    @classmethod
    def _is_near_existing(
        cls, lat: float, lng: float, existing: list[ChargingStation], tolerance_km: float = 0.15
    ) -> bool:
        return any(
            haversine_distance_km(lat, lng, s.latitude, s.longitude) < tolerance_km
            for s in existing
        )

    @classmethod
    def _is_near_candidates(
        cls, lat: float, lng: float, candidates: list[StationCreate], tolerance_km: float = 0.15
    ) -> bool:
        return any(
            haversine_distance_km(lat, lng, c.latitude, c.longitude) < tolerance_km
            for c in candidates
        )

    @staticmethod
    def _validate_and_clean_coords(lat: float, lon: float) -> tuple[float, float] | None:
        if (abs(lat) > 90.0 and abs(lat) <= 180.0) and (abs(lon) <= 90.0):
            lat, lon = lon, lat
        if -90.0 <= lat <= 90.0 and -180.0 <= lon <= 180.0:
            return round(float(lat), 6), round(float(lon), 6)
        return None

    @staticmethod
    def _classify_parking_level(tags: dict[str, Any], name: str) -> str:
        text = f"{name.lower()} {str(tags.get('parking', '')).lower()} {str(tags.get('location', '')).lower()} {str(tags.get('covered', '')).lower()} {str(tags.get('level', '')).lower()}"
        mall_kw = [
            "mall",
            "plaza",
            "klcc",
            "pavilion",
            "basement",
            "multi-storey",
            "underground",
            "indoor",
        ]
        if any(kw in text for kw in mall_kw):
            return "Multi-Storey / Indoor Carpark"
        rr_kw = ["r&r", "rsa", "layby", "shell", "petronas", "caltex", "surface"]
        if any(kw in text for kw in rr_kw):
            return "Highway R&R / Open Bay"
        return "Open Public Bay"

    @classmethod
    async def _fetch_nominatim(
        cls, min_lat: float, min_lng: float, max_lat: float, max_lng: float
    ) -> list[StationCreate]:
        params = {
            "q": "charging_station",
            "format": "jsonv2",
            "addressdetails": 1,
            "extratags": 1,
            "viewbox": f"{min_lng},{max_lat},{max_lng},{min_lat}",
            "bounded": 1,
            "limit": 40,
        }
        results: list[StationCreate] = []
        try:
            async with _make_ipv4_client(timeout=5.0) as client:
                res = await client.get(NOMINATIM_API_URL, params=params)
                if res.status_code == 200:
                    for item in res.json():
                        st = cls._parse_nominatim_item(item)
                        if st:
                            results.append(st)
        except Exception as exc:
            logger.debug("Nominatim search failed: %s", exc)
        return results

    @classmethod
    def _parse_nominatim_item(cls, item: dict[str, Any]) -> StationCreate | None:
        if (
            str(item.get("type", "")).lower() != "charging_station"
            and str(item.get("category", "")).lower() != "amenity"
        ):
            return None
        try:
            raw_lat, raw_lon = float(item["lat"]), float(item["lon"])
        except (KeyError, ValueError, TypeError):
            return None

        coords = cls._validate_and_clean_coords(raw_lat, raw_lon)
        if not coords:
            return None
        lat, lon = coords

        addr, extratags = item.get("address", {}), item.get("extratags", {})
        operator = (
            extratags.get("operator")
            or extratags.get("brand")
            or extratags.get("network")
            or "OpenStreetMap Community"
        ).strip()
        city = (
            addr.get("city")
            or addr.get("town")
            or addr.get("suburb")
            or addr.get("county")
            or addr.get("district")
            or "Peninsular Malaysia"
        ).strip()
        state = (addr.get("state") or "Malaysia").strip()
        road = (addr.get("road") or addr.get("street") or "").strip()
        display_name = item.get("display_name") or f"{road}, {city}"

        raw_name = (item.get("name") or "").strip()
        if not raw_name or raw_name.lower() in ("charging station", "ev charger", "charg"):
            loc = road or city
            name = f"{operator} EV Charger - {loc}" if operator else f"EV Charging Station - {loc}"
        else:
            name = raw_name

        plugs, max_kw = _extract_plugs(extratags)
        hours = extratags.get("opening_hours") or "24 Hours"
        is_24h = "24" in hours or "24/7" in hours

        return StationCreate(
            name=name,
            operator_name=operator,
            address=display_name,
            city=city,
            state=state,
            latitude=lat,
            longitude=lon,
            plug_types=plugs,
            max_power_kw=max_kw,
            is_available=True,
            is_24_hours=is_24h,
            charging_cost_myr=1.40,
            parking_fee_myr=0.0,
            parking_level=cls._classify_parking_level(extratags, name),
            operation_hours=hours,
            amenities=["Convenience Store", "Restroom"],
            how_to_access=[
                AccessStep(step_number=1, instruction="Discovered via OpenStreetMap open index.")
            ],
            source="osm_live",
            is_verified=True,
        )

    @classmethod
    async def _fetch_photon(
        cls,
        c_lat: float,
        c_lng: float,
        min_lat: float,
        min_lng: float,
        max_lat: float,
        max_lng: float,
    ) -> list[StationCreate]:
        queries = [
            "charging station",
            "Gentari",
            "JomCharge",
            "ChargEV",
            "DC Handal",
            "Shell Recharge",
            "TNB Electron",
            "Tesla",
            "EV",
        ]
        results: list[StationCreate] = []

        async def _query(client: httpx.AsyncClient, q: str) -> list[StationCreate]:
            q_res: list[StationCreate] = []
            try:
                res = await client.get(
                    PHOTON_API_URL,
                    params={
                        "q": q,
                        "lat": c_lat,
                        "lon": c_lng,
                        "bbox": f"{min_lng},{min_lat},{max_lng},{max_lat}",
                        "limit": 20,
                    },
                )
                if res.status_code == 200:
                    for f in res.json().get("features", []):
                        st = cls._parse_photon_feature(
                            f, min_lat, min_lng, max_lat, max_lng, c_lat, c_lng
                        )
                        if st:
                            q_res.append(st)
            except Exception as exc:
                logger.debug("Photon query '%s' failed: %s", q, exc)
            return q_res

        async with _make_ipv4_client(timeout=4.0) as client:
            gathered = await asyncio.gather(
                *[_query(client, q) for q in queries], return_exceptions=True
            )
            for item in gathered:
                if isinstance(item, list):
                    results.extend(item)
        return results

    @classmethod
    def _parse_photon_feature(
        cls,
        f: dict[str, Any],
        min_lat: float,
        min_lng: float,
        max_lat: float,
        max_lng: float,
        c_lat: float,
        c_lng: float,
    ) -> StationCreate | None:
        coords = f.get("geometry", {}).get("coordinates", [])
        if len(coords) < 2:
            return None
        try:
            raw_lon, raw_lat = float(coords[0]), float(coords[1])
            cleaned = cls._validate_and_clean_coords(raw_lat, raw_lon)
            if cleaned is None:
                return None
            lat, lon = cleaned
        except (ValueError, TypeError):
            return None

        in_bounds = (
            min_lat - 0.05 <= lat <= max_lat + 0.05 and min_lng - 0.05 <= lon <= max_lng + 0.05
        ) or (haversine_distance_km(c_lat, c_lng, lat, lon) <= 25.0)
        if not in_bounds:
            return None

        props = f.get("properties", {})
        osm_val = str(props.get("osm_value") or "").lower()
        osm_key = str(props.get("osm_key") or "").lower()
        if osm_val != "charging_station" and not (
            osm_key in ("amenity", "man_made") and osm_val in ("charging_station", "charge_point")
        ):
            return None

        raw_name = (props.get("name") or "EV Charger").strip()
        city = (
            props.get("city") or props.get("county") or props.get("state") or "Peninsular Malaysia"
        ).strip()
        state = (props.get("state") or "Malaysia").strip()
        street = (props.get("street") or "").strip()
        address = f"{street}, {city}" if street and city not in street else (street or city)
        operator = (props.get("operator") or props.get("brand") or "Open POI Network").strip()

        gen_names = (
            "gentari",
            "ev charger",
            "charging station",
            "charg",
            "jomcharge",
            "chargev",
            "dc handal",
            "shell recharge",
            "tnb electron",
        )
        name = (
            f"{raw_name} - {street or city}"
            if raw_name.lower() in gen_names and (street or city)
            else raw_name
        )

        return StationCreate(
            name=name,
            operator_name=operator,
            address=address,
            city=city,
            state=state,
            latitude=lat,
            longitude=lon,
            plug_types=[
                PlugInfo(type="CCS2", power_kw=60.0, count=2),
                PlugInfo(type="Type 2", power_kw=22.0, count=1),
            ],
            max_power_kw=60.0,
            is_available=True,
            is_24_hours=True,
            charging_cost_myr=1.40,
            parking_fee_myr=0.0,
            parking_level=cls._classify_parking_level(props, raw_name),
            operation_hours="24 Hours",
            amenities=["Convenience Store", "Dining"],
            how_to_access=[
                AccessStep(step_number=1, instruction="Discovered via live geographic open index.")
            ],
            source="osm_live",
            is_verified=True,
        )
