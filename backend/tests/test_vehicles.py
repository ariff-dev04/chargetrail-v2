"""Asynchronous test suite for EV Vehicle profiles, presets catalog, and garage management."""

import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_get_malaysian_ev_presets(async_client: AsyncClient) -> None:
    """Verify Malaysian EV preset catalog returns verified vehicles (KF11)."""
    response = await async_client.get("/api/v1/vehicles/presets")
    assert response.status_code == 200
    presets = response.json()
    assert len(presets) >= 6

    model_names = [p["model_name"] for p in presets]
    assert "e.MAS 7 Prime" in model_names
    assert "Atto 3 Extended Range" in model_names
    assert "Model 3 Long Range AWD" in model_names

    proton = next(p for p in presets if p["brand"] == "Proton")
    assert proton["battery_capacity_kwh"] == 60.22
    assert proton["connector_type"] == "CCS2"


@pytest.mark.asyncio
async def test_vehicle_creation_and_primary_toggling(async_client: AsyncClient) -> None:
    """Verify adding vehicles unsets existing primary when new primary is chosen (KF12)."""
    # 1. Create first vehicle (Proton e.MAS 7) as primary
    v1_payload = {
        "brand": "Proton",
        "model_name": "e.MAS 7 Prime",
        "nickname": "Daily Commuter",
        "battery_capacity_kwh": 60.22,
        "usable_range_km": 410.0,
        "efficiency_wh_per_km": 147.0,
        "max_dc_charge_kw": 100.0,
        "connector_type": "CCS2",
        "reserve_soc_percent": 15,
        "is_primary": True,
    }
    v1_res = await async_client.post("/api/v1/vehicles", json=v1_payload)
    assert v1_res.status_code == 201
    v1_data = v1_res.json()
    assert v1_data["is_primary"] is True
    v1_id = v1_data["id"]

    # 2. Create second vehicle (Tesla Model 3) as primary
    v2_payload = {
        "brand": "Tesla",
        "model_name": "Model 3 Long Range AWD",
        "nickname": "Roadtrip Cruiser",
        "battery_capacity_kwh": 75.0,
        "usable_range_km": 629.0,
        "efficiency_wh_per_km": 125.0,
        "max_dc_charge_kw": 250.0,
        "connector_type": "CCS2",
        "reserve_soc_percent": 10,
        "is_primary": True,
    }
    v2_res = await async_client.post("/api/v1/vehicles", json=v2_payload)
    assert v2_res.status_code == 201
    v2_data = v2_res.json()
    assert v2_data["is_primary"] is True
    v2_id = v2_data["id"]

    # 3. Verify first vehicle is no longer primary
    v1_check = await async_client.get(f"/api/v1/vehicles/{v1_id}")
    assert v1_check.status_code == 200
    assert v1_check.json()["is_primary"] is False

    # 4. Set first vehicle back to primary via /select endpoint
    select_res = await async_client.post(f"/api/v1/vehicles/{v1_id}/select")
    assert select_res.status_code == 200
    assert select_res.json()["is_primary"] is True

    # Confirm second vehicle is now unset
    v2_check = await async_client.get(f"/api/v1/vehicles/{v2_id}")
    assert v2_check.json()["is_primary"] is False


@pytest.mark.asyncio
async def test_vehicle_reserve_soc_and_effective_safe_range(async_client: AsyncClient) -> None:
    """Verify updating reserve SoC buffer percentage recomputes effective safe range (KF11)."""
    payload = {
        "brand": "BYD",
        "model_name": "Atto 3 Extended Range",
        "battery_capacity_kwh": 60.48,
        "usable_range_km": 420.0,
        "efficiency_wh_per_km": 144.0,
        "max_dc_charge_kw": 88.0,
        "reserve_soc_percent": 15,
    }
    create_res = await async_client.post("/api/v1/vehicles", json=payload)
    assert create_res.status_code == 201
    vehicle = create_res.json()
    vehicle_id = vehicle["id"]

    # 420 km * (100 - 15)% = 357.0 km
    assert vehicle["effective_safe_range_km"] == 357.0

    # Increase safety reserve to 20%
    update_res = await async_client.patch(
        f"/api/v1/vehicles/{vehicle_id}",
        json={"reserve_soc_percent": 20},
    )
    assert update_res.status_code == 200
    # 420 km * (100 - 20)% = 336.0 km
    assert update_res.json()["effective_safe_range_km"] == 336.0


@pytest.mark.asyncio
async def test_vehicle_deletion_from_garage(async_client: AsyncClient) -> None:
    """Verify deleting vehicle removes it from garage and returns 404 subsequently."""
    payload = {
        "brand": "Hyundai",
        "model_name": "IONIQ 5 Max AWD",
        "battery_capacity_kwh": 72.6,
        "usable_range_km": 430.0,
        "efficiency_wh_per_km": 169.0,
        "max_dc_charge_kw": 233.0,
    }
    create_res = await async_client.post("/api/v1/vehicles", json=payload)
    vehicle_id = create_res.json()["id"]

    # Delete vehicle
    del_res = await async_client.delete(f"/api/v1/vehicles/{vehicle_id}")
    assert del_res.status_code == 204

    # Verify not found
    get_res = await async_client.get(f"/api/v1/vehicles/{vehicle_id}")
    assert get_res.status_code == 404
