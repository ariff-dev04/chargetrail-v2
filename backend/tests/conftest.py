"""Pytest fixtures for backend test suite."""

from collections.abc import AsyncIterator
from typing import Any

import pytest
from geoalchemy2.admin.dialects import sqlite as geo_sqlite
from httpx import ASGITransport, AsyncClient
from sqlalchemy.ext.asyncio import (
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)

from app.core.database import Base, get_db_session
from app.main import app


# Ensure SQLite DDL hooks are disabled during in-memory testing
def _noop(*_args: Any, **_kwargs: Any) -> None:
    pass


geo_sqlite.after_create = _noop
geo_sqlite.before_create = _noop
geo_sqlite.before_drop = _noop
geo_sqlite.after_drop = _noop

# Shared test in-memory SQLite database URL for fast, isolated tests
TEST_DATABASE_URL = "sqlite+aiosqlite:///:memory:"


@pytest.fixture
async def db_session() -> AsyncIterator[AsyncSession]:
    """Create a pristine in-memory test database and yield an isolated session."""
    test_engine = create_async_engine(
        TEST_DATABASE_URL,
        echo=False,
        future=True,
    )
    async with test_engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    test_session_maker = async_sessionmaker(
        bind=test_engine,
        class_=AsyncSession,
        expire_on_commit=False,
        autoflush=False,
    )

    async with test_session_maker() as session:
        yield session

    async with test_engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)

    await test_engine.dispose()


@pytest.fixture
async def async_client(db_session: AsyncSession) -> AsyncIterator[AsyncClient]:
    """Provide an asynchronous HTTP client with overridden database session dependency."""

    async def override_get_db_session() -> AsyncIterator[AsyncSession]:
        yield db_session

    app.dependency_overrides[get_db_session] = override_get_db_session

    async with AsyncClient(
        transport=ASGITransport(app=app),
        base_url="http://testserver",
    ) as client:
        yield client

    app.dependency_overrides.clear()
