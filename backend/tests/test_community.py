"""Asynchronous tests for community submissions, reviews, and Survei Mikro consensus."""

import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_community_station_submission_and_moderation_approval(
    async_client: AsyncClient,
) -> None:
    """Verify community station starts unverified, lists in pending, and becomes verified upon approval."""
    payload = {
        "name": "Subang Parade Hidden AC Charger",
        "operator_name": "chargEV",
        "address": "Jalan Kemajuan Subang, SS16, 47500 Subang Jaya, Selangor",
        "city": "Subang Jaya",
        "state": "Selangor",
        "latitude": 3.0818,
        "longitude": 101.5838,
        "plug_types": [{"type": "Type 2", "power_kw": 22.0, "count": 2}],
        "max_power_kw": 22.0,
        "is_available": True,
        "is_24_hours": False,
        "parking_level": "Basement 2, Pillar P10",
        "how_to_access": [
            {
                "step_number": 1,
                "instruction": "Enter via carpark ramp opposite Empire Shopping Gallery.",
            }
        ],
    }

    # 1. Community submission (KF06)
    sub_res = await async_client.post("/api/v1/community/stations", json=payload)
    assert sub_res.status_code == 201
    created = sub_res.json()
    assert created["is_verified"] is False
    assert created["source"] == "community"
    station_id = created["id"]

    # 2. Check pending queue (KF09)
    pending_res = await async_client.get("/api/v1/community/stations/pending")
    assert pending_res.status_code == 200
    pending_ids = [s["id"] for s in pending_res.json()]
    assert station_id in pending_ids

    # 3. Moderate and approve
    mod_res = await async_client.patch(
        f"/api/v1/community/stations/{station_id}/moderate",
        json={"approve": True},
    )
    assert mod_res.status_code == 200
    approved = mod_res.json()
    assert approved["is_verified"] is True

    # 4. Confirm station is no longer in pending queue
    pending_after = await async_client.get("/api/v1/community/stations/pending")
    assert station_id not in [s["id"] for s in pending_after.json()]


@pytest.mark.asyncio
async def test_station_reviews_and_automatic_rating_recalculation(
    async_client: AsyncClient,
) -> None:
    """Verify posting reviews updates aggregate star rating and count (KF07)."""
    # Seed stations
    await async_client.post("/api/v1/stations/seed-sample")
    stations = (await async_client.get("/api/v1/stations")).json()
    station_id = stations[0]["id"]

    # Review 1: 5 stars
    r1_payload = {
        "rating": 5,
        "comment": "Super fast charging, was able to top up 10% to 80% in 22 mins.",
        "author_name": "Nazrin",
        "working_status": "working",
    }
    res1 = await async_client.post(
        f"/api/v1/community/stations/{station_id}/reviews",
        json=r1_payload,
    )
    assert res1.status_code == 201

    # Review 2: 3 stars
    r2_payload = {
        "rating": 3,
        "comment": "Charger worked but parking lot was crowded.",
        "author_name": "Farah",
        "working_status": "partial",
    }
    res2 = await async_client.post(
        f"/api/v1/community/stations/{station_id}/reviews",
        json=r2_payload,
    )
    assert res2.status_code == 201

    # Verify list reviews
    reviews_res = await async_client.get(f"/api/v1/community/stations/{station_id}/reviews")
    assert reviews_res.status_code == 200
    assert len(reviews_res.json()) >= 2

    # Verify station aggregate rating is (5+3)/2 = 4.0 and review_count is 2
    station_res = await async_client.get(f"/api/v1/stations/{station_id}")
    station_data = station_res.json()
    assert station_data["rating"] == 4.0
    assert station_data["review_count"] == 2


@pytest.mark.asyncio
async def test_survei_mikro_consensus_engine_threshold(
    async_client: AsyncClient,
) -> None:
    """Verify 3-vote consensus triggers auto-update of station availability and parking (KF16)."""
    # Seed stations
    await async_client.post("/api/v1/stations/seed-sample")
    stations = (await async_client.get("/api/v1/stations")).json()
    station_id = stations[0]["id"]

    survey_payload = {
        "plug_working_status": "out_of_order",
        "parking_fee_status": "free",
        "access_difficulty": "hard_underground",
    }

    # Vote 1 (no consensus yet)
    v1_res = await async_client.post(
        f"/api/v1/community/stations/{station_id}/micro-survey",
        json=survey_payload,
    )
    assert v1_res.status_code == 200
    v1_data = v1_res.json()
    assert v1_data["total_votes"] == 1
    assert v1_data["consensus_plug_status"] is None
    assert v1_data["station_auto_updated"] is False

    # Vote 2 (no consensus yet)
    await async_client.post(
        f"/api/v1/community/stations/{station_id}/micro-survey",
        json=survey_payload,
    )

    # Vote 3 (threshold N >= 3 met!)
    v3_res = await async_client.post(
        f"/api/v1/community/stations/{station_id}/micro-survey",
        json=survey_payload,
    )
    assert v3_res.status_code == 200
    v3_data = v3_res.json()
    assert v3_data["total_votes"] == 3
    assert v3_data["consensus_plug_status"] == "out_of_order"
    assert v3_data["consensus_parking_status"] == "free"
    assert v3_data["consensus_access_difficulty"] == "hard_underground"
    assert v3_data["station_auto_updated"] is True

    # Verify station record was automatically updated by consensus engine
    station_res = await async_client.get(f"/api/v1/stations/{station_id}")
    station_data = station_res.json()
    assert station_data["is_available"] is False
    assert station_data["parking_fee_myr"] == 0.0
