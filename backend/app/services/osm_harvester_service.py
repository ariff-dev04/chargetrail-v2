"""Live OpenStreetMap (Nominatim API + Photon POI) EV charging station harvester service."""

import asyncio
import logging
from typing import Any, ClassVar

import httpx

from app.models.station import ChargingStation
from app.repositories.station_repository import StationRepository
from app.schemas.routing import LatLngPoint
from app.schemas.station import StationCreate, StationFilterParams
from app.services.station_service import haversine_distance_km
from app.services.tesla_corridor_catalog import (
    build_osm_station_create,
    extract_osm_plugs,
    get_cached_corridor,
    get_malaysia_tesla_corridor_hubs,
    set_cached_corridor,
)

logger = logging.getLogger("chargetrail.harvester")

NOMINATIM_API_URL = "https://nominatim.openstreetmap.org/search"
PHOTON_API_URL = "https://photon.komoot.io/api/"
OSM_HEADERS = {
    "Accept": "application/json",
    "User-Agent": "ChargeTrailV2/1.0 (https://github.com/ariff-dev04/chargetrail-v2)",
}
GEN_NAMES = (
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
MALL_KWS = (
    "mall",
    "plaza",
    "klcc",
    "pavilion",
    "basement",
    "multi-storey",
    "underground",
    "indoor",
)
RR_KWS = ("r&r", "rsa", "layby", "shell", "petronas", "caltex", "surface")
PHOTON_QUERIES = (
    "charging station",
    "Gentari",
    "JomCharge",
    "ChargEV",
    "DC Handal",
    "Shell Recharge",
    "TNB Electron",
    "Tesla",
    "EV",
)


def _make_ipv4_client(timeout: float = 5.0) -> httpx.AsyncClient:
    return httpx.AsyncClient(
        headers=OSM_HEADERS,
        transport=httpx.AsyncHTTPTransport(local_address="0.0.0.0"),
        follow_redirects=True,
        timeout=timeout,
    )


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
        c_lat, c_lng = (
            center_lat or (min_lat + max_lat) / 2.0,
            center_lng or (min_lng + max_lng) / 2.0,
        )
        cell_key = f"{round(c_lat * 20)}_{round(c_lng * 20)}"
        cache_key = (
            f"vp_{round(min_lat, 2)}_{round(min_lng, 2)}_{round(max_lat, 2)}_{round(max_lng, 2)}"
        )
        if not persist:
            if cell_key in cls._harvest_cache:
                return cls._harvest_cache[cell_key]
            if cached := get_cached_corridor(cache_key):
                return cached

        candidates: list[StationCreate] = []
        for r in await asyncio.gather(
            cls._fetch_nominatim(min_lat, min_lng, max_lat, max_lng),
            cls._fetch_photon(c_lat, c_lng, min_lat, min_lng, max_lat, max_lng),
            return_exceptions=True,
        ):
            if isinstance(r, list):
                candidates.extend(r)

        unique = [c for c in candidates if not cls._is_near_candidates(c.latitude, c.longitude, [])]
        deduped: list[StationCreate] = []
        for c in unique:
            if not cls._is_near_candidates(c.latitude, c.longitude, deduped):
                deduped.append(c)
        cls._harvest_cache[cell_key] = deduped
        set_cached_corridor(cache_key, deduped)

        if persist and repository and deduped:
            p = StationFilterParams(
                min_lat=min_lat - 0.05,
                min_lng=min_lng - 0.05,
                max_lat=max_lat + 0.05,
                max_lng=max_lng + 0.05,
            )
            existing = await repository.list_stations(p)
            if to_insert := [
                c for c in deduped if not cls._is_near_existing(c.latitude, c.longitude, existing)
            ]:
                await repository.upsert_seed_stations(to_insert)
        return deduped

    @classmethod
    async def harvest_corridor_brand_pois(
        cls,
        min_lat: float,
        min_lng: float,
        max_lat: float,
        max_lng: float,
        query_text: str = "Tesla Supercharger",
    ) -> list[StationCreate]:
        """Discover live brand-specific highway hubs across corridor bounding box."""
        cache_key = f"brand_{round(min_lat, 2)}_{round(min_lng, 2)}_{round(max_lat, 2)}_{round(max_lng, 2)}_{query_text.lower()}"
        if cached := get_cached_corridor(cache_key):
            return cached

        c_lat, c_lng = (min_lat + max_lat) / 2.0, (min_lng + max_lng) / 2.0
        t_nom = cls._fetch_nominatim(min_lat, min_lng, max_lat, max_lng, q=query_text)
        t_pho = cls._fetch_photon(
            c_lat, c_lng, min_lat, min_lng, max_lat, max_lng, queries=[query_text]
        )
        results = await asyncio.gather(t_nom, t_pho, return_exceptions=True)

        unique: list[StationCreate] = []
        for r in results:
            if isinstance(r, list):
                for cand in r:
                    c_name, c_op = cand.name.lower(), (cand.operator_name or "").lower()
                    if "tesla" in c_name or "supercharger" in c_name or "tesla" in c_op:
                        cand.operator_name = "Tesla"
                        if cand.max_power_kw < 120.0:
                            cand.max_power_kw = 250.0
                    if not cls._is_near_candidates(cand.latitude, cand.longitude, unique):
                        unique.append(cand)

        if "tesla" in query_text.lower() or "supercharger" in query_text.lower():
            for hub in get_malaysia_tesla_corridor_hubs(min_lat, min_lng, max_lat, max_lng):
                if not cls._is_near_candidates(hub.latitude, hub.longitude, unique):
                    unique.append(hub)

        set_cached_corridor(cache_key, unique)
        return unique

    @classmethod
    async def harvest_route_corridor(
        cls, repository: StationRepository, polyline_points: list[LatLngPoint]
    ) -> int:
        if len(polyline_points) < 6:
            return 0
        samples = [
            polyline_points[int(len(polyline_points) * f)]
            for f in (0.15, 0.3, 0.45, 0.6, 0.75, 0.9)
        ]
        tasks = [
            cls.harvest_viewport(
                p.latitude - 0.3,
                p.longitude - 0.3,
                p.latitude + 0.3,
                p.longitude + 0.3,
                center_lat=p.latitude,
                center_lng=p.longitude,
                repository=repository,
                persist=True,
            )
            for p in samples
        ]
        res = await asyncio.gather(*tasks, return_exceptions=True)
        return sum(len(st) for st in res if isinstance(st, list))

    @classmethod
    def _is_near_existing(
        cls, lat: float, lng: float, existing: list[ChargingStation], tol: float = 0.15
    ) -> bool:
        return any(haversine_distance_km(lat, lng, s.latitude, s.longitude) < tol for s in existing)

    @classmethod
    def _is_near_candidates(
        cls, lat: float, lng: float, cands: list[StationCreate], tol: float = 0.15
    ) -> bool:
        return any(haversine_distance_km(lat, lng, c.latitude, c.longitude) < tol for c in cands)

    @staticmethod
    def _validate_and_clean_coords(lat: float, lon: float) -> tuple[float, float] | None:
        if abs(lat) > 90.0 >= abs(lon):
            lat, lon = lon, lat
        return (
            (round(float(lat), 6), round(float(lon), 6))
            if -90 <= lat <= 90 and -180 <= lon <= 180
            else None
        )

    @staticmethod
    def _classify_parking_level(tags: dict[str, Any], name: str) -> str:
        text = f"{name.lower()} {str(tags.get('parking', '')).lower()} {str(tags.get('location', '')).lower()}"
        if any(kw in text for kw in MALL_KWS):
            return "Multi-Storey / Indoor Carpark"
        if any(kw in text for kw in RR_KWS):
            return "Highway R&R / Open Bay"
        return "Open Public Bay"

    @classmethod
    async def _fetch_nominatim(
        cls,
        min_lat: float,
        min_lng: float,
        max_lat: float,
        max_lng: float,
        q: str = "charging_station",
    ) -> list[StationCreate]:
        p = {
            "q": q,
            "format": "jsonv2",
            "addressdetails": 1,
            "extratags": 1,
            "viewbox": f"{min_lng},{max_lat},{max_lng},{min_lat}",
            "bounded": 1,
            "limit": 40,
        }
        try:
            async with _make_ipv4_client(timeout=5.0) as client:
                res = await client.get(NOMINATIM_API_URL, params=p)
                return (
                    [st for item in res.json() if (st := cls._parse_nominatim_item(item))]
                    if res.status_code == 200
                    else []
                )
        except Exception as exc:
            logger.debug("Nominatim search failed: %s", exc)
        return []

    @classmethod
    def _parse_nominatim_item(cls, item: dict[str, Any]) -> StationCreate | None:
        cat, typ = str(item.get("category", "")).lower(), str(item.get("type", "")).lower()
        name_lower = str(item.get("name") or "").lower()
        if (
            typ not in ("charging_station", "charge_point")
            and cat != "amenity"
            and not (
                "tesla" in name_lower and ("supercharger" in name_lower or "charger" in name_lower)
            )
        ):
            return None
        try:
            coords = cls._validate_and_clean_coords(float(item["lat"]), float(item["lon"]))
            if not coords:
                return None
            lat, lon = coords
        except (KeyError, ValueError, TypeError):
            return None

        addr, extratags = item.get("address", {}), item.get("extratags", {})
        operator = (
            extratags.get("operator")
            or extratags.get("brand")
            or extratags.get("network")
            or "OpenStreetMap Community"
        ).strip()
        city = str(
            addr.get("city") or addr.get("town") or addr.get("district") or "Peninsular Malaysia"
        ).strip()
        state, road = (
            str(addr.get("state") or "Malaysia").strip(),
            str(addr.get("road") or "").strip(),
        )
        display_name = item.get("display_name") or f"{road}, {city}"
        raw_name = str(item.get("name") or "").strip()
        loc = road or city
        name = (
            (f"{operator} EV Charger - {loc}" if operator else f"EV Charging Station - {loc}")
            if not raw_name or raw_name.lower() in ("charging station", "ev charger", "charg")
            else raw_name
        )
        plugs, max_kw = extract_osm_plugs(extratags)
        return build_osm_station_create(
            name,
            operator,
            display_name,
            city,
            state,
            lat,
            lon,
            kw=max_kw,
            parking_level=cls._classify_parking_level(extratags, name),
            plugs=plugs,
            hours=extratags.get("opening_hours") or "24 Hours",
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
        queries: list[str] | None = None,
    ) -> list[StationCreate]:
        async def _query(client: httpx.AsyncClient, q: str) -> list[StationCreate]:
            try:
                p = {
                    "q": q,
                    "lat": c_lat,
                    "lon": c_lng,
                    "bbox": f"{min_lng},{min_lat},{max_lng},{max_lat}",
                    "limit": 20,
                }
                res = await client.get(PHOTON_API_URL, params=p)
                return (
                    [
                        st
                        for f in res.json().get("features", [])
                        if (
                            st := cls._parse_photon_feature(
                                f, min_lat, min_lng, max_lat, max_lng, c_lat, c_lng
                            )
                        )
                    ]
                    if res.status_code == 200
                    else []
                )
            except Exception as exc:
                logger.debug("Photon query '%s' failed: %s", q, exc)
            return []

        async with _make_ipv4_client(timeout=4.0) as client:
            gathered = await asyncio.gather(
                *[_query(client, q) for q in (queries or PHOTON_QUERIES)], return_exceptions=True
            )
            return [st for item in gathered if isinstance(item, list) for st in item]

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
            cleaned = cls._validate_and_clean_coords(float(coords[1]), float(coords[0]))
            if cleaned is None:
                return None
            lat, lon = cleaned
        except (ValueError, TypeError):
            return None

        if not (
            (min_lat - 0.05 <= lat <= max_lat + 0.05 and min_lng - 0.05 <= lon <= max_lng + 0.05)
            or (haversine_distance_km(c_lat, c_lng, lat, lon) <= 25.0)
        ):
            return None

        props = f.get("properties", {})
        osm_val, osm_key = (
            str(props.get("osm_value") or "").lower(),
            str(props.get("osm_key") or "").lower(),
        )
        raw_name = (props.get("name") or "EV Charger").strip()
        name_lower = raw_name.lower()
        is_ev = (
            osm_val in ("charging_station", "charge_point")
            or (
                osm_key in ("amenity", "man_made")
                and osm_val in ("charging_station", "charge_point")
            )
            or ("tesla" in name_lower and ("supercharger" in name_lower or "charger" in name_lower))
        )
        if not is_ev:
            return None

        city = str(props.get("city") or props.get("state") or "Peninsular Malaysia").strip()
        state = str(props.get("state") or "Malaysia").strip()
        street = str(props.get("street") or "").strip()
        address = f"{street}, {city}" if street and city not in street else (street or city)
        operator = str(props.get("operator") or props.get("brand") or "Open POI Network").strip()
        name = (
            f"{raw_name} - {street or city}"
            if raw_name.lower() in GEN_NAMES and (street or city)
            else raw_name
        )

        return build_osm_station_create(
            name,
            operator,
            address,
            city,
            state,
            lat,
            lon,
            kw=60.0,
            parking_level=cls._classify_parking_level(props, raw_name),
        )
