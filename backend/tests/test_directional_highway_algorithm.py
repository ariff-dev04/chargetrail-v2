"""Benchmark and unit test suite for directional highway R&R scoring algorithm."""

import random
import uuid

from app.schemas.routing import LatLngPoint
from app.schemas.station import StationRead
from app.services.directional_highway_scorer import (
    build_corridor_candidates,
    compute_cross_track_side,
    is_opposite_highway_direction,
    score_candidate_station,
)


def make_station(
    id: int,
    name: str,
    address: str,
    lat: float,
    lng: float,
    max_power_kw: float = 120.0,
    parking_level: str = "Open Bay",
    parking_fee_myr: float | None = 0.0,
) -> StationRead:
    """Helper to instantiate StationRead fixtures for corridor tests."""
    return StationRead(
        id=uuid.UUID(int=id),
        name=name,
        address=address,
        city="Highway",
        state="Selangor",
        latitude=lat,
        longitude=lng,
        max_power_kw=max_power_kw,
        parking_level=parking_level,
        parking_fee_myr=parking_fee_myr,
    )


def test_plus_e2_northbound_excludes_southbound_rnr() -> None:
    """Driving Northbound on PLUS E2 must exclude Southbound R&Rs across the divider."""
    # Polyline from Johor Bahru heading North towards Seremban / KL (~330 deg bearing)
    points = [
        LatLngPoint(latitude=1.4927, longitude=103.7414),
        LatLngPoint(latitude=2.1960, longitude=102.2405),
        LatLngPoint(latitude=2.7258, longitude=101.9424),
        LatLngPoint(latitude=3.1578, longitude=101.7118),
    ]

    sb_stations = [
        make_station(1, "Gentari R&R Seremban (Southbound)", "PLUS E2 KM 250 SB", 2.715, 101.945),
        make_station(
            2, "ChargEV RSA Ayer Keroh Arah Selatan", "Lebuhraya PLUS E2 Selatan", 2.210, 102.245
        ),
        make_station(3, "Shell Recharge R&R Pagoh SB", "PLUS Highway KM 143 SB", 2.150, 102.770),
    ]
    nb_stations = [
        make_station(4, "Gentari R&R Seremban (Northbound)", "PLUS E2 KM 250 NB", 2.715, 101.943),
        make_station(
            5, "ChargEV RSA Ayer Keroh Arah Utara", "Lebuhraya PLUS E2 Utara", 2.210, 102.240
        ),
    ]

    for st in sb_stations:
        assert is_opposite_highway_direction(st.name, st.address, segment_bearing_deg=330.0) is True

    for st in nb_stations:
        assert (
            is_opposite_highway_direction(st.name, st.address, segment_bearing_deg=330.0) is False
        )

    candidates = build_corridor_candidates(
        stations=sb_stations + nb_stations,
        points=points,
        origin_lat=1.4927,
        dest_lat=3.1578,
        max_corridor_detour=5.0,
    )
    candidate_names = [c.station.name for c in candidates]

    for st in sb_stations:
        assert st.name not in candidate_names
    for st in nb_stations:
        assert st.name in candidate_names


def test_plus_e1_southbound_excludes_northbound_rnr() -> None:
    """Driving Southbound on PLUS E1 must exclude Northbound R&Rs."""
    # Polyline from Ipoh heading South towards Tapah / KL (~155 deg bearing)
    points = [
        LatLngPoint(latitude=4.5975, longitude=101.0901),
        LatLngPoint(latitude=4.2000, longitude=101.2600),
        LatLngPoint(latitude=3.7000, longitude=101.5200),
        LatLngPoint(latitude=3.3200, longitude=101.5740),
        LatLngPoint(latitude=3.1578, longitude=101.7118),
    ]

    nb_stations = [
        make_station(11, "R&R Tapah Northbound", "PLUS E1 KM 305", 4.2005, 101.2610),
        make_station(12, "RSA Rawang Arah Utara", "PLUS E1 KM 440", 3.3200, 101.5750),
        make_station(13, "Hentian Sebelah Behrang (NB)", "PLUS E1 KM 380", 3.7400, 101.5100),
    ]
    sb_stations = [
        make_station(14, "R&R Tapah Southbound", "PLUS E1 KM 305", 4.2005, 101.2590),
        make_station(15, "RSA Rawang Arah Selatan", "PLUS E1 KM 440", 3.3200, 101.5730),
    ]

    for st in nb_stations:
        assert is_opposite_highway_direction(st.name, st.address, segment_bearing_deg=155.0) is True

    for st in sb_stations:
        assert (
            is_opposite_highway_direction(st.name, st.address, segment_bearing_deg=155.0) is False
        )

    candidates = build_corridor_candidates(
        stations=nb_stations + sb_stations,
        points=points,
        origin_lat=4.5975,
        dest_lat=3.1578,
        max_corridor_detour=5.0,
    )
    candidate_names = [c.station.name for c in candidates]

    for st in nb_stations:
        assert st.name not in candidate_names
    for st in sb_stations:
        assert st.name in candidate_names


