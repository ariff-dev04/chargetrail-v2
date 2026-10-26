"""Curated factory specification presets for popular Malaysian electric vehicles."""

from app.schemas.vehicle import VehiclePresetRead

MALAYSIAN_EV_PRESETS: list[VehiclePresetRead] = [
    VehiclePresetRead(
        preset_id="proton-emas-7",
        brand="Proton",
        model_name="e.MAS 7 Prime",
        battery_capacity_kwh=60.22,
        usable_range_km=410.0,
        efficiency_wh_per_km=147.0,
        max_dc_charge_kw=100.0,
        connector_type="CCS2",
    ),
    VehiclePresetRead(
        preset_id="byd-atto-3-ext",
        brand="BYD",
        model_name="Atto 3 Extended Range",
        battery_capacity_kwh=60.48,
        usable_range_km=420.0,
        efficiency_wh_per_km=144.0,
        max_dc_charge_kw=88.0,
        connector_type="CCS2",
    ),
    VehiclePresetRead(
        preset_id="tesla-model-3-lr",
        brand="Tesla",
        model_name="Model 3 Long Range AWD",
        battery_capacity_kwh=75.0,
        usable_range_km=629.0,
        efficiency_wh_per_km=125.0,
        max_dc_charge_kw=250.0,
        connector_type="CCS2",
    ),
    VehiclePresetRead(
        preset_id="byd-dolphin",
        brand="BYD",
        model_name="Dolphin Dynamic / Premium",
        battery_capacity_kwh=60.48,
        usable_range_km=427.0,
        efficiency_wh_per_km=142.0,
        max_dc_charge_kw=88.0,
        connector_type="CCS2",
    ),
    VehiclePresetRead(
        preset_id="hyundai-ioniq-5-max",
        brand="Hyundai",
        model_name="IONIQ 5 Max AWD",
        battery_capacity_kwh=72.6,
        usable_range_km=430.0,
        efficiency_wh_per_km=169.0,
        max_dc_charge_kw=233.0,
        connector_type="CCS2",
    ),
    VehiclePresetRead(
        preset_id="nissan-leaf-ep",
        brand="Nissan",
        model_name="Leaf e+ (CHAdeMO Legacy)",
        battery_capacity_kwh=59.0,
        usable_range_km=385.0,
        efficiency_wh_per_km=153.0,
        max_dc_charge_kw=50.0,
        connector_type="CHAdeMO",
    ),
]


def get_malaysian_presets() -> list[VehiclePresetRead]:
    """Return immutable list of validated Malaysian EV models."""
    return MALAYSIAN_EV_PRESETS
