from __future__ import annotations

import os
from pathlib import Path
import sys

import pytest_asyncio
from httpx import ASGITransport, AsyncClient
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine
from sqlalchemy.pool import NullPool

sys.path.append(str(Path(__file__).resolve().parents[1]))

import app.models  # noqa: F401
from app.database import Base
from app.dependencies import get_db
from app.main import app
from app.models.user import User
from app.utils.security import create_access_token, hash_pin

TEST_DATABASE_URL = os.getenv(
    "TEST_DATABASE_URL",
    "postgresql+asyncpg://admin:admin@localhost:5432/dental_test",
)

test_engine = create_async_engine(TEST_DATABASE_URL, echo=False, poolclass=NullPool)
TestSessionLocal = async_sessionmaker(test_engine, expire_on_commit=False)


@pytest_asyncio.fixture(autouse=True)
async def setup_db():
    async with test_engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)
        await conn.run_sync(Base.metadata.create_all)
    yield
    async with test_engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)


@pytest_asyncio.fixture
async def db():
    async with TestSessionLocal() as session:
        yield session


@pytest_asyncio.fixture
async def client(db):
    async def override_get_db():
        yield db

    app.dependency_overrides[get_db] = override_get_db
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        yield ac
    app.dependency_overrides.clear()


@pytest_asyncio.fixture
async def admin_token(db):
    user = User(name="Admin", role="admin", pin_hash=hash_pin("1234"), is_active=True)
    db.add(user)
    await db.commit()
    await db.refresh(user)
    return create_access_token({"sub": str(user.id), "role": "admin", "name": "Admin"})


@pytest_asyncio.fixture
async def staff_token(db):
    user = User(name="Staff", role="staff", pin_hash=hash_pin("5678"), is_active=True)
    db.add(user)
    await db.commit()
    await db.refresh(user)
    return create_access_token({"sub": str(user.id), "role": "staff", "name": "Staff"})
