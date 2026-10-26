"""Pydantic schemas for EV Vehicle specifications, presets, and garage management."""

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


class VehiclePresetRead(BaseModel):
    """Factory specification preset for an electric vehicle model."""

    preset_id: str = Field(description="Unique catalog slug", examples=["proton-emas-7"])
    brand: str = Field(description="Vehicle manufacturer", examples=["Proton"])
    model_name: str = Field(description="Commercial model trim", examples=["e.MAS 7 Prime"])
    battery_capacity_kwh: float = Field(
        description="Gross battery capacity in kWh", examples=[60.22]
    )
    usable_range_km: float = Field(description="Advertised WLTP range in km", examples=[410.0])
    efficiency_wh_per_km: float = Field(
        description="Average energy consumption in Wh/km", examples=[147.0]
    )
    max_dc_charge_kw: float = Field(
        description="Peak DC Fast Charging rate in kW", examples=[100.0]
    )
    connector_type: str = Field(
        default="CCS2", description="Primary charging connector standard", examples=["CCS2"]
    )


class VehicleCreate(BaseModel):
    """Payload schema for adding an EV to the user's garage."""

    brand: str = Field(min_length=1, max_length=80, examples=["Proton"])
    model_name: str = Field(min_length=1, max_length=120, examples=["e.MAS 7 Prime"])
    nickname: str | None = Field(default=None, max_length=100, examples=["My Daily EV"])
    battery_capacity_kwh: float = Field(gt=5.0, le=250.0, examples=[60.22])
    usable_range_km: float = Field(gt=30.0, le=1200.0, examples=[410.0])
    efficiency_wh_per_km: float = Field(gt=50.0, le=450.0, examples=[147.0])
    max_dc_charge_kw: float = Field(gt=7.0, le=500.0, examples=[100.0])
    connector_type: str = Field(default="CCS2", max_length=40, examples=["CCS2"])
    reserve_soc_percent: int = Field(default=15, ge=5, le=40, examples=[15])
    is_primary: bool = Field(default=True, examples=[True])


class VehicleUpdate(BaseModel):
    """Payload schema for modifying an existing vehicle in the garage."""

    nickname: str | None = Field(default=None, max_length=100)
    battery_capacity_kwh: float | None = Field(default=None, gt=5.0, le=250.0)
    usable_range_km: float | None = Field(default=None, gt=30.0, le=1200.0)
    efficiency_wh_per_km: float | None = Field(default=None, gt=50.0, le=450.0)
    max_dc_charge_kw: float | None = Field(default=None, gt=7.0, le=500.0)
    connector_type: str | None = Field(default=None, max_length=40)
    reserve_soc_percent: int | None = Field(default=None, ge=5, le=40)
    is_primary: bool | None = None


class VehicleRead(BaseModel):
    """Response schema representing an EV profile with computed safety buffer metrics."""

    id: UUID = Field(description="Unique vehicle profile UUID")
    user_id: UUID | None = Field(default=None, description="Owning user UUID")
    brand: str = Field(description="Vehicle manufacturer")
    model_name: str = Field(description="Commercial model trim")
    nickname: str | None = Field(default=None, description="Custom owner nickname")
    battery_capacity_kwh: float = Field(description="Gross battery capacity in kWh")
    usable_range_km: float = Field(description="Advertised WLTP range in km")
    efficiency_wh_per_km: float = Field(description="Average energy consumption in Wh/km")
    max_dc_charge_kw: float = Field(description="Peak DC Fast Charging rate in kW")
    connector_type: str = Field(default="CCS2", description="Primary charging port standard")
    reserve_soc_percent: int = Field(default=15, description="Safety reserve buffer percentage")
    is_primary: bool = Field(default=False, description="Active selected vehicle flag")
    effective_safe_range_km: float = Field(
        description="Usable range after subtracting safety reserve"
    )
    created_at: datetime | None = Field(default=None, description="Creation timestamp in UTC")
    updated_at: datetime | None = Field(default=None, description="Last update timestamp in UTC")

    model_config = ConfigDict(from_attributes=True)
