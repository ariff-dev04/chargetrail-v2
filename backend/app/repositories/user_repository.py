"""Repository for User accounts, authentication lookups, and station bookmarks."""

from uuid import UUID

from sqlalchemy import delete, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.station import ChargingStation
from app.models.user import SavedStation, User


class UserRepository:
    """Encapsulates database operations for users and saved station bookmarks."""

    def __init__(self, session: AsyncSession) -> None:
        """Initialize repository with an active asynchronous database session."""
        self.session = session

    async def get_by_email(self, email: str) -> User | None:
        """Retrieve user record by email address (case-insensitive)."""
        normalized_email = email.lower().strip()
        query = select(User).where(func.lower(User.email) == normalized_email)
        result = await self.session.execute(query)
        return result.scalar_one_or_none()

    async def get_by_id(self, user_id: UUID) -> User | None:
        """Retrieve user record by unique UUID."""
        query = select(User).where(User.id == user_id)
        result = await self.session.execute(query)
        return result.scalar_one_or_none()

    async def create_user(
        self,
        email: str,
        hashed_password: str,
        full_name: str,
        phone_number: str | None = None,
        preferred_connector: str = "CCS2",
    ) -> User:
        """Create and persist a new user account."""
        user = User(
            email=email.lower().strip(),
            hashed_password=hashed_password,
            full_name=full_name.strip(),
            phone_number=phone_number.strip() if phone_number else None,
            preferred_connector=preferred_connector.strip(),
        )
        self.session.add(user)
        await self.session.commit()
        await self.session.refresh(user)
        return user

    async def update_user(
        self,
        user: User,
        full_name: str | None = None,
        phone_number: str | None = None,
        preferred_connector: str | None = None,
    ) -> User:
        """Update mutable fields on an existing user record."""
        if full_name is not None:
            user.full_name = full_name.strip()
        if phone_number is not None:
            user.phone_number = phone_number.strip() if phone_number.strip() else None
        if preferred_connector is not None:
            user.preferred_connector = preferred_connector.strip()

        await self.session.commit()
        await self.session.refresh(user)
        return user

    async def get_saved_station_ids(self, user_id: UUID) -> list[UUID]:
        """Fetch ordered list of station UUIDs bookmarked by the user."""
        query = (
            select(SavedStation.station_id)
            .where(SavedStation.user_id == user_id)
            .order_by(SavedStation.created_at.desc())
        )
        result = await self.session.execute(query)
        return list(result.scalars().all())

    async def get_saved_stations(self, user_id: UUID) -> list[ChargingStation]:
        """Fetch full ChargingStation entities bookmarked by the user."""
        query = (
            select(ChargingStation)
            .join(SavedStation, SavedStation.station_id == ChargingStation.id)
            .where(SavedStation.user_id == user_id)
            .order_by(SavedStation.created_at.desc())
        )
        result = await self.session.execute(query)
        return list(result.scalars().all())

    async def toggle_saved_station(self, user_id: UUID, station_id: UUID) -> bool:
        """Toggle bookmark state for a station; returns True if now saved, False if removed."""
        query = select(SavedStation).where(
            SavedStation.user_id == user_id,
            SavedStation.station_id == station_id,
        )
        result = await self.session.execute(query)
        existing = result.scalar_one_or_none()

        if existing is not None:
            stmt = delete(SavedStation).where(
                SavedStation.user_id == user_id,
                SavedStation.station_id == station_id,
            )
            await self.session.execute(stmt)
            await self.session.commit()
            return False

        bookmark = SavedStation(user_id=user_id, station_id=station_id)
        self.session.add(bookmark)
        await self.session.commit()
        return True
