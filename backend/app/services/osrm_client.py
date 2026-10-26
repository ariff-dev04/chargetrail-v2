"""OSRM routing client providing highway polylines and road travel times."""

import httpx

from app.schemas.routing import LatLngPoint
from app.services.station_service import haversine_distance_km


class OsrmClient:
    """Client fetching road routing polylines and travel metrics via OSRM with offline fallbacks."""

    def __init__(self, base_url: str = "http://router.project-osrm.org") -> None:
        """Initialize OSRM client with base API URL."""
        self.base_url = base_url

    async def fetch_route(
        self,
        origin_lat: float,
        origin_lng: float,
        dest_lat: float,
        dest_lng: float,
        use_live_osrm: bool = True,
    ) -> tuple[list[LatLngPoint], float, int]:
        """Fetch road polyline coordinates, total driving distance (km), and drive duration (minutes)."""
        if use_live_osrm:
            try:
                async with httpx.AsyncClient(timeout=1.5) as client:
                    url = (
                        f"{self.base_url}/route/v1/driving/"
                        f"{origin_lng},{origin_lat};{dest_lng},{dest_lat}"
                    )
                    res = await client.get(
                        url,
                        params={"overview": "full", "geometries": "geojson"},
                    )
                    if res.status_code == 200:
                        data = res.json()
                        routes = data.get("routes", [])
                        if routes:
                            route = routes[0]
                            dist_meters = route.get("distance", 0.0)
                            dur_seconds = route.get("duration", 0.0)
                            coords = route.get("geometry", {}).get("coordinates", [])

                            points = [LatLngPoint(latitude=c[1], longitude=c[0]) for c in coords]
                            if points:
                                dist_km = round(dist_meters / 1000.0, 1)
                                drive_mins = max(round(dur_seconds / 60.0), 1)
                                return points, dist_km, drive_mins
            except Exception:
                # Network latency, timeout, or OSRM unavailable; fallback to deterministic geometry
                pass

        # Deterministic Highway Polyline Synthesis (Peninsular Malaysia PLUS Corridor)
        return self._synthesize_highway_route(
            origin_lat,
            origin_lng,
            dest_lat,
            dest_lng,
        )

    def _synthesize_highway_route(
        self,
        lat1: float,
        lon1: float,
        lat2: float,
        lon2: float,
    ) -> tuple[list[LatLngPoint], float, int]:
        """Synthesize realistic highway polyline traversing major Malaysian road corridors."""
        points: list[LatLngPoint] = [LatLngPoint(latitude=lat1, longitude=lon1)]

        is_northbound_highway = lat2 > lat1 and abs(lat2 - lat1) > 1.2
        is_southbound_highway = lat1 > lat2 and abs(lat1 - lat2) > 1.2

        if is_northbound_highway:
            # North-South Expressway Northbound corridor (KL -> Perak -> Penang)
            highway_nodes = [
                (3.3217, 101.5767),  # Rawang PLUS Interchange
                (3.7250, 101.4800),  # Tanjung Malim
                (4.1950, 101.2789),  # Tapah RSA Hub (Charger node)
                (4.5975, 101.0760),  # Ipoh
                (4.8517, 100.7417),  # Taiping
                (5.3100, 100.4300),  # Juru / Penang Bridge approach
            ]
            for n_lat, n_lon in highway_nodes:
                if lat1 < n_lat < lat2:
                    points.append(LatLngPoint(latitude=n_lat, longitude=n_lon))

        elif is_southbound_highway:
            # North-South Expressway Southbound corridor (KL -> Melaka -> Johor Bahru)
            highway_nodes = [
                (2.8100, 101.7900),  # Nilai Interchange
                (2.7258, 101.9424),  # Seremban
                (2.2740, 102.2850),  # Ayer Keroh Melaka
                (2.1500, 102.7700),  # Pagoh RSA
                (1.8800, 103.1400),  # Yong Peng
                (1.6500, 103.6000),  # Senai / Kulai
            ]
            for n_lat, n_lon in highway_nodes:
                if lat2 < n_lat < lat1:
                    points.append(LatLngPoint(latitude=n_lat, longitude=n_lon))

        else:
            # Shorter inter-urban route (e.g., KLCC <-> Putrajaya / PJ)
            steps = 8
            for i in range(1, steps):
                fraction = i / float(steps)
                inter_lat = lat1 + (lat2 - lat1) * fraction
                inter_lon = lon1 + (lon2 - lon1) * fraction
                points.append(LatLngPoint(latitude=inter_lat, longitude=inter_lon))

        points.append(LatLngPoint(latitude=lat2, longitude=lon2))

        # Calculate road distance considering real-world road curvature (1.16 winding factor)
        straight_dist = haversine_distance_km(lat1, lon1, lat2, lon2)
        road_distance_km = round(straight_dist * 1.16, 1)

        # Average highway speed ~85 km/h
        drive_minutes = max(round((road_distance_km / 85.0) * 60), 5)

        return points, road_distance_km, drive_minutes
