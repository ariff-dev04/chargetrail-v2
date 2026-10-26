"""Pydantic schemas for place geocoding, OSRM polylines, and battery route planning."""

from uuid import UUID

from pydantic import BaseModel, Field

from app.schemas.station import StationRead


class LatLngPoint(BaseModel):
    """Geographic coordinate representation."""

    latitude: float = Field(ge=-90.0, le=90.0, examples=[3.1578])
    longitude: float = Field(ge=-180.0, le=180.0, examples=[101.7118])


class PlaceSuggestion(BaseModel):
    """Geocoded landmark, city, or expressway interchange suggestion."""

    name: str = Field(description="Display place or landmark title", examples=["Suria KLCC"])
    city: str = Field(description="City or municipality", examples=["Kuala Lumpur"])
    state: str = Field(description="Malaysian state or territory", examples=["Kuala Lumpur"])
    latitude: float = Field(description="Latitude coordinate", examples=[3.1578])
    longitude: float = Field(description="Longitude coordinate", examples=[101.7118])
    category: str = Field(
        default="city", description="Place classification (city, mall, highway_rsa)"
    )


class RoutePlanRequest(BaseModel):
    """Payload schema requesting battery-aware route simulation and charging stop optimization."""

    origin_name: str = Field(default="Kuala Lumpur (KLCC)", examples=["Kuala Lumpur (KLCC)"])
    origin_lat: float = Field(ge=-90.0, le=90.0, examples=[3.1578])
    origin_lng: float = Field(ge=-180.0, le=180.0, examples=[101.7118])

    destination_name: str = Field(
        default="Penang (Gurney Plaza)", examples=["Penang (Gurney Plaza)"]
    )
    destination_lat: float = Field(ge=-90.0, le=90.0, examples=[5.4372])
    destination_lng: float = Field(ge=-180.0, le=180.0, examples=[100.3096])

    vehicle_id: UUID | None = Field(
        default=None, description="Optional garage vehicle UUID override"
    )
    starting_soc_percent: int = Field(default=80, ge=10, le=100, examples=[80])

    # EV Battery Specifications (Used if vehicle_id not provided)
    battery_capacity_kwh: float = Field(default=60.48, gt=5.0, le=250.0, examples=[60.48])
    efficiency_wh_per_km: float = Field(default=144.0, gt=50.0, le=450.0, examples=[144.0])
    max_dc_charge_kw: float = Field(default=88.0, gt=7.0, le=500.0, examples=[88.0])
    connector_type: str = Field(default="CCS2", examples=["CCS2"])
    reserve_soc_percent: int = Field(default=15, ge=5, le=40, examples=[15])

    # Corridor Search Envelope
    corridor_radius_km: float = Field(default=20.0, gt=1.0, le=100.0, examples=[20.0])


class ChargingStopRecommendation(BaseModel):
    """Recommended charging stop along the travel corridor."""

    station: StationRead
    distance_from_origin_km: float = Field(description="Distance along route from departure")
    detour_distance_km: float = Field(description="Orthogonal distance from highway corridor")
    arrival_soc_percent: int = Field(description="Projected battery percentage upon arrival")
    departure_soc_percent: int = Field(description="Target battery percentage upon departing bay")
    energy_added_kwh: float = Field(description="Energy replenished into vehicle battery in kWh")
    estimated_charge_minutes: int = Field(
        description="Estimated charging session duration in minutes"
    )
    estimated_cost_myr: float = Field(
        description="Estimated charging tariff cost in Malaysian Ringgit"
    )


class RoutePlanResponse(BaseModel):
    """Complete simulated journey plan with battery telemetry and charging stop recommendations."""

    origin_name: str
    destination_name: str
    total_distance_km: float = Field(description="Total road distance in kilometers")
    estimated_drive_minutes: int = Field(description="Net driving time excluding charging stops")
    total_charging_minutes: int = Field(
        description="Cumulative charging time across recommended stops"
    )
    total_trip_minutes: int = Field(description="Total travel time including driving and charging")

    starting_soc_percent: int = Field(description="Battery State of Charge at journey start")
    projected_destination_soc_without_charging: int = Field(
        description="Hypothetical arrival SoC if no charging stops were made"
    )
    final_arrival_soc_percent: int = Field(description="Projected arrival SoC at final destination")
    total_energy_kwh: float = Field(
        description="Estimated energy expenditure for the entire journey"
    )

    range_anxiety_status: str = Field(
        description="Risk classification: safe, warning, or critical_charging_required",
        examples=["safe"],
    )
    status_summary: str = Field(description="Human-readable safety buffer explanation")
    vehicle_summary: str = Field(
        description="Summary of vehicle specifications used for simulation"
    )

    polyline_points: list[LatLngPoint] = Field(description="Sequential route polyline coordinates")
    recommended_stops: list[ChargingStopRecommendation] = Field(
        default_factory=list,
        description="Optimized charging stops to avoid running out of charge",
    )
    corridor_stations: list[StationRead] = Field(
        default_factory=list,
        description="All compatible charging stations within the corridor buffer",
    )
