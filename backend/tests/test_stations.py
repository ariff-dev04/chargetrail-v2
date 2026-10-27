"""Comprehensive test suite for EV Charging Stations spatial queries, filters, and seeder."""

import uuid

import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_seed_sample_stations_and_idempotency(async_client: AsyncClient) -> None:
    """Verify that seeding inserts 14 stations and subsequent calls are idempotent."""
    # First seed invocation
    first_res = await async_client.post("/api/v1/stations/seed-sample")
    assert first_res.status_code == 201
    first_data = first_res.json()
    assert first_data["inserted_count"] == 14
    assert first_data["total_count"] == 14

    # Second seed invocation (should detect existing coordinates and not insert duplicates)
    second_res = await async_client.post("/api/v1/stations/seed-sample")
    assert second_res.status_code == 201
    second_data = second_res.json()
    assert second_data["inserted_count"] == 0
    assert second_data["total_count"] == 14


@pytest.mark.asyncio
async def test_list_stations_unfiltered(async_client: AsyncClient) -> None:
    """Verify listing stations without query filters returns all seeded stations."""
    await async_client.post("/api/v1/stations/seed-sample")

    response = await async_client.get("/api/v1/stations")
    assert response.status_code == 200
    stations = response.json()
    assert len(stations) == 14


@pytest.mark.asyncio
async def test_list_stations_viewport_bounding_box(async_client: AsyncClient) -> None:
    """Verify viewport bounding box query isolates stations within Klang Valley coordinates."""
    await async_client.post("/api/v1/stations/seed-sample")

    # Bounding box covering greater Kuala Lumpur / Selangor / Putrajaya region
    params = {
        "min_lat": 2.80,
        "max_lat": 3.30,
        "min_lng": 101.40,
        "max_lng": 101.90,
    }
    response = await async_client.get("/api/v1/stations", params=params)
    assert response.status_code == 200
    stations = response.json()

    station_names = {s["name"] for s in stations}
    assert "Suria KLCC Gentari Charging Hub" in station_names
    assert "IOI City Mall Putrajaya JomCharge" in station_names
    assert "Sunway Pyramid chargEV Station" in station_names

    # Ensure distant stations in Perak, Penang, and Johor are excluded
    assert "TNB Electron Tapah R&R Northbound" not in station_names
    assert "Gurney Plaza Shell Recharge" not in station_names
    assert "Mid Valley Southkey Gentari Hub" not in station_names


@pytest.mark.asyncio
async def test_list_stations_radius_proximity(async_client: AsyncClient) -> None:
    """Verify proximity search calculates distance_km and orders results nearest first."""
    await async_client.post("/api/v1/stations/seed-sample")

    # Origin at Suria KLCC coordinates
    params = {
        "lat": 3.1578,
        "lng": 101.7118,
        "radius_km": 15.0,
    }
    response = await async_client.get("/api/v1/stations", params=params)
    assert response.status_code == 200
    stations = response.json()

    assert len(stations) >= 1
    # First station must be Suria KLCC with distance ~ 0 km
    assert stations[0]["name"] == "Suria KLCC Gentari Charging Hub"
    assert stations[0]["distance_km"] == 0.0

    # Verify distances are populated and monotonically increasing
    distances = [s["distance_km"] for s in stations]
    assert all(d is not None for d in distances)
    assert distances == sorted(distances)


@pytest.mark.asyncio
async def test_list_stations_connector_type_filter(async_client: AsyncClient) -> None:
    """Verify filtering by connector type (CHAdeMO vs CCS2)."""
    await async_client.post("/api/v1/stations/seed-sample")

    # Only Mid Valley Southkey has a CHAdeMO plug
    chademo_res = await async_client.get("/api/v1/stations", params={"connector_type": "CHAdeMO"})
    assert chademo_res.status_code == 200
    chademo_stations = chademo_res.json()
    assert len(chademo_stations) == 1
    assert chademo_stations[0]["name"] == "Mid Valley Southkey Gentari Hub"

    # All seeded stations include CCS2
    ccs2_res = await async_client.get("/api/v1/stations", params={"connector_type": "CCS2"})
    assert ccs2_res.status_code == 200
    assert len(ccs2_res.json()) == 14


