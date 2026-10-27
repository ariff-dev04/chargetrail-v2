"""Asynchronous tests for Malaysian place geocoding and battery-aware route planning."""

import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_search_malaysian_places(async_client: AsyncClient) -> None:
    """Verify place search returns geocoded Malaysian landmarks and cities (KF10)."""
    # 1. Search for Penang
    penang_res = await async_client.get("/api/v1/routing/places", params={"q": "Penang"})
    assert penang_res.status_code == 200
    penang_places = penang_res.json()
    assert len(penang_places) >= 1
    assert any("Penang" in p["state"] or "Penang" in p["name"] for p in penang_places)

    # 2. Search for KLCC
    kl_res = await async_client.get("/api/v1/routing/places", params={"q": "KLCC"})
    assert kl_res.status_code == 200
    assert any("KLCC" in p["name"] for p in kl_res.json())

    # 3. Search for Tapah RSA highway stop
    tapah_res = await async_client.get("/api/v1/routing/places", params={"q": "Tapah"})
    assert tapah_res.status_code == 200
    assert any("Tapah" in p["city"] for p in tapah_res.json())


@pytest.mark.asyncio
async def test_short_urban_route_safe_range(async_client: AsyncClient) -> None:
    """Verify short urban trip (KL -> Putrajaya) classifies as safe without charging stops (KF14)."""
    payload = {
        "origin_name": "Kuala Lumpur (KLCC)",
        "origin_lat": 3.1578,
        "origin_lng": 101.7118,
        "destination_name": "Putrajaya (IOI City Mall)",
        "destination_lat": 2.9698,
        "destination_lng": 101.7135,
        "starting_soc_percent": 80,
        "battery_capacity_kwh": 60.48,
        "efficiency_wh_per_km": 144.0,
        "max_dc_charge_kw": 88.0,
        "reserve_soc_percent": 15,
    }

    res = await async_client.post("/api/v1/routing/plan", json=payload)
    assert res.status_code == 200
    plan = res.json()

    assert plan["range_anxiety_status"] == "safe"
    assert len(plan["recommended_stops"]) == 0
    assert plan["total_charging_minutes"] == 0
    assert plan["final_arrival_soc_percent"] > 60
    assert len(plan["polyline_points"]) >= 2
    assert "safe" in plan["status_summary"].lower()


@pytest.mark.asyncio
async def test_long_highway_route_recommends_charging_stop(async_client: AsyncClient) -> None:
    """Verify long interstate route (KL -> Penang) triggers charging recommendation at Tapah (KF15)."""
    # 1. Seed Malaysian charging stations
    await async_client.post("/api/v1/stations/seed-sample")

    # 2. Route from KLCC (3.1578, 101.7118) to Penang (5.4372, 100.3096) with low starting battery (55%)
    payload = {
        "origin_name": "Kuala Lumpur (KLCC)",
        "origin_lat": 3.1578,
        "origin_lng": 101.7118,
        "destination_name": "Penang (Gurney Plaza)",
        "destination_lat": 5.4372,
        "destination_lng": 100.3096,
        "starting_soc_percent": 55,
        "battery_capacity_kwh": 60.48,
        "efficiency_wh_per_km": 144.0,
        "max_dc_charge_kw": 88.0,
        "reserve_soc_percent": 15,
        "corridor_radius_km": 25.0,
    }

    res = await async_client.post("/api/v1/routing/plan", json=payload)
    assert res.status_code == 200
    plan = res.json()

    # Route distance should be ~350+ km
    assert plan["total_distance_km"] > 300.0
    assert plan["range_anxiety_status"] == "critical_charging_required"

    # Must automatically recommend at least one charging stop along the PLUS highway
    assert len(plan["recommended_stops"]) >= 1

    recommended_station_names = [s["station"]["name"] for s in plan["recommended_stops"]]
    assert "TNB Electron Tapah R&R Northbound" in recommended_station_names

    # Verify no Southbound stations in corridor stations for Northbound travel
    corridor_names = [s["name"] for s in plan["corridor_stations"]]
    assert not any("southbound" in n.lower() or "arah selatan" in n.lower() for n in corridor_names)

    stop = plan["recommended_stops"][0]
    assert stop["arrival_soc_percent"] >= 5
    assert stop["departure_soc_percent"] >= 75
    assert stop["estimated_charge_minutes"] > 0
    assert stop["estimated_cost_myr"] > 0
    assert stop["corridor_lat"] is not None
    assert stop["corridor_lng"] is not None
    assert len(stop["nearby_alternatives"]) >= 1
    alt_names = [a["name"] for a in stop["nearby_alternatives"]]
    assert any("Simpang Pulai" in n or "Ipoh" in n for n in alt_names)

    # Charging stops must ensure final arrival SoC satisfies safety buffer
    assert plan["final_arrival_soc_percent"] >= 15
    assert plan["total_charging_minutes"] > 0
    assert plan["total_trip_minutes"] > plan["estimated_drive_minutes"]


@pytest.mark.asyncio
async def test_route_planning_with_preferred_stop_station(async_client: AsyncClient) -> None:
    """Verify specifying preferred_stop_station_ids prioritizes that station."""
    await async_client.post("/api/v1/stations/seed-sample")
    stations_res = await async_client.get("/api/v1/stations")
    simpang_pulai = next(s for s in stations_res.json() if "Simpang Pulai" in s["name"])

    payload = {
        "origin_name": "Kuala Lumpur (KLCC)",
        "origin_lat": 3.1578,
        "origin_lng": 101.7118,
        "destination_name": "Penang (Gurney Plaza)",
        "destination_lat": 5.4372,
        "destination_lng": 100.3096,
        "starting_soc_percent": 55,
        "battery_capacity_kwh": 60.48,
        "efficiency_wh_per_km": 144.0,
        "max_dc_charge_kw": 88.0,
        "reserve_soc_percent": 15,
        "corridor_radius_km": 25.0,
        "preferred_stop_station_ids": [simpang_pulai["id"]],
    }

    res = await async_client.post("/api/v1/routing/plan", json=payload)
    assert res.status_code == 200
    plan = res.json()
    assert len(plan["recommended_stops"]) >= 1
    assert plan["recommended_stops"][0]["station"]["id"] == simpang_pulai["id"]


@pytest.mark.asyncio
async def test_route_planning_with_garage_vehicle_override(async_client: AsyncClient) -> None:
    """Verify route planning resolves vehicle specifications from garage vehicle_id."""
    # 1. Create custom vehicle in garage
    veh_payload = {
        "brand": "Tesla",
        "model_name": "Model 3 Long Range AWD",
        "battery_capacity_kwh": 75.0,
        "usable_range_km": 629.0,
        "efficiency_wh_per_km": 125.0,
        "max_dc_charge_kw": 250.0,
        "reserve_soc_percent": 10,
    }
    veh_res = await async_client.post("/api/v1/vehicles", json=veh_payload)
    assert veh_res.status_code == 201
    vehicle_id = veh_res.json()["id"]

    # 2. Plan route using vehicle_id
    plan_payload = {
        "origin_name": "KLCC",
        "origin_lat": 3.1578,
        "origin_lng": 101.7118,
        "destination_name": "Putrajaya",
        "destination_lat": 2.9698,
        "destination_lng": 101.7135,
        "vehicle_id": vehicle_id,
        "starting_soc_percent": 90,
    }

    res = await async_client.post("/api/v1/routing/plan", json=plan_payload)
    assert res.status_code == 200
    plan = res.json()
    assert "Tesla Model 3 Long Range AWD" in plan["vehicle_summary"]
