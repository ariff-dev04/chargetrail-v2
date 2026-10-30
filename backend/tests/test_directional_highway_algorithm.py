"""Benchmark and unit test suite for directional highway R&R scoring algorithm."""

import random
import uuid

from app.schemas.routing import LatLngPoint, RoutePlanRequest
from app.schemas.station import StationRead
from app.services.directional_highway_scorer import (
    build_corridor_candidates,
    compute_cross_track_side,
    is_opposite_highway_direction,
    score_candidate_station,
)
from app.services.route_planner_service import RoutePlannerService, _CorridorCandidate


def mk_st(
    id: int, name: str, addr: str, lat: float, lng: float, kw: float = 120.0, lvl: str = "Open Bay"
) -> StationRead:
    """Helper to instantiate StationRead fixtures for corridor tests."""
    full_addr = addr if len(addr) >= 5 else f"{addr} Highway"
    return StationRead(
        id=uuid.UUID(int=id),
        name=name,
        address=full_addr,
        city="Hwy",
        state="Sel",
        latitude=lat,
        longitude=lng,
        max_power_kw=kw,
        parking_level=lvl,
        parking_fee_myr=0.0,
    )


def test_plus_e2_northbound_excludes_southbound_rnr() -> None:
    """Driving Northbound on PLUS E2 must exclude Southbound R&Rs across the divider."""
    pts = [
        LatLngPoint(latitude=lat, longitude=lng)
        for lat, lng in [
            (1.4927, 103.7414),
            (2.196, 102.2405),
            (2.7258, 101.9424),
            (3.1578, 101.7118),
        ]
    ]
    sbs = [
        mk_st(1, "Gentari R&R Seremban (Southbound)", "E2 SB", 2.715, 101.945),
        mk_st(2, "ChargEV RSA Ayer Keroh Arah Selatan", "E2 S", 2.21, 102.245),
        mk_st(3, "Shell Recharge R&R Pagoh SB", "E2 SB", 2.15, 102.77),
    ]
    nbs = [
        mk_st(4, "Gentari R&R Seremban (Northbound)", "E2 NB", 2.715, 101.943),
        mk_st(5, "ChargEV RSA Ayer Keroh Arah Utara", "E2 U", 2.21, 102.24),
    ]

    for st in sbs:
        assert is_opposite_highway_direction(st.name, st.address, segment_bearing_deg=330.0) is True
    for st in nbs:
        assert (
            is_opposite_highway_direction(st.name, st.address, segment_bearing_deg=330.0) is False
        )

    candidates = build_corridor_candidates(
        stations=sbs + nbs, points=pts, origin_lat=1.4927, dest_lat=3.1578, max_corridor_detour=5.0
    )
    cand_names = [c.station.name for c in candidates]
    for st in sbs:
        assert st.name not in cand_names
    for st in nbs:
        assert st.name in cand_names


def test_plus_e1_southbound_excludes_northbound_rnr() -> None:
    """Driving Southbound on PLUS E1 must exclude Northbound R&Rs."""
    pts = [
        LatLngPoint(latitude=lat, longitude=lng)
        for lat, lng in [
            (4.5975, 101.0901),
            (4.20, 101.26),
            (3.70, 101.52),
            (3.32, 101.574),
            (3.1578, 101.7118),
        ]
    ]
    nbs = [
        mk_st(11, "R&R Tapah Northbound", "E1 NB", 4.2005, 101.261),
        mk_st(12, "RSA Rawang Arah Utara", "E1 NB", 3.32, 101.575),
        mk_st(13, "Hentian Sebelah Behrang (NB)", "E1 NB", 3.74, 101.51),
    ]
    sbs = [
        mk_st(14, "R&R Tapah Southbound", "E1 SB", 4.2005, 101.259),
        mk_st(15, "RSA Rawang Arah Selatan", "E1 SB", 3.32, 101.573),
    ]

    for st in nbs:
        assert is_opposite_highway_direction(st.name, st.address, segment_bearing_deg=155.0) is True
    for st in sbs:
        assert (
            is_opposite_highway_direction(st.name, st.address, segment_bearing_deg=155.0) is False
        )

    candidates = build_corridor_candidates(
        stations=nbs + sbs, points=pts, origin_lat=4.5975, dest_lat=3.1578, max_corridor_detour=5.0
    )
    cand_names = [c.station.name for c in candidates]
    for st in nbs:
        assert st.name not in cand_names
    for st in sbs:
        assert st.name in cand_names


