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
        name="The Exchange TRX",
        city="Kuala Lumpur",
        state="Wilayah Persekutuan Kuala Lumpur",
        latitude=3.1428,
        longitude=101.7188,
        category="mall",
    ),
    PlaceSuggestion(
        name="Mid Valley Megamall",
        city="Kuala Lumpur",
        state="Wilayah Persekutuan Kuala Lumpur",
        latitude=3.1179,
        longitude=101.6778,
        category="mall",
    ),
    PlaceSuggestion(
        name="Pavilion Bukit Jalil",
        city="Kuala Lumpur",
        state="Wilayah Persekutuan Kuala Lumpur",
        latitude=3.0514,
        longitude=101.6706,
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
        name="1 Utama Shopping Centre",
        city="Petaling Jaya",
        state="Selangor",
        latitude=3.1511,
        longitude=101.6152,
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
        name="Auto-City Juru / PLUS Highway",
        city="Perai",
        state="Penang",
        latitude=5.3377,
        longitude=100.4288,
        category="highway_rsa",
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
        name="Skudai Shell RSA / PLUS Southbound",
        city="Skudai",
        state="Johor",
        latitude=1.5342,
        longitude=103.6622,
        category="highway_rsa",
    ),
    PlaceSuggestion(
        name="Pagoh RSA Hub / PLUS Highway",
        city="Muar",
        state="Johor",
        latitude=2.1500,
        longitude=102.7700,
        category="highway_rsa",
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
        name="Jonker Street / Melaka City",
        city="Melaka",
        state="Melaka",
        latitude=2.1952,
        longitude=102.2483,
        category="tourist_hub",
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
        name="Taiping Lake Gardens",
        city="Taiping",
        state="Perak",
        latitude=4.8517,
        longitude=100.7417,
        category="tourist_hub",
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
    PlaceSuggestion(
        name="Kota Bharu Town Centre",
        city="Kota Bharu",
        state="Kelantan",
        latitude=6.1254,
        longitude=102.2386,
        category="city",
    ),
    PlaceSuggestion(
        name="Kuala Terengganu Waterfront",
        city="Kuala Terengganu",
        state="Terengganu",
        latitude=5.3302,
        longitude=103.1408,
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

        # 2. Try querying Photon open-source Nominatim API
        try:
            async with httpx.AsyncClient(timeout=2.0) as client:
                res = await client.get(
                    "https://photon.komoot.io/api/",
                    params={"q": query, "lat": 3.1578, "lon": 101.7118, "limit": limit},
                )
                if res.status_code == 200:
                    data = res.json()
                    for feature in data.get("features", []):
                        props = feature.get("properties", {})
                        geom = feature.get("geometry", {})
                        coords = geom.get("coordinates", [])
                        if len(coords) >= 2:
                            lng, lat = coords[0], coords[1]
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
            pass

        # 3. Nominatim Fallback if still under limit
        if len(matched) < limit:
            try:
                headers = {"User-Agent": "ChargeTrail-v2/1.0"}
                async with httpx.AsyncClient(timeout=2.0, headers=headers) as client:
                    res = await client.get(
                        "https://nominatim.openstreetmap.org/search",
                        params={"format": "jsonv2", "countrycodes": "my", "q": query, "limit": 5},
                    )
                    if res.status_code == 200:
                        data = res.json()
                        for item_data in data:
                            lat = float(item_data.get("lat", 0.0))
                            lng = float(item_data.get("lon", 0.0))
                            if 0.5 <= lat <= 8.5 and 99.0 <= lng <= 120.0:
                                display_name = item_data.get("display_name", "")
                                parts = [p.strip() for p in display_name.split(",")]
                                name = parts[0] if parts else query
                                city = parts[1] if len(parts) > 1 else "Malaysia"
                                state = parts[-2] if len(parts) > 2 else "Malaysia"
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
                pass

        return matched[:limit]
