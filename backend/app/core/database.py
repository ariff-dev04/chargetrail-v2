"""Database connection management and session factory using Async SQLAlchemy 2.0.

Provides async connection pooling, base model declarations, and session dependencies.
"""

import logging
from collections.abc import AsyncGenerator

from sqlalchemy import text
from sqlalchemy.ext.asyncio import (
    AsyncAttrs,
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)
from sqlalchemy.orm import DeclarativeBase

from app.core.config import get_settings

logger = logging.getLogger(__name__)

settings = get_settings()

engine_kwargs: dict[str, object] = {
    "echo": settings.DEBUG,
    "future": True,
}
if "sqlite" in settings.async_database_url:
    engine_kwargs["connect_args"] = {"check_same_thread": False}
else:
    engine_kwargs["pool_pre_ping"] = True

engine = create_async_engine(
    settings.async_database_url,
    **engine_kwargs,
)

async_session_maker = async_sessionmaker(
    bind=engine,
    class_=AsyncSession,
    expire_on_commit=False,
    autoflush=False,
)


class Base(AsyncAttrs, DeclarativeBase):
    """Declarative base class for all SQLAlchemy ORM models."""

    pass


async def get_db_session() -> AsyncGenerator[AsyncSession, None]:
    """Provide an asynchronous database session context for request handlers."""
    async with async_session_maker() as session:
        try:
            yield session
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()


async def check_database_health() -> bool:
    """Execute a simple query to verify active connectivity with the database."""
    try:
        async with async_session_maker() as session:
            result = await session.execute(text("SELECT 1"))
            return result.scalar() == 1
    except Exception as exc:
        logger.warning("Database connectivity check failed: %s", exc)
        return False