def test_lpt_karak_e8_eastbound_vs_westbound_bilingual() -> None:
    """Bilingual Eastbound and Westbound tags must match directional bearings accurately."""
    eb, wb = 75.0, 255.0
    for name in ["Karak R&R Arah Barat", "Shell R&R Temerloh Westbound", "Petronas Gambang (WB)"]:
        assert is_opposite_highway_direction(name, "LPT1 E8", eb) is True
        assert is_opposite_highway_direction(name, "LPT1 E8", wb) is False
    for name in ["Karak R&R Arah Timur", "Shell R&R Temerloh Eastbound", "Petronas Gambang (EB)"]:
        assert is_opposite_highway_direction(name, "LPT1 E8", wb) is True
        assert is_opposite_highway_direction(name, "LPT1 E8", eb) is False
    assert is_opposite_highway_direction("Petronas Lebuhraya Timur-Barat", "Gerik", eb) is False
    assert is_opposite_highway_direction("Shell Lebuhraya Utara-Selatan", "PLUS", eb) is False


def test_malaysia_keep_left_carriageway_cross_divider_penalty() -> None:
    """Unlabeled R&Rs across highway divider (>80m right) receive +15.0 penalty over left side."""
    p1, p2 = (2.85, 101.62), (2.87, 101.62)
    left_st = mk_st(21, "ChargEV R&R Dengkil", "ELITE", 2.86, 101.6188)
    right_st = mk_st(22, "ChargEV R&R Dengkil", "ELITE", 2.86, 101.6212)

    assert compute_cross_track_side(p1, p2, left_st.latitude, left_st.longitude) == "left"
    assert compute_cross_track_side(p1, p2, right_st.latitude, right_st.longitude) == "right"

    sc_l = score_candidate_station(left_st, detour_km=0.1, side="left", cross_track_m=130.0)
    sc_r = score_candidate_station(right_st, detour_km=0.1, side="right", cross_track_m=130.0)
    assert sc_r - sc_l >= 18.0
    assert sc_l < sc_r


def test_access_ease_prioritizes_highway_rnr_over_indoor_mall() -> None:
    """Highway R&R / Open Bay chargers must rank ahead of indoor/multi-storey parking garages."""
    rnr = mk_st(
        31, "Gentari RSA Ayer Keroh", "PLUS E2", 2.21, 102.24, 120.0, "Highway R&R / Open Bay"
    )
    mall = mk_st(
        32,
        "Gentari Mahkota Parade Mall",
        "Bandar Hilir",
        2.21,
        102.24,
        120.0,
        "Multi-Storey / Indoor Carpark",
    )

    sc_rnr = score_candidate_station(rnr, detour_km=0.5, side="center")
    sc_mall = score_candidate_station(mall, detour_km=0.5, side="center")
    assert sc_rnr < sc_mall

    sc_strict = score_candidate_station(mall, detour_km=0.5, side="center", prefer_easy_access=True)
    assert sc_strict - sc_rnr >= 12.0


def test_deterministic_tie_breaker_first_vs_second_click() -> None:
    """Shuffled input stations must produce 100% identical candidate ranking and tie-breakers."""
    pts = [LatLngPoint(latitude=lat, longitude=101.7) for lat in [3.1, 3.2, 3.3]]
    base = [mk_st(100 + i, f"Chg {i}", "PLUS", 3.12 + i * 0.03, 101.7) for i in range(4)]
    first = build_corridor_candidates(base, pts, 3.1, 3.3, 5.0)

    for seed in (42, 999, 1337):
        shuffled = list(base)
        random.Random(seed).shuffle(shuffled)
        res = build_corridor_candidates(shuffled, pts, 3.1, 3.3, 5.0)
        assert [c.station.id for c in res] == [c.station.id for c in first]
        assert [c.score for c in res] == [c.score for c in first]