@pytest.mark.asyncio
async def test_list_stations_power_filter(async_client: AsyncClient) -> None:
    """Verify filtering stations by minimum power output in kW."""
    await async_client.post("/api/v1/stations/seed-sample")

    # Stations with at least 180kW DC chargers
    response = await async_client.get("/api/v1/stations", params={"min_kw": 180.0})
    assert response.status_code == 200
    stations = response.json()

    assert len(stations) == 5
    for station in stations:
        assert station["max_power_kw"] >= 180.0


@pytest.mark.asyncio
async def test_list_stations_amenity_filter(async_client: AsyncClient) -> None:
    """Verify filtering stations by nearby facility amenity tags."""
    await async_client.post("/api/v1/stations/seed-sample")

    # Tapah R&R and Seremban RSA include "Petrol Station" amenity
    petrol_res = await async_client.get("/api/v1/stations", params={"amenity": "Petrol Station"})
    assert petrol_res.status_code == 200
    petrol_stations = petrol_res.json()
    assert len(petrol_stations) == 4
    names = {s["name"] for s in petrol_stations}
    assert "TNB Electron Tapah R&R Northbound" in names
    assert "Shell Recharge Seremban RSA Southbound" in names

    # Multiple stations have "Dining"
    dining_res = await async_client.get("/api/v1/stations", params={"amenity": "Dining"})
    assert dining_res.status_code == 200
    assert len(dining_res.json()) >= 4


@pytest.mark.asyncio
async def test_list_stations_24_hours_filter(async_client: AsyncClient) -> None:
    """Verify filtering for stations operating 24 hours daily."""
    await async_client.post("/api/v1/stations/seed-sample")

    response = await async_client.get("/api/v1/stations", params={"is_24_hours": True})
    assert response.status_code == 200
    stations = response.json()

    assert len(stations) == 8
    for station in stations:
        assert station["is_24_hours"] is True


@pytest.mark.asyncio
async def test_get_station_by_id_and_not_found(async_client: AsyncClient) -> None:
    """Verify retrieving station by ID returns detailed how_to_access steps and 404 for unknown ID."""
    await async_client.post("/api/v1/stations/seed-sample")

    # Fetch station list to obtain a valid UUID
    list_res = await async_client.get("/api/v1/stations")
    stations = list_res.json()
    target_station = stations[0]
    station_id = target_station["id"]

    # Retrieve specific station by valid UUID
    detail_res = await async_client.get(f"/api/v1/stations/{station_id}")
    assert detail_res.status_code == 200
    detail = detail_res.json()
    assert detail["id"] == station_id
    assert detail["name"] == target_station["name"]
    assert "how_to_access" in detail
    assert len(detail["how_to_access"]) >= 2
    assert detail["how_to_access"][0]["step_number"] == 1
    assert "instruction" in detail["how_to_access"][0]

    # Query with non-existent UUID must return 404
    non_existent_id = uuid.uuid4()
    not_found_res = await async_client.get(f"/api/v1/stations/{non_existent_id}")
    assert not_found_res.status_code == 404
    assert "not found" in not_found_res.json()["detail"].lower()


