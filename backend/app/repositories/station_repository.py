"""Repository for ChargingStation data access and spatial queries.

Handles viewport bounding box queries, proximity searches, JSON attributes
filtering, and idempotent seed batch operations.
"""

import math
from typing import Any
from uuid import UUID

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.station import ChargingStation
from app.schemas.station import StationCreate, StationFilterParams


class StationRepository:
    """Encapsulates database operations and spatial query building for charging stations."""

    def __init__(self, session: AsyncSession) -> None:
        """Initialize repository with an active asynchronous database session."""
        self.session = session

    async def list_stations(
        self,
        filters: StationFilterParams,
    ) -> list[ChargingStation]:
        """Query charging stations satisfying spatial bounds, technical specs, and metadata."""
        query = select(ChargingStation)

        # 1. Viewport Bounding Box Filter (min_lat, min_lng, max_lat, max_lng)
        if (
            filters.min_lat is not None
            and filters.max_lat is not None
            and filters.min_lng is not None
            and filters.max_lng is not None
        ):
            query = query.where(
                ChargingStation.latitude >= filters.min_lat,
                ChargingStation.latitude <= filters.max_lat,
                ChargingStation.longitude >= filters.min_lng,
                ChargingStation.longitude <= filters.max_lng,
            )

        # 2. Radius Filter Bounding Envelope (lat, lng, radius_km)
        elif filters.lat is not None and filters.lng is not None:
            # Approximate bounding coordinates based on radius (1 deg lat ~ 111 km)
            delta_lat = filters.radius_km / 111.0
            cos_lat = math.cos(math.radians(filters.lat))
            delta_lng = filters.radius_km / (111.0 * max(abs(cos_lat), 0.01))

            query = query.where(
                ChargingStation.latitude >= (filters.lat - delta_lat),
                ChargingStation.latitude <= (filters.lat + delta_lat),
                ChargingStation.longitude >= (filters.lng - delta_lng),
                ChargingStation.longitude <= (filters.lng + delta_lng),
            )

        # 3. Minimum Power Output Filter (kW)
        if filters.min_kw is not None:
            query = query.where(ChargingStation.max_power_kw >= filters.min_kw)

        # 4. 24-Hour Availability Filter
        if filters.is_24_hours is not None:
            query = query.where(ChargingStation.is_24_hours == filters.is_24_hours)

        # 5. Driver Review Rating Filter
        if filters.min_rating is not None:
            query = query.where(ChargingStation.rating >= filters.min_rating)

        # Execute filtered query
        result = await self.session.execute(query)
        stations = list(result.scalars().all())

        # Post-filter JSON structures (connector_type and amenities) for cross-dialect portability
        if filters.connector_type:
            target_type = filters.connector_type.strip().lower()
            stations = [s for s in stations if self._has_connector_type(s.plug_types, target_type)]

        if filters.amenity:
            target_amenity = filters.amenity.strip().lower()
            stations = [s for s in stations if self._has_amenity(s.amenities, target_amenity)]

        # Apply offset and limit pagination
        offset = filters.offset
        limit = filters.limit
        return stations[offset : offset + limit]

    async def get_by_id(self, station_id: UUID) -> ChargingStation | None:
        """Retrieve a single charging station by its unique UUID."""
        query = select(ChargingStation).where(ChargingStation.id == station_id)
        result = await self.session.execute(query)
        return result.scalar_one_or_none()

    async def find_by_coordinates(
        self,
        latitude: float,
        longitude: float,
        tolerance_km: float = 0.15,
    ) -> ChargingStation | None:
        """Find an existing station near given coordinates within tolerance."""
        delta_lat = tolerance_km / 111.0
        delta_lng = tolerance_km / 111.0
        query = select(ChargingStation).where(
            ChargingStation.latitude >= (latitude - delta_lat),
            ChargingStation.latitude <= (latitude + delta_lat),
            ChargingStation.longitude >= (longitude - delta_lng),
            ChargingStation.longitude <= (longitude + delta_lng),
        )
        result = await self.session.execute(query)
        return result.scalars().first()

    async def create_station(self, station_in: StationCreate) -> ChargingStation:
        """Create and persist a new charging station record."""
        station_dict = station_in.model_dump()
        station_dict["plug_types"] = [
            p.model_dump() if hasattr(p, "model_dump") else p for p in station_in.plug_types
        ]
        station_dict["how_to_access"] = [
            step.model_dump() if hasattr(step, "model_dump") else step
            for step in station_in.how_to_access
        ]
        station_dict["location"] = f"SRID=4326;POINT({station_in.longitude} {station_in.latitude})"

        station = ChargingStation(**station_dict)
        self.session.add(station)
        await self.session.commit()
        await self.session.refresh(station)
        return station

    async def upsert_seed_stations(
        self,
        stations_data: list[StationCreate],
    ) -> tuple[int, int]:
        """Insert seed stations idempotently by unique composite coordinates and name."""
        query_existing = select(
            ChargingStation.name,
            ChargingStation.latitude,
            ChargingStation.longitude,
        )
        existing_result = await self.session.execute(query_existing)
        existing_keys = {
            (name, round(lat, 4), round(lng, 4)) for name, lat, lng in existing_result.all()
        }

        inserted_count = 0
        for item in stations_data:
            key = (item.name, round(item.latitude, 4), round(item.longitude, 4))
            if key in existing_keys:
                continue

            station_dict = item.model_dump()
            # Convert Pydantic submodels into raw dicts for JSON columns
            station_dict["plug_types"] = [
                p.model_dump() if hasattr(p, "model_dump") else p for p in item.plug_types
            ]
            station_dict["how_to_access"] = [
                step.model_dump() if hasattr(step, "model_dump") else step
                for step in item.how_to_access
            ]
            # Spatial WKT representation
            station_dict["location"] = f"SRID=4326;POINT({item.longitude} {item.latitude})"

            new_station = ChargingStation(**station_dict)
            self.session.add(new_station)
            existing_keys.add(key)
            inserted_count += 1

        if inserted_count > 0:
            await self.session.commit()

        # Retrieve total count of stations
        count_query = select(func.count(ChargingStation.id))
        total_result = await self.session.execute(count_query)
        total_count = int(total_result.scalar_one() or 0)

        return inserted_count, total_count

    @staticmethod
    def _has_connector_type(
        plug_types: list[dict[str, Any]] | None,
        target_type: str,
    ) -> bool:
        """Check whether plug_types JSON array contains the target connector type."""
        if not plug_types:
            return False
        return any(str(plug.get("type", "")).strip().lower() == target_type for plug in plug_types)

    @staticmethod
    def _has_amenity(
        amenities: list[str] | None,
        target_amenity: str,
    ) -> bool:
        """Check whether amenities list contains the specified amenity tag."""
        if not amenities:
            return False
        return any(target_amenity in str(amenity).strip().lower() for amenity in amenities)
