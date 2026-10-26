"""Asynchronous tests for authentication, profiles, and station bookmarks."""

import uuid

import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_user_registration_and_duplicate_conflict(async_client: AsyncClient) -> None:
    """Verify user registration succeeds with 201 and rejects duplicate emails with 409."""
    payload = {
        "email": "driver.my@chargetrail.com",
        "password": "Password123!",
        "full_name": "Ariff Azman",
        "phone_number": "+60123456789",
        "preferred_connector": "CCS2",
    }

    # Successful registration
    reg_res = await async_client.post("/api/v1/auth/register", json=payload)
    assert reg_res.status_code == 201
    data = reg_res.json()
    assert "access_token" in data
    assert data["token_type"] == "bearer"
    assert data["user"]["email"] == "driver.my@chargetrail.com"
    assert data["user"]["full_name"] == "Ariff Azman"
    assert data["user"]["preferred_connector"] == "CCS2"

    # Duplicate registration rejected
    dup_res = await async_client.post("/api/v1/auth/register", json=payload)
    assert dup_res.status_code == 409
    assert "already exists" in dup_res.json()["detail"].lower()


@pytest.mark.asyncio
async def test_user_login_success_and_invalid_credentials(async_client: AsyncClient) -> None:
    """Verify authentication succeeds with valid credentials and fails on wrong password."""
    # Register test user
    reg_payload = {
        "email": "login.test@chargetrail.com",
        "password": "CorrectPassword123",
        "full_name": "Siti Nurhaliza",
    }
    await async_client.post("/api/v1/auth/register", json=reg_payload)

    # Valid login
    login_res = await async_client.post(
        "/api/v1/auth/login",
        json={"email": "login.test@chargetrail.com", "password": "CorrectPassword123"},
    )
    assert login_res.status_code == 200
    token_data = login_res.json()
    assert "access_token" in token_data
    assert token_data["user"]["full_name"] == "Siti Nurhaliza"

    # Incorrect password
    bad_pass_res = await async_client.post(
        "/api/v1/auth/login",
        json={"email": "login.test@chargetrail.com", "password": "WrongPassword999"},
    )
    assert bad_pass_res.status_code == 401
    assert "invalid email or password" in bad_pass_res.json()["detail"].lower()

    # Non-existent user
    unknown_user_res = await async_client.post(
        "/api/v1/auth/login",
        json={"email": "nobody@nowhere.com", "password": "AnyPassword"},
    )
    assert unknown_user_res.status_code == 401


@pytest.mark.asyncio
async def test_user_profile_retrieval_and_update(async_client: AsyncClient) -> None:
    """Verify authenticated profile retrieval and mutable attribute updates."""
    # Register and obtain token
    reg_payload = {
        "email": "profile.test@chargetrail.com",
        "password": "Password123!",
        "full_name": "Tan Sri Lim",
        "preferred_connector": "CCS2",
    }
    reg_res = await async_client.post("/api/v1/auth/register", json=reg_payload)
    token = reg_res.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    # Fetch profile
    me_res = await async_client.get("/api/v1/users/me", headers=headers)
    assert me_res.status_code == 200
    profile = me_res.json()
    assert profile["full_name"] == "Tan Sri Lim"
    assert profile["preferred_connector"] == "CCS2"
    assert profile["saved_station_ids"] == []

    # Update profile
    patch_payload = {
        "full_name": "Dato Lim Wei",
        "phone_number": "+60198765432",
        "preferred_connector": "CHAdeMO",
    }
    patch_res = await async_client.patch("/api/v1/users/me", json=patch_payload, headers=headers)
    assert patch_res.status_code == 200
    updated = patch_res.json()
    assert updated["full_name"] == "Dato Lim Wei"
    assert updated["phone_number"] == "+60198765432"
    assert updated["preferred_connector"] == "CHAdeMO"


@pytest.mark.asyncio
async def test_station_bookmark_toggle_and_listing(async_client: AsyncClient) -> None:
    """Verify toggling bookmarks (save and remove) and querying saved stations."""
    # 1. Seed Malaysian stations
    await async_client.post("/api/v1/stations/seed-sample")
    stations_res = await async_client.get("/api/v1/stations")
    target_station = stations_res.json()[0]
    target_id = target_station["id"]

    # 2. Register user
    user_payload = {
        "email": "bookmark.user@chargetrail.com",
        "password": "Password123!",
        "full_name": "Kumar Sangakkara",
    }
    reg_res = await async_client.post("/api/v1/auth/register", json=user_payload)
    token = reg_res.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    # 3. Bookmark station (save)
    save_res = await async_client.post(f"/api/v1/users/me/bookmarks/{target_id}", headers=headers)
    assert save_res.status_code == 200
    save_data = save_res.json()
    assert save_data["is_saved"] is True
    assert target_id in save_data["saved_station_ids"]

    # 4. List saved stations
    list_saved = await async_client.get("/api/v1/users/me/bookmarks", headers=headers)
    assert list_saved.status_code == 200
    saved_list = list_saved.json()
    assert len(saved_list) == 1
    assert saved_list[0]["id"] == target_id
    assert saved_list[0]["name"] == target_station["name"]

    # 5. Toggle bookmark again (un-save)
    unsave_res = await async_client.post(f"/api/v1/users/me/bookmarks/{target_id}", headers=headers)
    assert unsave_res.status_code == 200
    unsave_data = unsave_res.json()
    assert unsave_data["is_saved"] is False
    assert target_id not in unsave_data["saved_station_ids"]

    # 6. Verify list is now empty
    empty_saved = await async_client.get("/api/v1/users/me/bookmarks", headers=headers)
    assert empty_saved.status_code == 200
    assert len(empty_saved.json()) == 0

    # 7. Non-existent station 404
    non_existent_id = uuid.uuid4()
    not_found_res = await async_client.post(
        f"/api/v1/users/me/bookmarks/{non_existent_id}",
        headers=headers,
    )
    assert not_found_res.status_code == 404