def test_stop_strategy_thresholds_and_charge_targets() -> None:
    """Verify few_long (95%), quickest (80%), and short_many (65%) stop strategies."""
    c1 = _CorridorCandidate(
        station=mk_st(201, "C1", "E1", 3.2, 101.7, 150.0), dist=140.0, detour=0.1, score=-10.0
    )
    c2 = _CorridorCandidate(
        station=mk_st(202, "C2", "E1", 3.8, 101.7, 150.0), dist=230.0, detour=0.1, score=-10.0
    )
    pts = [LatLngPoint(latitude=3.1, longitude=101.7), LatLngPoint(latitude=4.5, longitude=101.7)]
    specs = (60.0, 150.0, 150.0, 15)
    p = RoutePlannerService.__new__(RoutePlannerService)

    def eval_strat(s: str) -> int:
        req = RoutePlanRequest(
            origin_name="A",
            origin_lat=3.1,
            origin_lng=101.7,
            destination_name="B",
            destination_lat=4.5,
            destination_lng=101.7,
            starting_soc_percent=50,
            stop_strategy=s,
            target_arrival_soc_pct=15.0,
        )
        stops, _, _ = p._optimize_charging_stops([c1, c2], req, 300.0, pts, specs, -25, "critical")
        return stops[0].departure_soc_percent

    assert eval_strat("few_long") == 95
    assert eval_strat("quickest") == 80
    assert eval_strat("short_many") == 65


def test_tesla_driver_prioritizes_exit_supercharger_and_preserves_standard_ev_rnr() -> None:
    """Non-Tesla EV prefers direct highway R&R, while Tesla EV prioritizes exit Supercharger."""
    rnr = mk_st(301, "Gentari R&R (NB)", "PLUS E2", 2.4, 102.2, 120.0, "Highway R&R / Open Bay")
    tesla = mk_st(302, "Tesla Supercharger", "Exit", 2.4, 102.23, 250.0, "Multi-Storey / Carpark")

    # 1. Non-Tesla driver: direct R&R beats mall/indoor Tesla Supercharger
    sc_non_rnr = score_candidate_station(rnr, 0.3, "left", prefer_easy_access=True)
    sc_non_sc = score_candidate_station(tesla, 3.2, "center", prefer_easy_access=True)
    assert sc_non_rnr < sc_non_sc

    # 2. Tesla driver: carpark penalty is bypassed and affinity bonus is granted
    sc_tes_rnr = score_candidate_station(
        rnr, 0.3, "left", prefer_easy_access=True, is_tesla_driver=True
    )
    sc_tes_sc = score_candidate_station(
        tesla, 3.2, "center", prefer_easy_access=True, is_tesla_driver=True
    )
    assert sc_tes_sc < sc_tes_rnr
    assert sc_non_rnr == sc_tes_rnr

    # 3. Corridor candidates filtering with 2.5 km threshold
    pts = [
        LatLngPoint(latitude=lat, longitude=lng)
        for lat, lng in [(2.2, 102.2), (2.4, 102.2), (2.6, 102.2)]
    ]
    cand_std = build_corridor_candidates([rnr, tesla], pts, 2.2, 2.6, 2.5, is_tesla_driver=False)
    assert [c.station.name for c in cand_std] == [rnr.name]

    cand_tesla = build_corridor_candidates([rnr, tesla], pts, 2.2, 2.6, 2.5, is_tesla_driver=True)
    cand_names = [c.station.name for c in cand_tesla]
    assert tesla.name in cand_names and rnr.name in cand_names
