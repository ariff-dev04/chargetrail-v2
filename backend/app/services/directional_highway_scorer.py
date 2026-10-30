"""Directional highway R&R geometric analysis and candidate scoring."""

import math
from dataclasses import dataclass
from typing import Any

from app.schemas.routing import LatLngPoint
from app.schemas.station import StationRead
from app.services.station_service import haversine_distance_km

NORTHBOUND_KEYWORDS = ("northbound", "north bound", "arah utara", " nb", "(nb)", "utara")
SOUTHBOUND_KEYWORDS = ("southbound", "south bound", "arah selatan", " sb", "(sb)", "selatan")
EASTBOUND_KEYWORDS = ("eastbound", "east bound", "arah timur", " eb", "(eb)", "timur")
WESTBOUND_KEYWORDS = ("westbound", "west bound", "arah barat", " wb", "(wb)", "barat")
HIGHWAY_KEYWORDS = ("rsa", "r&r", "layby", "hentian", "highway", "lebuhraya", "plus", "tol")


@dataclass
class CorridorCandidate:
    """Corridor candidate station with along-route distance, detour, side, and score."""

    station: StationRead
    dist: float
    detour: float
    score: float = 0.0
    side: str = "center"
    cross_track_m: float = 0.0
    local_dlat: float = 0.0
    local_dlng: float = 0.0
    is_on_left: bool = False


