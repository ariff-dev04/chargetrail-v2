"""Geocoding service providing Malaysian place search and landmark resolution."""

import httpx

from app.schemas.routing import PlaceSuggestion

# Curated Malaysian major cities, expressways, and popular EV transit hubs
MALAYSIAN_LANDMARKS: list[PlaceSuggestion] = [
    PlaceSuggestion(
        name="Suria KLCC / Kuala Lumpur City Centre",
        city="Kuala Lumpur",
        state="Wilayah Persekutuan Kuala Lumpur",
        latitude=3.1578,
        longitude=101.7118,
        category="mall",
    ),
    PlaceSuggestion(
        name="IOI City Mall / Putrajaya",
        city="Putrajaya",
        state="Wilayah Persekutuan Putrajaya",
        latitude=2.9698,
        longitude=101.7135,
        category="mall",
    ),
    PlaceSuggestion(
        name="Sunway Pyramid / Bandar Sunway",
        city="Petaling Jaya",
        state="Selangor",
        latitude=3.0733,
        longitude=101.6078,
        category="mall",
    ),
    PlaceSuggestion(
        name="Shell Recharge Tapah RSA (Northbound)",
        city="Tapah",
        state="Perak",
        latitude=4.1950,
        longitude=101.2789,
        category="highway_rsa",
    ),
    PlaceSuggestion(
        name="Gurney Plaza / George Town",
        city="George Town",
        state="Penang",
        latitude=5.4372,
        longitude=100.3096,
        category="mall",
    ),
    PlaceSuggestion(
        name="Mid Valley Southkey / Johor Bahru",
        city="Johor Bahru",
        state="Johor",
        latitude=1.4989,
        longitude=103.7774,
        category="mall",
    ),
    PlaceSuggestion(
        name="Ayer Keroh Interchange / Melaka",
        city="Ayer Keroh",
        state="Melaka",
        latitude=2.2740,
        longitude=102.2850,
        category="city",
    ),
    PlaceSuggestion(
        name="Seremban Gateway / PLUS Expressway",
        city="Seremban",
        state="Negeri Sembilan",
        latitude=2.7258,
        longitude=101.9424,
        category="city",
    ),
    PlaceSuggestion(
        name="Genting Highlands / SkyAvenue",
        city="Genting Highlands",
        state="Pahang",
        latitude=3.4237,
        longitude=101.7932,
        category="tourist_hub",
    ),
    PlaceSuggestion(
        name="Kuantan City Centre",
        city="Kuantan",
        state="Pahang",
        latitude=3.8077,
        longitude=103.3260,
        category="city",
    ),
    PlaceSuggestion(
        name="Ipoh Town Hall / Old Town",
        city="Ipoh",
        state="Perak",
        latitude=4.5975,
        longitude=101.0760,
        category="city",
    ),
    PlaceSuggestion(
        name="Cyberjaya Silicon Valley Hub",
        city="Cyberjaya",
        state="Selangor",
        latitude=2.9213,
        longitude=101.6559,
        category="tech_hub",
    ),
    PlaceSuggestion(
        name="Alor Setar Menara City Centre",
        city="Alor Setar",
        state="Kedah",
        latitude=6.1248,
        longitude=100.3678,
        category="city",
    ),
]


class GeocodingService:
    """Provides fast, deterministic Malaysian place search with optional open geocoding."""

    async def search_places(self, query: str, limit: int = 8) -> list[PlaceSuggestion]:
        """Search places by query keyword matching against Malaysian catalog and open geocoding."""
        q = query.strip().lower()
        if not q:
            return MALAYSIAN_LANDMARKS[:limit]

        # 1. Filter verified curated landmarks first (deterministic & instant)
        matched: list[PlaceSuggestion] = [
            p
            for p in MALAYSIAN_LANDMARKS
            if q in p.name.lower() or q in p.city.lower() or q in p.state.lower()
        ]

        if len(matched) >= limit:
            return matched[:limit]

        # 2. Try querying Photon open-source Nominatim API if query is long enough
        try:
            async with httpx.AsyncClient(timeout=1.2) as client:
                res = await client.get(
                    "https://photon.komoot.io/api/",
                    params={"q": query, "limit": limit},
                )
                if res.status_code == 200:
                    data = res.json()
                    for feature in data.get("features", []):
                        props = feature.get("properties", {})
                        geom = feature.get("geometry", {})
                        coords = geom.get("coordinates", [])
                        if len(coords) >= 2:
                            lng, lat = coords[0], coords[1]
                            # Only include places roughly in Malaysian/SE-Asia geographic envelope
                            if 0.5 <= lat <= 8.5 and 99.0 <= lng <= 120.0:
                                name = props.get("name") or props.get("street") or query
                                city = props.get("city") or props.get("county") or "Malaysia"
                                state = props.get("state") or "Malaysia"
                                item = PlaceSuggestion(
                                    name=name,
                                    city=city,
                                    state=state,
                                    latitude=lat,
                                    longitude=lng,
                                    category="geocoded",
                                )
                                if not any(m.name == item.name for m in matched):
                                    matched.append(item)
        except Exception:
            # Gracefully ignore open geocoding timeout or network errors
            pass

        return matched[:limit]
