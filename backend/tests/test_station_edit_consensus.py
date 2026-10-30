"""Tests for suggested station edits and community consensus auto-mutation."""

import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_suggest_station_edit_creates_pending_proposal(async_client: AsyncClient) -> None:
    """Submitting a suggested edit creates a pending proposal and lists in pending-edits."""
    # Create baseline charging station
    st_res = await async_client.post(
        "/api/v1/community/stations",
        json={
            "name": "Pavilion KL Basement Charger",
            "address": "168 Jalan Bukit Bintang",
            "city": "Kuala Lumpur",
            "state": "Wilayah Persekutuan",
            "latitude": 3.1488,
            "longitude": 101.7133,
            "max_power_kw": 120.0,
            "plug_types": [{"type": "CCS2", "power_kw": 120.0, "count": 2}],
            "charging_cost_myr": 1.20,
            "parking_fee_myr": 5.0,
            "parking_level": "Basement B1",
            "description": "Initial description",
            "amenities": ["Shopping", "Dining"],
        },
    )
    assert st_res.status_code == 201
    station_id = st_res.json()["id"]

    # Submit edit suggestion
    edit_payload = {
        "parking_level": "Basement B2",
        "description": "Enter via Basement B2 Pillar G4",
        "price_per_kwh": 1.45,
        "amenities": ["Shopping", "Dining", "Surau"],
    }
    suggest_res = await async_client.post(
        f"/api/v1/community/stations/{station_id}/suggest-edit",
        json=edit_payload,
    )
    assert suggest_res.status_code == 201
    proposal = suggest_res.json()
    assert proposal["status"] == "pending"
    assert proposal["parking_level"] == "Basement B2"
    assert proposal["description"] == "Enter via Basement B2 Pillar G4"
    assert proposal["price_per_kwh"] == 1.45
    assert proposal["confirm_votes"] == 0

    # Retrieve pending edits for this station
    pending_res = await async_client.get(f"/api/v1/community/stations/{station_id}/pending-edits")
    assert pending_res.status_code == 200
    pending_list = pending_res.json()
    assert any(p["id"] == proposal["id"] for p in pending_list)

    # Check moderation queue lists the proposal
    queue_res = await async_client.get("/api/v1/community/moderation-queue")
    assert queue_res.status_code == 200
    assert any(p["id"] == proposal["id"] for p in queue_res.json())


@pytest.mark.asyncio
async def test_consensus_auto_mutates_station_on_3_confirm_votes(async_client: AsyncClient) -> None:
    """Casting 3 confirm votes approves proposal and auto-mutates live station record."""
    st_res = await async_client.post(
        "/api/v1/community/stations",
        json={
            "name": "Mid Valley Megamall Level P2",
            "address": "Lingkaran Syed Putra",
            "city": "Kuala Lumpur",
            "state": "Wilayah Persekutuan",
            "latitude": 3.1180,
            "longitude": 101.6780,
            "max_power_kw": 50.0,
            "plug_types": [{"type": "Type 2", "power_kw": 22.0, "count": 2}],
            "charging_cost_myr": 1.00,
            "parking_fee_myr": 3.0,
            "parking_level": "Level P2",
            "description": "Original text",
        },
    )
    station_id = st_res.json()["id"]

    # Propose updated access and price
    suggest_res = await async_client.post(
        f"/api/v1/community/stations/{station_id}/suggest-edit",
        json={
            "parking_level": "Zone C Level P3 Pillar 12",
            "description": "Upgraded to 150kW DC Fast Charger with Autocharge support",
            "price_per_kwh": 1.55,
            "max_power_kw": 150.0,
        },
    )
    edit_id = suggest_res.json()["id"]

    # Cast 3 confirm votes from different community drivers
    for idx in range(3):
        vote_res = await async_client.post(
            f"/api/v1/community/edits/{edit_id}/vote",
            json={"vote": "confirm", "voter_token": f"driver_token_{idx}"},
        )
        assert vote_res.status_code == 200

    approved_proposal = vote_res.json()
    assert approved_proposal["status"] == "approved"
    assert approved_proposal["confirm_votes"] == 3

    # Fetch live station record and assert auto-mutation occurred
    live_st_res = await async_client.get(f"/api/v1/stations/{station_id}")
    assert live_st_res.status_code == 200
    live_data = live_st_res.json()

    assert live_data["parking_level"] == "Zone C Level P3 Pillar 12"
    assert live_data["description"] == "Upgraded to 150kW DC Fast Charger with Autocharge support"
    assert live_data["price_per_kwh"] == 1.55
    assert live_data["max_power_kw"] == 150.0
    assert live_data["is_community_verified"] is True


@pytest.mark.asyncio
async def test_moderator_fast_track_approval_applies_edit_in_one_click(
    async_client: AsyncClient,
) -> None:
    """Moderator fast-track approval approves and applies edit immediately."""
    st_res = await async_client.post(
        "/api/v1/community/stations",
        json={
            "name": "Sunway Pyramid Blue Atrium",
            "address": "3 Jalan PJS 11/15",
            "city": "Petaling Jaya",
            "state": "Selangor",
            "latitude": 3.0733,
            "longitude": 101.6078,
            "max_power_kw": 60.0,
            "plug_types": [{"type": "CCS2", "power_kw": 60.0, "count": 2}],
            "charging_cost_myr": 1.30,
            "parking_fee_myr": 4.0,
            "parking_level": "B1 Blue",
            "description": "Atrium charger",
        },
    )
    station_id = st_res.json()["id"]

    suggest_res = await async_client.post(
        f"/api/v1/community/stations/{station_id}/suggest-edit",
        json={
            "parking_level": "Level B1 Blue Bay 14-16",
            "description": "Fast-track verified by admin: 24/7 security guard present",
            "price_per_kwh": 1.40,
            "is_operational": True,
        },
    )
    edit_id = suggest_res.json()["id"]

    # 1-Click fast track approval
    fast_res = await async_client.post(
        f"/api/v1/community/edits/{edit_id}/vote",
        json={"vote": "confirm", "fast_track_approve": True},
    )
    assert fast_res.status_code == 200
    assert fast_res.json()["status"] == "approved"

    # Verify live station record
    live_res = await async_client.get(f"/api/v1/stations/{station_id}")
    assert live_res.status_code == 200
    live_st = live_res.json()
    assert live_st["parking_level"] == "Level B1 Blue Bay 14-16"
    assert live_st["description"] == "Fast-track verified by admin: 24/7 security guard present"
    assert live_st["price_per_kwh"] == 1.40
    assert live_st["is_community_verified"] is True