def compute_segment_bearing(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    """Calculate forward geodetic azimuth from (lat1, lng1) to (lat2, lng2) in degrees [0, 360)."""
    if lat1 == lat2 and lng1 == lng2:
        return 0.0
    r_lat1, r_lat2 = math.radians(lat1), math.radians(lat2)
    d_lng = math.radians(lng2 - lng1)
    y = math.sin(d_lng) * math.cos(r_lat2)
    x = math.cos(r_lat1) * math.sin(r_lat2) - math.sin(r_lat1) * math.cos(r_lat2) * math.cos(d_lng)
    return (math.degrees(math.atan2(y, x)) + 360.0) % 360.0


def _dist_to_segment_km(
    p1: tuple[float, float], p2: tuple[float, float], target_lat: float, target_lng: float
) -> float:
    """Calculate perpendicular or vertex distance in km from target to segment [p1 -> p2]."""
    mid_lat = math.radians((p1[0] + p2[0]) / 2.0)
    cos_lat = math.cos(mid_lat)
    dx, dy = (p2[1] - p1[1]) * cos_lat * 111.32, (p2[0] - p1[0]) * 111.32
    tx, ty = (target_lng - p1[1]) * cos_lat * 111.32, (target_lat - p1[0]) * 111.32
    seg_len_sq = dx * dx + dy * dy
    if seg_len_sq < 1e-12:
        return math.hypot(tx, ty)
    t = max(0.0, min(1.0, (tx * dx + ty * dy) / seg_len_sq))
    return math.hypot(tx - t * dx, ty - t * dy)


def compute_local_segment_bearing(
    polyline: list[tuple[float, float]], target_lat: float, target_lng: float
) -> tuple[float, float, int]:
    """Find closest polyline segment [p_i -> p_{i+1}] and return (bearing_deg, min_dist_km, closest_idx)."""
    if not polyline:
        return (0.0, 0.0, 0)
    if len(polyline) == 1:
        return (
            0.0,
            round(_dist_to_segment_km(polyline[0], polyline[0], target_lat, target_lng), 4),
            0,
        )

    best_idx, min_dist_km = 0, float("inf")
    for i in range(len(polyline) - 1):
        dist = _dist_to_segment_km(polyline[i], polyline[i + 1], target_lat, target_lng)
        if dist < min_dist_km:
            min_dist_km, best_idx = dist, i

    p1, p2 = polyline[best_idx], polyline[best_idx + 1]
    return (
        round(compute_segment_bearing(p1[0], p1[1], p2[0], p2[1]), 2),
        round(min_dist_km, 4),
        best_idx,
    )


def compute_cross_track_side(
    p1: tuple[float, float], p2: tuple[float, float], station_lat: float, station_lng: float
) -> str:
    """Determine whether station lies on 'left', 'right', or 'center' (within 60m) of driving direction."""
    mid_lat = math.radians((p1[0] + p2[0]) / 2.0)
    cos_lat = math.cos(mid_lat)
    dx, dy = (p2[1] - p1[1]) * cos_lat * 111320.0, (p2[0] - p1[0]) * 111320.0
    sx, sy = (station_lng - p1[1]) * cos_lat * 111320.0, (station_lat - p1[0]) * 111320.0
    seg_len = math.hypot(dx, dy)
    if seg_len < 1e-6:
        return "center"
    cross_product = dx * sy - dy * sx
    if abs(cross_product) / seg_len <= 60.0:
        return "center"
    return "left" if cross_product > 0.0 else "right"


def compute_cross_track_distance_m(
    p1: tuple[float, float], p2: tuple[float, float], station_lat: float, station_lng: float
) -> float:
    """Compute absolute cross-track distance in meters from station to segment vector."""
    mid_lat = math.radians((p1[0] + p2[0]) / 2.0)
    cos_lat = math.cos(mid_lat)
    dx, dy = (p2[1] - p1[1]) * cos_lat * 111320.0, (p2[0] - p1[0]) * 111320.0
    sx, sy = (station_lng - p1[1]) * cos_lat * 111320.0, (station_lat - p1[0]) * 111320.0
    seg_len = math.hypot(dx, dy)
    return math.hypot(sx, sy) if seg_len < 1e-6 else abs(dx * sy - dy * sx) / seg_len


def is_opposite_highway_direction(
    station_name: str, station_address: str, segment_bearing_deg: float
) -> bool:
    """Exclude stations facing opposite highway direction using bilingual English/Malay tokens."""
    raw = f"{station_name.lower()} {station_address.lower()}"
    for phrase in (
        "utara-selatan",
        "utara\u2013selatan",
        "utara selatan",
        "north-south",
        "north south",
    ):
        raw = raw.replace(phrase, "")
    padded = f" {raw} "

    has_nb = any(kw in padded for kw in NORTHBOUND_KEYWORDS)
    has_sb = any(kw in padded for kw in SOUTHBOUND_KEYWORDS)
    has_eb = any(kw in padded for kw in EASTBOUND_KEYWORDS)
    has_wb = any(kw in padded for kw in WESTBOUND_KEYWORDS)

    bearing = segment_bearing_deg % 360.0
    is_north = bearing <= 75.0 or bearing >= 285.0
    is_south = 105.0 <= bearing <= 255.0
    is_east = 45.0 <= bearing <= 135.0
    is_west = 225.0 <= bearing <= 315.0

    if (is_north and has_sb and not has_nb) or (is_south and has_nb and not has_sb):
        return True
    if is_east and has_wb and not has_eb:
        return True
    return bool(is_west and has_eb and not has_wb)


def score_candidate_station(
    station: Any,
    detour_km: float,
    side: str = "center",
    cross_track_m: float = 0.0,
    prefer_easy_access: bool = False,
) -> float:
    """Deterministically score candidate charger based on detour, side, access ease, and power."""
    score = detour_km * 2.0
    power_kw = float(getattr(station, "max_power_kw", 0.0) or 0.0)
    score -= min(power_kw, 350.0) * 0.1

    name = str(getattr(station, "name", "") or "").lower()
    addr = str(getattr(station, "address", "") or "").lower()
    clean = f"{name} {addr}"
    for phrase in (
        "utara-selatan",
        "utara\u2013selatan",
        "utara selatan",
        "north-south",
        "north south",
    ):
        clean = clean.replace(phrase, "")
    padded = f" {clean} "

    dir_kws = (
        "northbound",
        "southbound",
        "eastbound",
        "westbound",
        "arah utara",
        "arah selatan",
        "arah timur",
        "arah barat",
        " nb",
        "(nb)",
        " sb",
        "(sb)",
        " eb",
        "(eb)",
        " wb",
        "(wb)",
        "utara",
        "selatan",
        "timur",
        "barat",
    )
    has_dir_tag = any(kw in padded for kw in dir_kws)
    is_highway = any(kw in clean for kw in HIGHWAY_KEYWORDS)
    is_overpass = any(kw in clean for kw in ("overpass", "jejantas", "overhead"))

    if side == "left":
        score -= 3.0
    elif (
        is_highway
        and not has_dir_tag
        and not is_overpass
        and side == "right"
        and cross_track_m > 80.0
    ):
        score += 15.0

    parking = str(getattr(station, "parking_level", "") or "").lower()
    desc = f"{clean} {parking} {str(getattr(station, 'city', '') or '').lower()}"

    if (
        "highway r&r / open bay" in parking
        or (is_highway and "open" in parking)
        or "highway r&r" in parking
    ):
        score -= 4.0
    elif "open public bay" in parking or parking == "open bay" or "open" in parking:
        score -= 1.5
    elif any(
        k in parking for k in ("multi-storey", "indoor carpark", "basement", "underground")
    ) or any(m in desc for m in ("mall", "plaza", "klcc", "pavilion", "basement", "underground")):
        score += 8.0 if prefer_easy_access else 2.5

    if (fee := getattr(station, "parking_fee_myr", None)) and fee > 0.0:
        score += 1.5

    return round(score, 4)


def station_tie_breaker_key(score: float, station: Any) -> tuple[float, float, float, str]:
    """Deterministic tie-breaker key (score, round(lat, 6), round(lng, 6), station_id)."""
    return (
        score,
        round(float(getattr(station, "latitude", 0.0)), 6),
        round(float(getattr(station, "longitude", 0.0)), 6),
        str(getattr(station, "id", "")),
    )


def is_directionally_compatible(
    station_name: str,
    station_address: str,
    station_lat: float,
    station_lng: float = 0.0,
    origin_lat: float = 0.0,
    dest_lat: float = 0.0,
    local_dlat: float | None = None,
    local_dlng: float | None = None,
) -> bool:
    """Check if station is directionally and latitudinally compatible with route direction."""
    del station_lng
    if not (
        (min(origin_lat, dest_lat) - 0.05) <= station_lat <= (max(origin_lat, dest_lat) + 0.05)
    ):
        return False
    d_lat = (
        local_dlat
        if local_dlat is not None and abs(local_dlat) > 0.0001
        else (dest_lat - origin_lat)
    )
    d_lng = local_dlng if local_dlng is not None and abs(local_dlng) > 0.0001 else 0.0
    bearing = (math.degrees(math.atan2(d_lng, d_lat)) + 360.0) % 360.0
    return not is_opposite_highway_direction(station_name, station_address, bearing)


def build_corridor_candidates(
    stations: list[StationRead],
    points: list[LatLngPoint],
    origin_lat: float,
    dest_lat: float,
    max_corridor_detour: float,
    prefer_easy_access: bool = False,
) -> list[CorridorCandidate]:
    """Filter and score stations along route polyline into directional corridor candidates."""
    if not points or not stations:
        return []

    polyline = [(p.latitude, p.longitude) for p in points]
    cum_dists = [0.0]
    for i in range(len(points) - 1):
        cum_dists.append(
            cum_dists[-1]
            + haversine_distance_km(
                points[i].latitude,
                points[i].longitude,
                points[i + 1].latitude,
                points[i + 1].longitude,
            )
        )

    candidates: list[CorridorCandidate] = []
    min_lat, max_lat = min(origin_lat, dest_lat) - 0.08, max(origin_lat, dest_lat) + 0.08
    for st in stations:
        if not (min_lat <= st.latitude <= max_lat):
            continue

        bearing, detour_km, closest_idx = compute_local_segment_bearing(
            polyline, st.latitude, st.longitude
        )
        if detour_km > max_corridor_detour or is_opposite_highway_direction(
            st.name, st.address, bearing
        ):
            continue

        p1_idx = closest_idx if closest_idx < len(polyline) - 1 else max(0, closest_idx - 1)
        p1, p2 = polyline[p1_idx], polyline[min(p1_idx + 1, len(polyline) - 1)]
        side = compute_cross_track_side(p1, p2, st.latitude, st.longitude)
        cross_track_m = compute_cross_track_distance_m(p1, p2, st.latitude, st.longitude)
        score = score_candidate_station(st, detour_km, side, cross_track_m, prefer_easy_access)

        candidates.append(
            CorridorCandidate(
                station=st,
                dist=round(cum_dists[closest_idx] + detour_km, 1),
                detour=round(detour_km, 1),
                score=score,
                side=side,
                cross_track_m=round(cross_track_m, 1),
                is_on_left=(side == "left"),
            )
        )

    candidates.sort(
        key=lambda c: (
            c.dist,
            c.score,
            round(c.station.latitude, 6),
            round(c.station.longitude, 6),
            str(c.station.id),
        )
    )
    return candidates