@pytest.mark.asyncio
async def test_upsert_external_station_on_interaction(async_client: AsyncClient) -> None:
    """Verify that interacting with an external OSM station idempotently saves it to the DB."""
    osm_payload = {
        "name": "Kuala Lumpur Sentral EV Hub (OSM Live)",
        "operator_name": "OpenStreetMap Community",
        "address": "Jalan Stesen Sentral 5, Kuala Lumpur",
        "city": "Kuala Lumpur",
        "state": "Wilayah Persekutuan Kuala Lumpur",
        "latitude": 3.1340,
        "longitude": 101.6860,
        "plug_types": [{"type": "CCS2", "power_kw": 60.0, "count": 2}],
        "max_power_kw": 60.0,
        "is_available": True,
        "is_24_hours": True,
        "charging_cost_myr": 1.40,
        "parking_fee_myr": 0.0,
        "parking_level": "Outdoor Carpark",
        "operation_hours": "24 Hours",
        "amenities": ["Dining", "Restroom"],
        "how_to_access": [{"step_number": 1, "instruction": "Located via live OSM network."}],
        "source": "osm_live",
        "is_verified": False,
    }

    # 1. First interaction: inserts new station
    first_res = await async_client.post("/api/v1/stations/upsert-external", json=osm_payload)
    assert first_res.status_code == 200
    first_station = first_res.json()
    assert first_station["name"] == osm_payload["name"]
    station_id = first_station["id"]

    # 2. Second interaction: returns existing station without creating duplicates
    second_res = await async_client.post("/api/v1/stations/upsert-external", json=osm_payload)
    assert second_res.status_code == 200
    second_station = second_res.json()
    assert second_station["id"] == station_id


@pytest.mark.asyncio
async def test_upsert_batch_stations(async_client: AsyncClient) -> None:
    """Verify batch upsert persists multiple OSM stations and deduplicates."""
    batch_payload = [
        {
            "name": "Klang Valley OSM Charger Alpha",
            "operator_name": "OpenStreetMap Live",
            "address": "Jalan Ampang, Kuala Lumpur",
            "city": "Kuala Lumpur",
            "state": "Kuala Lumpur",
            "latitude": 3.1610,
            "longitude": 101.7140,
            "plug_types": [{"type": "CCS2", "power_kw": 60.0, "count": 2}],
            "max_power_kw": 60.0,
            "is_available": True,
            "is_24_hours": True,
            "charging_cost_myr": 1.40,
            "parking_fee_myr": 0.0,
            "parking_level": "Ground Bay",
            "operation_hours": "24 Hours",
            "amenities": ["Dining"],
            "how_to_access": [{"step_number": 1, "instruction": "Direct street access."}],
            "source": "osm_live",
            "is_verified": True,
        },
        {
            "name": "Klang Valley OSM Charger Beta",
            "operator_name": "OpenStreetMap Live",
            "address": "Jalan Sultan Ismail, Kuala Lumpur",
            "city": "Kuala Lumpur",
            "state": "Kuala Lumpur",
            "latitude": 3.1550,
            "longitude": 101.7080,
            "plug_types": [{"type": "CCS2", "power_kw": 120.0, "count": 2}],
            "max_power_kw": 120.0,
            "is_available": True,
            "is_24_hours": True,
            "charging_cost_myr": 1.40,
            "parking_fee_myr": 0.0,
            "parking_level": "Basement 1",
            "operation_hours": "24 Hours",
            "amenities": ["Shopping"],
            "how_to_access": [{"step_number": 1, "instruction": "Follow EV signs."}],
            "source": "osm_live",
            "is_verified": True,
        },
    ]

    res = await async_client.post("/api/v1/stations/upsert-batch", json=batch_payload)
    assert res.status_code == 200
    saved = res.json()
    assert len(saved) >= 2
    names = [s["name"] for s in saved]
    assert "Klang Valley OSM Charger Alpha" in names
    assert "Klang Valley OSM Charger Beta" in names


@pytest.mark.asyncio
async def test_harvest_viewport_endpoint(async_client: AsyncClient) -> None:
    """Verify live harvest viewport endpoint responds gracefully."""
    req_payload = {
        "min_lat": 3.10,
        "min_lng": 101.65,
        "max_lat": 3.20,
        "max_lng": 101.75,
        "center_lat": 3.15,
        "center_lng": 101.70,
    }
    res = await async_client.post("/api/v1/stations/harvest-viewport", json=req_payload)
    assert res.status_code == 200
    assert isinstance(res.json(), list)