def test_lpt_karak_e8_eastbound_vs_westbound_bilingual() -> None:
    """Bilingual Eastbound and Westbound tags must match directional bearings accurately."""
    eb_bearing = 75.0  # KL -> Kuantan (Eastbound)
    wb_bearing = 255.0  # Kuantan -> KL (Westbound)

    wb_tags = ["Karak R&R Arah Barat", "Shell R&R Temerloh Westbound", "Petronas Gambang (WB)"]
    eb_tags = ["Karak R&R Arah Timur", "Shell R&R Temerloh Eastbound", "Petronas Gambang (EB)"]

    for name in wb_tags:
        assert is_opposite_highway_direction(name, "LPT1 E8 Highway", eb_bearing) is True
        assert is_opposite_highway_direction(name, "LPT1 E8 Highway", wb_bearing) is False

    for name in eb_tags:
        assert is_opposite_highway_direction(name, "LPT1 E8 Highway", wb_bearing) is True
        assert is_opposite_highway_direction(name, "LPT1 E8 Highway", eb_bearing) is False

    # Highway names containing directional words must not trigger false exclusion
    assert (
        is_opposite_highway_direction("Petronas Lebuhraya Timur-Barat", "Gerik, Perak", eb_bearing)
        is False
    )
    assert (
        is_opposite_highway_direction(
            "Shell Lebuhraya Utara-Selatan", "PLUS Expressway", eb_bearing
        )
        is False
    )
    assert (
        is_opposite_highway_direction("Petronas Lebuhraya Timur-Barat", "Gerik, Perak", wb_bearing)
        is False
    )


def test_malaysia_keep_left_carriageway_cross_divider_penalty() -> None:
    """Unlabeled R&Rs across highway divider (>80m right) receive +15.0 penalty over left side."""
    p1 = (2.8500, 101.6200)
    p2 = (2.8700, 101.6200)  # Driving straight North along highway centerline

    # Same carriageway (Left of vector in Keep-Left driving) vs Opposite (Right across divider)
    left_station = make_station(21, "ChargEV R&R Dengkil", "ELITE Highway", 2.8600, 101.6188)
    right_station = make_station(22, "ChargEV R&R Dengkil", "ELITE Highway", 2.8600, 101.6212)

    assert compute_cross_track_side(p1, p2, left_station.latitude, left_station.longitude) == "left"
    assert (
        compute_cross_track_side(p1, p2, right_station.latitude, right_station.longitude) == "right"
    )

    score_left = score_candidate_station(
        left_station, detour_km=0.1, side="left", cross_track_m=130.0
    )
    score_right = score_candidate_station(
        right_station, detour_km=0.1, side="right", cross_track_m=130.0
    )

    # Left receives -3.0 reward; right receives +15.0 cross-divider penalty
    assert score_right - score_left >= 18.0
    assert score_left < score_right


def test_access_ease_prioritizes_highway_rnr_over_indoor_mall() -> None:
    """Highway R&R / Open Bay chargers must rank ahead of indoor/multi-storey parking garages."""
    rnr = make_station(
        31, "Gentari RSA Ayer Keroh", "PLUS E2", 2.21, 102.24, 120.0, "Highway R&R / Open Bay"
    )
    mall = make_station(
        32,
        "Gentari Mahkota Parade Mall",
        "Bandar Hilir",
        2.21,
        102.24,
        120.0,
        "Multi-Storey / Indoor Carpark",
    )

    score_rnr = score_candidate_station(rnr, detour_km=0.5, side="center", cross_track_m=0.0)
    score_mall = score_candidate_station(mall, detour_km=0.5, side="center", cross_track_m=0.0)

    # R&R receives -4.0 access bonus, Mall receives +2.5 penalty (lower score is better)
    assert score_rnr < score_mall

    # If prefer_easy_access is True, mall penalty escalates to +8.0
    score_mall_strict = score_candidate_station(
        mall, detour_km=0.5, side="center", cross_track_m=0.0, prefer_easy_access=True
    )
    assert score_mall_strict > score_mall
    assert score_mall_strict - score_rnr >= 12.0


def test_deterministic_tie_breaker_first_vs_second_click() -> None:
    """Shuffled input stations must produce 100% identical candidate ranking and tie-breakers."""
    points = [
        LatLngPoint(latitude=3.1000, longitude=101.7000),
        LatLngPoint(latitude=3.2000, longitude=101.7000),
        LatLngPoint(latitude=3.3000, longitude=101.7000),
    ]

    base_stations = [
        make_station(101, "Charger Alpha", "PLUS E1 KM 10", 3.1200, 101.7010, 120.0),
        make_station(102, "Charger Beta", "PLUS E1 KM 15", 3.1500, 101.7010, 120.0),
        make_station(103, "Charger Gamma", "PLUS E1 KM 20", 3.1800, 101.7010, 120.0),
        make_station(104, "Charger Delta", "PLUS E1 KM 25", 3.2200, 101.7010, 120.0),
        make_station(105, "Charger Epsilon", "PLUS E1 KM 30", 3.2500, 101.7010, 120.0),
    ]

    candidates_first = build_corridor_candidates(base_stations, points, 3.1000, 3.3000, 5.0)

    # Shuffle the input order multiple times
    for seed in (42, 999, 1337):
        shuffled = list(base_stations)
        random.Random(seed).shuffle(shuffled)
        candidates_shuffled = build_corridor_candidates(shuffled, points, 3.1000, 3.3000, 5.0)

        assert [c.station.id for c in candidates_shuffled] == [
            c.station.id for c in candidates_first
        ]
        assert [c.score for c in candidates_shuffled] == [c.score for c in candidates_first]
        assert [c.dist for c in candidates_shuffled] == [c.dist for c in candidates_first]
