# Dental Clinic App — Backend Development Guide

> **Stack:** Python 3.12 · FastAPI · SQLAlchemy 2.0 (async) · PostgreSQL 15 · Alembic · Pydantic V2 · AWS S3 · WATI · APScheduler · Amazon Lightsail
>
> **Access model:** Doctor & Staff only. No patient-facing endpoints.

---

## Table of Contents

1. [Project Structure](#1-project-structure)
2. [Environment & Dependencies](#2-environment--dependencies)
3. [Configuration Management](#3-configuration-management)
4. [Database Setup](#4-database-setup)
5. [Models (SQLAlchemy)](#5-models-sqlalchemy)
6. [Schemas (Pydantic V2)](#6-schemas-pydantic-v2)
7. [Authentication & Authorization](#7-authentication--authorization)
8. [Rate Limiting](#8-rate-limiting)
9. [API Modules](#9-api-modules)
   - [9.1 Auth](#91-auth)
   - [9.2 Patients](#92-patients)
   - [9.3 Appointments](#93-appointments)
   - [9.4 Visits, Notes & Photos](#94-visits-notes--photos)
   - [9.5 PDF Generation (Prescriptions)](#95-pdf-generation-prescriptions)
   - [9.6 WhatsApp / WATI](#96-whatsapp--wati)
   - [9.7 Dashboard](#97-dashboard)
   - [9.8 Staff Management](#98-staff-management)
   - [9.9 Master Lists](#99-master-lists)
   - [9.10 Inventory (Add-on)](#910-inventory-add-on)
10. [File Storage (S3)](#10-file-storage-s3)
11. [Error Handling](#11-error-handling)
12. [Logging](#12-logging)
13. [Scheduled Tasks](#13-scheduled-tasks)
14. [Security Checklist](#14-security-checklist)
15. [Testing Strategy](#15-testing-strategy)
16. [Deployment](#16-deployment)

---

## 1. Project Structure

```
dental-backend/
├── app/
│   ├── __init__.py
│   ├── main.py                  # FastAPI app factory, lifespan, middleware registration
│   ├── config.py                # Pydantic settings (reads from .env)
│   ├── database.py              # Async SQLAlchemy engine + session factory
│   ├── dependencies.py          # Shared FastAPI Depends() — auth, db session, pagination
│   │
│   ├── models/                  # SQLAlchemy ORM models
│   │   ├── __init__.py
│   │   ├── user.py
│   │   ├── patient.py
│   │   ├── appointment.py
│   │   ├── visit.py
│   │   ├── visit_photo.py
│   │   ├── treatment_master.py
│   │   ├── medication_master.py
│   │   ├── visit_treatment.py
│   │   ├── visit_medication.py
│   │   ├── prescription.py
│   │   ├── activity_log.py
│   │   ├── whatsapp_message.py
│   │   └── inventory.py         # Add-on
│   │
│   ├── schemas/                 # Pydantic V2 request/response models
│   │   ├── __init__.py
│   │   ├── auth.py
│   │   ├── patient.py
│   │   ├── appointment.py
│   │   ├── visit.py
│   │   ├── visit_photo.py
│   │   ├── prescription.py
│   │   ├── dashboard.py
│   │   ├── staff.py
│   │   ├── master.py
│   │   └── common.py            # Shared schemas (pagination, errors)
│   │
│   ├── routers/                 # FastAPI APIRouter — one file per domain
│   │   ├── __init__.py
│   │   ├── auth.py
│   │   ├── patients.py
│   │   ├── appointments.py
│   │   ├── visits.py
│   │   ├── prescriptions.py
│   │   ├── dashboard.py
│   │   ├── staff.py
│   │   ├── masters.py
│   │   └── inventory.py
│   │
│   ├── services/                # Business logic — no DB/HTTP in routers
│   │   ├── __init__.py
│   │   ├── auth_service.py
│   │   ├── patient_service.py
│   │   ├── appointment_service.py
│   │   ├── visit_service.py
│   │   ├── photo_service.py
│   │   ├── pdf_service.py
│   │   ├── s3_service.py
│   │   ├── whatsapp_service.py
│   │   ├── dashboard_service.py
│   │   └── inventory_service.py
│   │
│   ├── middleware/
│   │   ├── __init__.py
│   │   ├── activity_logger.py   # Async activity log middleware
│   │   └── request_id.py        # Injects X-Request-ID into every request
│   │
│   ├── templates/               # Jinja2 HTML templates for PDF rendering
│   │   └── prescription.html
│   │
│   └── utils/
│       ├── __init__.py
│       ├── security.py          # bcrypt helpers, JWT encode/decode
│       ├── uid.py               # Patient UID generator (PAT-000001)
│       └── pagination.py
│
├── alembic/
│   ├── env.py
│   ├── script.py.mako
│   └── versions/
│
├── tests/
│   ├── conftest.py              # Fixtures: test DB, test client, mock S3
│   ├── unit/
│   │   ├── test_auth.py
│   │   ├── test_patient_service.py
│   │   └── test_visit_service.py
│   └── integration/
│       ├── test_auth_routes.py
│       ├── test_patient_routes.py
│       ├── test_visit_routes.py
│       └── test_appointment_routes.py
│
├── scripts/
│   └── seed.py                  # Dev seed data (never run in production)
│
├── .env.example
├── .env                         # Never committed — add to .gitignore
├── .gitignore
├── alembic.ini
├── pyproject.toml
├── requirements.txt
└── requirements-dev.txt
```

> **Rule:** Routers only handle HTTP concerns (parse request, call service, return response). All business logic lives in `services/`. All DB queries live in `services/` using the injected session. This separation makes unit testing straightforward.

---

## 2. Environment & Dependencies

### Python Version

Use **Python 3.12**. Pin it with `.python-version` (for pyenv) or in `pyproject.toml`.

```toml
# pyproject.toml
[project]
name = "dental-backend"
requires-python = ">=3.12"
```

### Core Dependencies (`requirements.txt`)

```txt
fastapi==0.115.0
uvicorn[standard]==0.30.6
sqlalchemy[asyncio]==2.0.36
asyncpg==0.30.0           # Async PostgreSQL driver
alembic==1.13.3
pydantic[email]==2.9.2
pydantic-settings==2.5.2
python-jose[cryptography]==3.3.0   # JWT
passlib[bcrypt]==1.7.4             # PIN hashing
slowapi==0.1.9                     # Rate limiting
structlog==24.4.0                  # Structured logging
boto3==1.35.0                      # AWS S3
weasyprint==62.3                   # HTML → PDF
jinja2==3.1.4                      # PDF templates
httpx==0.27.2                      # Async HTTP client (WATI calls)
apscheduler==3.10.4                # Cron scheduler
python-multipart==0.0.12           # File upload support
Pillow==10.4.0                     # Image compression
```

### Dev Dependencies (`requirements-dev.txt`)

```txt
pytest==8.3.3
pytest-asyncio==0.24.0
httpx==0.27.2           # TestClient
pytest-cov==5.0.0
factory-boy==3.3.1      # Test factories
moto[s3]==5.0.14        # Mock AWS S3
ruff==0.6.9             # Linting + formatting
mypy==1.11.2
```

---

## 3. Configuration Management

All configuration is read from environment variables via **Pydantic Settings**. No hardcoded secrets — ever.

```python
# app/config.py
from pydantic_settings import BaseSettings, SettingsConfigDict
from functools import lru_cache


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
    )

    # App
    app_name: str = "Dental Clinic API"
    environment: str = "production"        # "development" | "production"
    debug: bool = False
    api_prefix: str = "/api/v1"

    # Database
    database_url: str                      # postgresql+asyncpg://user:pass@host/db
    db_pool_size: int = 10
    db_max_overflow: int = 20

    # JWT
    jwt_secret_key: str                    # Long random string — never expose
    jwt_algorithm: str = "HS256"
    access_token_expire_minutes: int = 60
    refresh_token_expire_days: int = 7

    # AWS S3
    aws_access_key_id: str
    aws_secret_access_key: str
    aws_region: str = "ap-south-1"
    s3_bucket_name: str
    s3_presigned_url_expiry: int = 900     # 15 minutes

    # WATI (WhatsApp)
    wati_api_url: str
    wati_api_token: str

    # Feature flags
    inventory_addon_enabled: bool = False


@lru_cache
def get_settings() -> Settings:
    return Settings()
```

### `.env.example`

```dotenv
DATABASE_URL=postgresql+asyncpg://dental_user:strongpassword@localhost:5432/dental_db
JWT_SECRET_KEY=replace-with-64-char-random-string
AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE
AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
AWS_REGION=ap-south-1
S3_BUCKET_NAME=dental-clinic-files
WATI_API_URL=https://live-mt-server.wati.io/YOUR_ACCOUNT_ID
WATI_API_TOKEN=your-wati-token
ENVIRONMENT=production
```

> **Never commit `.env`** — add it to `.gitignore`. On the server, set env vars via `systemd` `EnvironmentFile` or AWS Secrets Manager.

---

## 4. Database Setup

### Async Engine & Session

```python
# app/database.py
from sqlalchemy.ext.asyncio import (
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)
from sqlalchemy.orm import DeclarativeBase
from app.config import get_settings

settings = get_settings()

engine = create_async_engine(
    settings.database_url,
    pool_size=settings.db_pool_size,
    max_overflow=settings.db_max_overflow,
    pool_pre_ping=True,    # Reconnect on stale connections
    echo=settings.debug,   # Log SQL only in development
)

AsyncSessionLocal = async_sessionmaker(
    engine,
    class_=AsyncSession,
    expire_on_commit=False,
    autoflush=False,
)


class Base(DeclarativeBase):
    pass
```

### Session Dependency

```python
# app/dependencies.py
from collections.abc import AsyncGenerator
from sqlalchemy.ext.asyncio import AsyncSession
from app.database import AsyncSessionLocal


async def get_db() -> AsyncGenerator[AsyncSession, None]:
    async with AsyncSessionLocal() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
```

### Alembic Setup

```ini
# alembic.ini (key setting)
script_location = alembic
sqlalchemy.url = # Leave blank — overridden in env.py
```

```python
# alembic/env.py
import asyncio
from alembic import context
from app.database import engine
from app.models import Base  # Imports all models for autogenerate

def run_migrations_online():
    async def run():
        async with engine.connect() as connection:
            await connection.run_sync(
                context.configure,
                target_metadata=Base.metadata,
                compare_type=True,
            )
            async with context.begin_transaction():
                await context.run_migrations()

    asyncio.run(run())
```

**Common Alembic commands:**

```bash
# Generate migration after model change
alembic revision --autogenerate -m "add_visit_photos_table"

# Apply all pending migrations
alembic upgrade head

# Roll back one migration
alembic downgrade -1

# Check current migration state
alembic current
```

---

## 5. Models (SQLAlchemy)

All models inherit from `Base`. Use `UUID` PKs, `mapped_column` with explicit types, and `relationship()` for associations.

### Base Mixin

```python
# app/models/mixins.py
import uuid
from datetime import datetime, timezone
from sqlalchemy import DateTime
from sqlalchemy.orm import mapped_column, MappedColumn
from sqlalchemy.dialects.postgresql import UUID


class TimestampMixin:
    created_at: MappedColumn[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
    )
    updated_at: MappedColumn[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
        nullable=False,
    )
```

### Users

```python
# app/models/user.py
import uuid
from sqlalchemy import String, Boolean, DateTime
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column
from app.database import Base
from app.models.mixins import TimestampMixin


class User(Base, TimestampMixin):
    __tablename__ = "users"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    name: Mapped[str] = mapped_column(String(100), nullable=False)
    role: Mapped[str] = mapped_column(String(20), nullable=False)  # "admin" | "staff"
    pin_hash: Mapped[str] = mapped_column(String(255), nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    last_login_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
```

### Patients

```python
# app/models/patient.py
import uuid
from sqlalchemy import String, Integer, Boolean, Text, DateTime
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.database import Base
from app.models.mixins import TimestampMixin


class Patient(Base, TimestampMixin):
    __tablename__ = "patients"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    patient_uid: Mapped[str] = mapped_column(String(20), unique=True, nullable=False, index=True)
    name: Mapped[str] = mapped_column(String(150), nullable=False)
    age: Mapped[int | None] = mapped_column(Integer, nullable=True)
    gender: Mapped[str | None] = mapped_column(String(10), nullable=True)
    mobile: Mapped[str] = mapped_column(String(15), nullable=False)
    whatsapp_enabled: Mapped[bool] = mapped_column(Boolean, default=True)
    address: Mapped[str | None] = mapped_column(Text, nullable=True)
    medical_history: Mapped[str | None] = mapped_column(Text, nullable=True)
    allergies: Mapped[str | None] = mapped_column(Text, nullable=True)
    is_deleted: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False, index=True)
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    deletion_reason: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_by: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False)

    visits: Mapped[list["Visit"]] = relationship("Visit", back_populates="patient")
    appointments: Mapped[list["Appointment"]] = relationship("Appointment", back_populates="patient")
```

### Visits

```python
# app/models/visit.py
import uuid
from sqlalchemy import String, Text, Date, ForeignKey
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.database import Base
from app.models.mixins import TimestampMixin


class Visit(Base, TimestampMixin):
    __tablename__ = "visits"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    patient_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("patients.id"), nullable=False, index=True
    )
    appointment_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("appointments.id"), nullable=True
    )
    visit_date: Mapped[date] = mapped_column(Date, nullable=False, index=True)
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    diagnosis: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_by: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False)

    patient: Mapped["Patient"] = relationship("Patient", back_populates="visits")
    treatments: Mapped[list["VisitTreatment"]] = relationship("VisitTreatment", back_populates="visit")
    medications: Mapped[list["VisitMedication"]] = relationship("VisitMedication", back_populates="visit")
    photos: Mapped[list["VisitPhoto"]] = relationship("VisitPhoto", back_populates="visit")
    prescription: Mapped["Prescription | None"] = relationship("Prescription", back_populates="visit")
```

### Visit Photos

```python
# app/models/visit_photo.py
import uuid
from sqlalchemy import String, Text, ForeignKey, DateTime
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.database import Base


class VisitPhoto(Base):
    __tablename__ = "visit_photos"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    visit_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("visits.id"), nullable=False, index=True
    )
    s3_key: Mapped[str] = mapped_column(String(500), nullable=False)
    photo_url: Mapped[str] = mapped_column(String(1000), nullable=False)
    caption: Mapped[str | None] = mapped_column(Text, nullable=True)
    uploaded_by: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False)
    uploaded_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
        index=True,
    )

    visit: Mapped["Visit"] = relationship("Visit", back_populates="photos")
```

---

## 6. Schemas (Pydantic V2)

Schemas are separated into `Request` (input) and `Response` (output) classes. Responses never expose sensitive fields like `pin_hash`.

```python
# app/schemas/patient.py
from __future__ import annotations
import uuid
from datetime import datetime
from pydantic import BaseModel, Field, field_validator
import re


class PatientCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=150)
    mobile: str = Field(..., pattern=r"^\+?[0-9]{10,15}$")
    age: int | None = Field(None, ge=1, le=120)
    gender: str | None = Field(None, pattern="^(Male|Female|Other)$")
    address: str | None = None
    medical_history: str | None = None
    allergies: str | None = None
    whatsapp_enabled: bool = True


class PatientUpdate(BaseModel):
    name: str | None = Field(None, min_length=1, max_length=150)
    mobile: str | None = Field(None, pattern=r"^\+?[0-9]{10,15}$")
    age: int | None = Field(None, ge=1, le=120)
    gender: str | None = None
    address: str | None = None
    medical_history: str | None = None
    allergies: str | None = None
    whatsapp_enabled: bool | None = None


class PatientResponse(BaseModel):
    model_config = {"from_attributes": True}

    id: uuid.UUID
    patient_uid: str
    name: str
    mobile: str
    age: int | None
    gender: str | None
    address: str | None
    medical_history: str | None
    allergies: str | None
    whatsapp_enabled: bool
    is_deleted: bool
    created_at: datetime
    updated_at: datetime


class PatientListResponse(BaseModel):
    items: list[PatientResponse]
    total: int
    page: int
    page_size: int
```

```python
# app/schemas/visit.py
import uuid
from datetime import date, datetime
from pydantic import BaseModel, Field


class VisitPhotoResponse(BaseModel):
    model_config = {"from_attributes": True}

    id: uuid.UUID
    photo_url: str          # Presigned URL — regenerated on fetch
    caption: str | None
    uploaded_by: uuid.UUID
    uploaded_at: datetime


class VisitCreate(BaseModel):
    patient_id: uuid.UUID
    appointment_id: uuid.UUID | None = None
    visit_date: date
    notes: str | None = None
    diagnosis: str | None = None
    treatment_ids: list[uuid.UUID] = []
    medication_items: list["VisitMedicationItem"] = []


class VisitMedicationItem(BaseModel):
    medication_id: uuid.UUID
    dosage: str = Field(..., min_length=1, max_length=100)
    quantity: int = Field(..., ge=1)


class VisitResponse(BaseModel):
    model_config = {"from_attributes": True}

    id: uuid.UUID
    patient_id: uuid.UUID
    appointment_id: uuid.UUID | None
    visit_date: date
    notes: str | None
    diagnosis: str | None
    photos: list[VisitPhotoResponse]
    created_by: uuid.UUID
    created_at: datetime
```

```python
# app/schemas/common.py
from pydantic import BaseModel


class ErrorResponse(BaseModel):
    error_code: str
    message: str
    details: dict | None = None


class SuccessResponse(BaseModel):
    message: str
```

---

## 7. Authentication & Authorization

Authentication uses **PIN-based login** issuing a JWT access token + refresh token. No username/password — staff select their profile and enter a PIN.

### Security Utilities

```python
# app/utils/security.py
from datetime import datetime, timedelta, timezone
from passlib.context import CryptContext
from jose import JWTError, jwt
from app.config import get_settings

settings = get_settings()
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


def hash_pin(pin: str) -> str:
    """Hash a raw PIN. Never store plain PINs."""
    return pwd_context.hash(pin)


def verify_pin(plain_pin: str, hashed_pin: str) -> bool:
    return pwd_context.verify(plain_pin, hashed_pin)


def create_access_token(payload: dict) -> str:
    data = payload.copy()
    data["exp"] = datetime.now(timezone.utc) + timedelta(
        minutes=settings.access_token_expire_minutes
    )
    data["type"] = "access"
    return jwt.encode(data, settings.jwt_secret_key, algorithm=settings.jwt_algorithm)


def create_refresh_token(payload: dict) -> str:
    data = payload.copy()
    data["exp"] = datetime.now(timezone.utc) + timedelta(
        days=settings.refresh_token_expire_days
    )
    data["type"] = "refresh"
    return jwt.encode(data, settings.jwt_secret_key, algorithm=settings.jwt_algorithm)


def decode_token(token: str) -> dict:
    """Raises JWTError on invalid or expired tokens."""
    return jwt.decode(token, settings.jwt_secret_key, algorithms=[settings.jwt_algorithm])
```

### Auth Dependencies

```python
# app/dependencies.py (auth section)
import uuid
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from jose import JWTError
from sqlalchemy.ext.asyncio import AsyncSession
from app.utils.security import decode_token
from app.models.user import User
from app.database import get_db

bearer_scheme = HTTPBearer()


async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(bearer_scheme),
    db: AsyncSession = Depends(get_db),
) -> User:
    token = credentials.credentials
    try:
        payload = decode_token(token)
        if payload.get("type") != "access":
            raise HTTPException(status_code=401, detail="Invalid token type")
        user_id: str = payload.get("sub")
        if not user_id:
            raise HTTPException(status_code=401, detail="Invalid token payload")
    except JWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token is invalid or expired",
            headers={"WWW-Authenticate": "Bearer"},
        )

    user = await db.get(User, uuid.UUID(user_id))
    if not user or not user.is_active:
        raise HTTPException(status_code=401, detail="User not found or inactive")
    return user


def require_role(*roles: str):
    """Factory: returns a dependency that checks the user's role."""
    async def role_checker(current_user: User = Depends(get_current_user)) -> User:
        if current_user.role not in roles:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Access denied. Required role: {', '.join(roles)}",
            )
        return current_user
    return role_checker


# Convenience shortcuts
require_admin = require_role("admin")
require_any_staff = require_role("admin", "staff")
```

---

## 8. Rate Limiting

Uses **SlowAPI** (Starlette middleware, compatible with FastAPI). Limits are applied at the router level — stricter on auth endpoints, lenient on general reads.

```python
# app/main.py
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded

limiter = Limiter(key_func=get_remote_address, default_limits=["200/minute"])
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)
```

```python
# app/routers/auth.py — strict limits on auth
from slowapi import Limiter
from slowapi.util import get_remote_address
from app.main import limiter

router = APIRouter(prefix="/auth", tags=["Auth"])

@router.post("/login")
@limiter.limit("10/minute")        # 10 login attempts per IP per minute
async def login(request: Request, ...):
    ...

@router.post("/refresh")
@limiter.limit("30/minute")
async def refresh_token(request: Request, ...):
    ...
```

```python
# app/routers/patients.py — standard limits
@router.get("/")
@limiter.limit("100/minute")
async def list_patients(request: Request, ...):
    ...

@router.post("/")
@limiter.limit("60/minute")
async def create_patient(request: Request, ...):
    ...
```

> **Production note:** If you add multiple Uvicorn workers, rate limits become per-worker (not global). For true global limits across workers, use Redis as the SlowAPI storage backend: `Limiter(key_func=get_remote_address, storage_uri="redis://localhost:6379")`.

---

## 9. API Modules

All routers are registered with the `api_prefix` in `main.py`:

```python
# app/main.py
from app.routers import auth, patients, appointments, visits, prescriptions, dashboard, staff, masters

app.include_router(auth.router,          prefix=f"{settings.api_prefix}")
app.include_router(patients.router,      prefix=f"{settings.api_prefix}")
app.include_router(appointments.router,  prefix=f"{settings.api_prefix}")
app.include_router(visits.router,        prefix=f"{settings.api_prefix}")
app.include_router(prescriptions.router, prefix=f"{settings.api_prefix}")
app.include_router(dashboard.router,     prefix=f"{settings.api_prefix}")
app.include_router(staff.router,         prefix=f"{settings.api_prefix}")
app.include_router(masters.router,       prefix=f"{settings.api_prefix}")
```

---

### 9.1 Auth

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/auth/users` | List active staff (for PIN screen profile picker) |
| `POST` | `/auth/login` | Submit PIN → receive JWT access + refresh tokens |
| `POST` | `/auth/refresh` | Exchange refresh token for new access token |
| `POST` | `/auth/logout` | Invalidate session (client deletes token) |

```python
# app/routers/auth.py
from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy.ext.asyncio import AsyncSession
from app.dependencies import get_db, get_current_user
from app.schemas.auth import LoginRequest, TokenResponse, UserListResponse
from app.services.auth_service import AuthService
from app.main import limiter

router = APIRouter(prefix="/auth", tags=["Auth"])


@router.get("/users", response_model=UserListResponse)
@limiter.limit("60/minute")
async def list_users(request: Request, db: AsyncSession = Depends(get_db)):
    """Returns list of active staff for PIN screen. No auth required — only names + IDs."""
    return await AuthService(db).list_active_users()


@router.post("/login", response_model=TokenResponse)
@limiter.limit("10/minute")
async def login(request: Request, body: LoginRequest, db: AsyncSession = Depends(get_db)):
    return await AuthService(db).login(body.user_id, body.pin)


@router.post("/refresh", response_model=TokenResponse)
@limiter.limit("30/minute")
async def refresh(request: Request, body: RefreshRequest, db: AsyncSession = Depends(get_db)):
    return await AuthService(db).refresh_token(body.refresh_token)


@router.post("/logout", status_code=204)
async def logout(current_user=Depends(get_current_user)):
    # JWT is stateless; client is responsible for deleting the token.
    # For server-side invalidation, add token to a Redis blocklist here.
    return
```

```python
# app/services/auth_service.py
from fastapi import HTTPException
from sqlalchemy import select
from app.models.user import User
from app.utils.security import verify_pin, create_access_token, create_refresh_token, decode_token


class AuthService:
    def __init__(self, db):
        self.db = db

    async def login(self, user_id: str, pin: str) -> dict:
        user = await self.db.get(User, user_id)
        if not user or not user.is_active:
            raise HTTPException(status_code=401, detail="Invalid credentials")
        if not verify_pin(pin, user.pin_hash):
            raise HTTPException(status_code=401, detail="Invalid credentials")

        payload = {"sub": str(user.id), "role": user.role, "name": user.name}
        return {
            "access_token": create_access_token(payload),
            "refresh_token": create_refresh_token(payload),
            "token_type": "bearer",
        }

    async def refresh_token(self, refresh_token: str) -> dict:
        from jose import JWTError
        try:
            payload = decode_token(refresh_token)
            if payload.get("type") != "refresh":
                raise HTTPException(status_code=401, detail="Invalid token type")
        except JWTError:
            raise HTTPException(status_code=401, detail="Invalid refresh token")

        new_payload = {"sub": payload["sub"], "role": payload["role"], "name": payload["name"]}
        return {
            "access_token": create_access_token(new_payload),
            "refresh_token": create_refresh_token(new_payload),
            "token_type": "bearer",
        }
```

---

### 9.2 Patients

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| `GET` | `/patients` | Any staff | List patients (paginated, searchable) |
| `POST` | `/patients` | Any staff | Register new patient |
| `GET` | `/patients/{id}` | Any staff | Get patient detail |
| `PATCH` | `/patients/{id}` | Any staff | Update patient info |
| `DELETE` | `/patients/{id}` | Admin only | Soft delete patient |
| `GET` | `/patients/{id}/visits` | Any staff | Get patient's visit history |

```python
# app/routers/patients.py
from fastapi import APIRouter, Depends, Query, Request
from sqlalchemy.ext.asyncio import AsyncSession
from app.dependencies import get_db, get_current_user, require_admin
from app.schemas.patient import PatientCreate, PatientUpdate, PatientResponse, PatientListResponse
from app.schemas.common import SuccessResponse
from app.services.patient_service import PatientService
from app.main import limiter

router = APIRouter(prefix="/patients", tags=["Patients"])


@router.get("/", response_model=PatientListResponse)
@limiter.limit("100/minute")
async def list_patients(
    request: Request,
    search: str | None = Query(None, max_length=100),
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    return await PatientService(db).list_patients(search=search, page=page, page_size=page_size)


@router.post("/", response_model=PatientResponse, status_code=201)
@limiter.limit("60/minute")
async def create_patient(
    request: Request,
    body: PatientCreate,
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    return await PatientService(db).create_patient(body, created_by=current_user.id)


@router.get("/{patient_id}", response_model=PatientResponse)
async def get_patient(
    patient_id: uuid.UUID,
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    return await PatientService(db).get_patient(patient_id)


@router.patch("/{patient_id}", response_model=PatientResponse)
async def update_patient(
    patient_id: uuid.UUID,
    body: PatientUpdate,
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    return await PatientService(db).update_patient(patient_id, body)


@router.delete("/{patient_id}", response_model=SuccessResponse)
async def delete_patient(
    patient_id: uuid.UUID,
    reason: str = Query(..., min_length=5, max_length=500),
    current_user=Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    await PatientService(db).soft_delete(patient_id, reason=reason, deleted_by=current_user.id)
    return {"message": "Patient deleted successfully"}
```

**Patient service — soft delete and patient UID generation:**

```python
# app/services/patient_service.py
from sqlalchemy import select, func, or_
from app.models.patient import Patient
from app.utils.uid import generate_patient_uid


class PatientService:
    def __init__(self, db):
        self.db = db

    async def create_patient(self, data: PatientCreate, created_by) -> Patient:
        uid = await generate_patient_uid(self.db)
        patient = Patient(**data.model_dump(), patient_uid=uid, created_by=created_by)
        self.db.add(patient)
        await self.db.flush()   # Gets the DB-generated ID without committing
        return patient

    async def list_patients(self, search: str | None, page: int, page_size: int) -> dict:
        query = select(Patient).where(Patient.is_deleted == False)
        if search:
            query = query.where(
                or_(
                    Patient.name.ilike(f"%{search}%"),
                    Patient.patient_uid.ilike(f"%{search}%"),
                    Patient.mobile.ilike(f"%{search}%"),
                )
            )
        count_query = select(func.count()).select_from(query.subquery())
        total = (await self.db.execute(count_query)).scalar()
        query = query.order_by(Patient.name).offset((page - 1) * page_size).limit(page_size)
        result = await self.db.execute(query)
        return {"items": result.scalars().all(), "total": total, "page": page, "page_size": page_size}

    async def soft_delete(self, patient_id, reason: str, deleted_by) -> None:
        patient = await self._get_or_404(patient_id)
        patient.is_deleted = True
        patient.deleted_at = datetime.now(timezone.utc)
        patient.deletion_reason = reason
```

```python
# app/utils/uid.py
from sqlalchemy import select, func
from app.models.patient import Patient


async def generate_patient_uid(db) -> str:
    """Generates sequential UIDs: PAT-000001, PAT-000002, ..."""
    result = await db.execute(select(func.count()).select_from(Patient))
    count = result.scalar() or 0
    return f"PAT-{(count + 1):06d}"
```

---

### 9.3 Appointments

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| `GET` | `/appointments` | Any staff | Calendar query (`?date=YYYY-MM-DD&range=day\|week`) |
| `POST` | `/appointments` | Any staff | Create new appointment |
| `GET` | `/appointments/{id}` | Any staff | Get appointment detail |
| `PATCH` | `/appointments/{id}` | Any staff | Update status / reschedule |
| `DELETE` | `/appointments/{id}` | Any staff | Cancel appointment |

**Conflict detection is mandatory — always enforce on the backend:**

```python
# app/services/appointment_service.py
from sqlalchemy import select, and_
from app.models.appointment import Appointment
from fastapi import HTTPException


class AppointmentService:
    def __init__(self, db):
        self.db = db

    async def create_appointment(self, data, created_by) -> Appointment:
        await self._check_conflict(data.scheduled_at, data.duration_minutes)
        appt = Appointment(**data.model_dump(), created_by=created_by, status="scheduled")
        self.db.add(appt)
        await self.db.flush()
        return appt

    async def _check_conflict(self, scheduled_at, duration_minutes, exclude_id=None):
        """Reject overlapping time slots before inserting."""
        from datetime import timedelta
        end_time = scheduled_at + timedelta(minutes=duration_minutes)
        query = select(Appointment).where(
            and_(
                Appointment.status.not_in(["cancelled", "no_show"]),
                Appointment.scheduled_at < end_time,
                (Appointment.scheduled_at + func.make_interval(0, 0, 0, 0, 0, Appointment.duration_minutes)) > scheduled_at,
            )
        )
        if exclude_id:
            query = query.where(Appointment.id != exclude_id)
        conflict = (await self.db.execute(query)).scalars().first()
        if conflict:
            raise HTTPException(
                status_code=409,
                detail={
                    "error_code": "APPOINTMENT_CONFLICT",
                    "message": "This time slot overlaps with an existing appointment",
                    "conflicting_appointment_id": str(conflict.id),
                },
            )
```

**Appointment status FSM:** `scheduled → in_progress → completed | cancelled | no_show`

---

### 9.4 Visits, Notes & Photos

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| `POST` | `/visits` | Any staff | Create visit (notes + treatments + medications) |
| `GET` | `/visits/{id}` | Any staff | Get visit detail with photos |
| `PATCH` | `/visits/{id}` | Any staff | Update visit notes / diagnosis |
| `POST` | `/visits/{id}/photos` | Any staff | Upload one or more photos |
| `DELETE` | `/visits/{id}/photos/{photo_id}` | Any staff | Delete a photo |

```python
# app/routers/visits.py
from fastapi import APIRouter, Depends, UploadFile, File, Form
from typing import Annotated

router = APIRouter(prefix="/visits", tags=["Visits"])


@router.post("/", response_model=VisitResponse, status_code=201)
async def create_visit(
    body: VisitCreate,
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    return await VisitService(db).create_visit(body, created_by=current_user.id)


@router.post("/{visit_id}/photos", response_model=list[VisitPhotoResponse], status_code=201)
@limiter.limit("30/minute")
async def upload_photos(
    request: Request,
    visit_id: uuid.UUID,
    files: Annotated[list[UploadFile], File(...)],
    captions: Annotated[list[str] | None, Form()] = None,
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Accepts up to 10 photos per request.
    Each file is compressed, uploaded to S3, and recorded in visit_photos.
    """
    if len(files) > 10:
        raise HTTPException(status_code=400, detail="Maximum 10 photos per upload")
    return await PhotoService(db).upload_photos(
        visit_id=visit_id,
        files=files,
        captions=captions or [],
        uploaded_by=current_user.id,
    )


@router.delete("/{visit_id}/photos/{photo_id}", status_code=204)
async def delete_photo(
    visit_id: uuid.UUID,
    photo_id: uuid.UUID,
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    await PhotoService(db).delete_photo(photo_id, visit_id)
```

```python
# app/services/photo_service.py
import io
import uuid
from PIL import Image
from app.services.s3_service import S3Service
from app.models.visit_photo import VisitPhoto


MAX_PHOTO_SIZE_KB = 1500   # Compress to under 1.5 MB
PHOTO_MAX_DIMENSION = 1920  # Max width or height in pixels


class PhotoService:
    def __init__(self, db):
        self.db = db
        self.s3 = S3Service()

    async def upload_photos(self, visit_id, files, captions, uploaded_by) -> list[VisitPhoto]:
        results = []
        for i, file in enumerate(files):
            self._validate_file(file)
            compressed = await self._compress_image(file)
            photo_id = uuid.uuid4()
            s3_key = f"visit-photos/{visit_id}/{photo_id}.jpg"
            await self.s3.upload_bytes(s3_key, compressed, content_type="image/jpeg")
            photo_url = await self.s3.get_presigned_url(s3_key)
            caption = captions[i] if i < len(captions) else None
            photo = VisitPhoto(
                id=photo_id,
                visit_id=visit_id,
                s3_key=s3_key,
                photo_url=photo_url,
                caption=caption,
                uploaded_by=uploaded_by,
            )
            self.db.add(photo)
            results.append(photo)
        await self.db.flush()
        return results

    def _validate_file(self, file: UploadFile) -> None:
        allowed_types = {"image/jpeg", "image/png", "image/webp"}
        if file.content_type not in allowed_types:
            raise HTTPException(
                status_code=400,
                detail=f"Unsupported file type: {file.content_type}. Allowed: JPEG, PNG, WebP",
            )

    async def _compress_image(self, file: UploadFile) -> bytes:
        contents = await file.read()
        img = Image.open(io.BytesIO(contents)).convert("RGB")
        # Resize if too large
        if max(img.size) > PHOTO_MAX_DIMENSION:
            img.thumbnail((PHOTO_MAX_DIMENSION, PHOTO_MAX_DIMENSION), Image.LANCZOS)
        output = io.BytesIO()
        quality = 85
        img.save(output, format="JPEG", quality=quality, optimize=True)
        # Reduce quality further if still too large
        while output.tell() > MAX_PHOTO_SIZE_KB * 1024 and quality > 50:
            quality -= 10
            output = io.BytesIO()
            img.save(output, format="JPEG", quality=quality, optimize=True)
        return output.getvalue()

    async def delete_photo(self, photo_id: uuid.UUID, visit_id: uuid.UUID) -> None:
        photo = await self.db.get(VisitPhoto, photo_id)
        if not photo or photo.visit_id != visit_id:
            raise HTTPException(status_code=404, detail="Photo not found")
        await self.s3.delete_object(photo.s3_key)
        await self.db.delete(photo)
```

---

### 9.5 PDF Generation (Prescriptions)

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| `POST` | `/visits/{id}/prescription` | Any staff | Generate prescription PDF |
| `GET` | `/visits/{id}/prescription` | Any staff | Get existing prescription (presigned URL) |

```python
# app/services/pdf_service.py
import io
from jinja2 import Environment, FileSystemLoader
from weasyprint import HTML
from app.services.s3_service import S3Service
from app.models.prescription import Prescription


class PDFService:
    def __init__(self, db):
        self.db = db
        self.s3 = S3Service()
        self.jinja_env = Environment(
            loader=FileSystemLoader("app/templates"),
            autoescape=True,
        )

    async def generate_prescription(self, visit_id: uuid.UUID) -> Prescription:
        visit = await self._get_visit_with_relations(visit_id)
        html_content = self._render_template(visit)
        pdf_bytes = HTML(string=html_content).write_pdf()
        s3_key = f"prescriptions/{visit.visit_date.year}/{visit.visit_date.month}/{visit.patient_id}/{visit_id}.pdf"
        await self.s3.upload_bytes(s3_key, pdf_bytes, content_type="application/pdf")
        pdf_url = await self.s3.get_presigned_url(s3_key)
        prescription = Prescription(
            visit_id=visit_id,
            s3_key=s3_key,
            pdf_url=pdf_url,
        )
        self.db.add(prescription)
        await self.db.flush()
        return prescription

    def _render_template(self, visit) -> str:
        template = self.jinja_env.get_template("prescription.html")
        return template.render(visit=visit, patient=visit.patient, generated_at=datetime.now())
```

---

### 9.6 WhatsApp / WATI

WATI sends are internal — never exposed as a direct API endpoint. Two triggers:

1. **Cron job** — appointment reminders at 24h and 1h before scheduled time
2. **On-demand** — staff manually sends a prescription PDF to a patient

```python
# app/services/whatsapp_service.py
import httpx
from app.config import get_settings
from app.models.whatsapp_message import WhatsAppMessage, MessageType, MessageStatus

settings = get_settings()


class WhatsAppService:
    BASE_URL = settings.wati_api_url
    HEADERS = {"Authorization": f"Bearer {settings.wati_api_token}"}

    async def send_appointment_reminder(self, patient, appointment, reminder_type: str) -> None:
        """reminder_type: '24h' | '1h'"""
        message = self._build_reminder_message(patient, appointment, reminder_type)
        await self._send_message(patient.mobile, message)
        await self._log_message(
            patient_id=patient.id,
            appointment_id=appointment.id,
            msg_type=MessageType.APPOINTMENT_REMINDER,
        )

    async def send_prescription_pdf(self, patient, pdf_url: str) -> None:
        await self._send_document(patient.mobile, pdf_url, filename="prescription.pdf")

    async def _send_message(self, mobile: str, message: str) -> None:
        async with httpx.AsyncClient(timeout=10) as client:
            response = await client.post(
                f"{self.BASE_URL}/api/v1/sendSessionMessage/{mobile}",
                headers=self.HEADERS,
                json={"messageText": message},
            )
            response.raise_for_status()

    async def _send_document(self, mobile: str, url: str, filename: str) -> None:
        async with httpx.AsyncClient(timeout=15) as client:
            response = await client.post(
                f"{self.BASE_URL}/api/v1/sendFile/{mobile}",
                headers=self.HEADERS,
                json={"url": url, "filename": filename},
            )
            response.raise_for_status()

    def _build_reminder_message(self, patient, appointment, reminder_type: str) -> str:
        time_str = appointment.scheduled_at.strftime("%I:%M %p")
        date_str = appointment.scheduled_at.strftime("%d %b %Y")
        window = "tomorrow" if reminder_type == "24h" else "in 1 hour"
        return (
            f"Hello {patient.name},\n"
            f"This is a reminder for your dental appointment {window} "
            f"on {date_str} at {time_str}.\n"
            f"Please arrive 5 minutes early. Call us if you need to reschedule."
        )
```

---

### 9.7 Dashboard

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| `GET` | `/dashboard/summary` | Any staff | Today's stats and appointments |

```python
# app/services/dashboard_service.py
from datetime import date, datetime, timezone
from sqlalchemy import select, func
from app.models.appointment import Appointment
from app.models.patient import Patient
from app.models.user import User


class DashboardService:
    def __init__(self, db):
        self.db = db

    async def get_summary(self) -> dict:
        today = date.today()

        # Today's appointments
        appts_query = select(Appointment).where(
            func.date(Appointment.scheduled_at) == today,
            Appointment.status.not_in(["cancelled"]),
        ).order_by(Appointment.scheduled_at)
        appointments = (await self.db.execute(appts_query)).scalars().all()

        # Patient count
        patient_count = (await self.db.execute(
            select(func.count()).select_from(Patient).where(Patient.is_deleted == False)
        )).scalar()

        # Staff count
        staff_count = (await self.db.execute(
            select(func.count()).select_from(User).where(User.is_active == True)
        )).scalar()

        return {
            "today": str(today),
            "appointments_today": len(appointments),
            "appointments": appointments,
            "total_patients": patient_count,
            "total_staff": staff_count,
        }
```

---

### 9.8 Staff Management

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| `GET` | `/staff` | Admin | List all staff |
| `POST` | `/staff` | Admin | Create new staff member |
| `PATCH` | `/staff/{id}` | Admin | Update staff details |
| `DELETE` | `/staff/{id}` | Admin | Deactivate staff (soft) |
| `POST` | `/staff/{id}/reset-pin` | Admin | Reset staff PIN |
| `GET` | `/activity-logs` | Admin | View audit trail |

```python
# app/routers/staff.py
router = APIRouter(prefix="/staff", tags=["Staff"])

@router.post("/{staff_id}/reset-pin", response_model=SuccessResponse)
async def reset_pin(
    staff_id: uuid.UUID,
    body: PinResetRequest,
    current_user=Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    await StaffService(db).reset_pin(staff_id, body.new_pin)
    return {"message": "PIN reset successfully"}
```

```python
# app/services/staff_service.py
class StaffService:
    async def reset_pin(self, staff_id: uuid.UUID, new_pin: str) -> None:
        if len(new_pin) < 4 or len(new_pin) > 8:
            raise HTTPException(status_code=422, detail="PIN must be 4–8 digits")
        if not new_pin.isdigit():
            raise HTTPException(status_code=422, detail="PIN must contain digits only")
        user = await self.db.get(User, staff_id)
        if not user:
            raise HTTPException(status_code=404, detail="Staff member not found")
        user.pin_hash = hash_pin(new_pin)
```

---

### 9.9 Master Lists

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| `GET` | `/treatments` | Any staff | List active treatments |
| `POST` | `/treatments` | Admin | Create treatment |
| `PATCH` | `/treatments/{id}` | Admin | Update treatment |
| `GET` | `/medications` | Any staff | List active medications |
| `POST` | `/medications` | Admin | Create medication |
| `PATCH` | `/medications/{id}` | Admin | Update medication |

> **Rule:** Never hard-delete masters — only soft-deactivate (`is_active = False`). Existing visit records reference them and must remain valid.

---

### 9.10 Inventory (Add-on)

This module is **feature-flagged** — only active when `INVENTORY_ADDON_ENABLED=true`.

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| `GET` | `/inventory` | Admin | List items with stock levels |
| `POST` | `/inventory` | Admin | Add inventory item |
| `PATCH` | `/inventory/{id}` | Admin | Update stock / item details |
| `GET` | `/inventory/alerts` | Admin | Items below reorder threshold |
| `POST` | `/inventory/invoices` | Admin | Upload supplier invoice PDF (parsed) |

```python
# Feature flag guard in main.py
if settings.inventory_addon_enabled:
    from app.routers import inventory
    app.include_router(inventory.router, prefix=settings.api_prefix)
```

---

## 10. File Storage (S3)

### S3 Service

```python
# app/services/s3_service.py
import boto3
from botocore.exceptions import ClientError
from app.config import get_settings

settings = get_settings()


class S3Service:
    def __init__(self):
        self.client = boto3.client(
            "s3",
            aws_access_key_id=settings.aws_access_key_id,
            aws_secret_access_key=settings.aws_secret_access_key,
            region_name=settings.aws_region,
        )
        self.bucket = settings.s3_bucket_name

    async def upload_bytes(self, key: str, data: bytes, content_type: str) -> None:
        self.client.put_object(
            Bucket=self.bucket,
            Key=key,
            Body=data,
            ContentType=content_type,
            ServerSideEncryption="AES256",
        )

    async def get_presigned_url(self, key: str) -> str:
        return self.client.generate_presigned_url(
            "get_object",
            Params={"Bucket": self.bucket, "Key": key},
            ExpiresIn=settings.s3_presigned_url_expiry,
        )

    async def delete_object(self, key: str) -> None:
        try:
            self.client.delete_object(Bucket=self.bucket, Key=key)
        except ClientError as e:
            raise HTTPException(status_code=500, detail=f"S3 delete failed: {e}")
```

### S3 Folder Structure

```
dental-clinic-files/
├── prescriptions/
│   └── {year}/{month}/{patient_id}/{visit_id}.pdf
└── visit-photos/
    └── {year}/{month}/{patient_id}/{visit_id}/{photo_id}.jpg
```

### S3 Bucket Policy Checklist

- **Block all public access**: enabled
- **Server-side encryption**: SSE-S3 (AES256) on every `put_object`
- **Versioning**: disabled (files are immutable once generated)
- **Lifecycle rule**: transition to S3-IA after 90 days
- **IAM policy** (minimum required):

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:PutObject", "s3:GetObject", "s3:DeleteObject"],
      "Resource": "arn:aws:s3:::dental-clinic-files/*"
    }
  ]
}
```

---

## 11. Error Handling

### Global Exception Handler

```python
# app/main.py
from fastapi import Request
from fastapi.responses import JSONResponse
from fastapi.exceptions import RequestValidationError
import structlog

logger = structlog.get_logger()


@app.exception_handler(RequestValidationError)
async def validation_error_handler(request: Request, exc: RequestValidationError):
    return JSONResponse(
        status_code=422,
        content={
            "error_code": "VALIDATION_ERROR",
            "message": "Request validation failed",
            "details": exc.errors(),
        },
    )


@app.exception_handler(HTTPException)
async def http_exception_handler(request: Request, exc: HTTPException):
    return JSONResponse(
        status_code=exc.status_code,
        content={
            "error_code": exc.detail.get("error_code", "HTTP_ERROR") if isinstance(exc.detail, dict) else "HTTP_ERROR",
            "message": exc.detail if isinstance(exc.detail, str) else exc.detail.get("message", "An error occurred"),
            "details": exc.detail if isinstance(exc.detail, dict) else None,
        },
    )


@app.exception_handler(Exception)
async def unhandled_exception_handler(request: Request, exc: Exception):
    logger.error("unhandled_exception", error=str(exc), path=request.url.path)
    return JSONResponse(
        status_code=500,
        content={
            "error_code": "INTERNAL_SERVER_ERROR",
            "message": "An unexpected error occurred. Please try again.",
        },
    )
```

### Standard HTTP Error Codes

| Code | When to use |
|------|-------------|
| 400 | Bad request (malformed input not caught by Pydantic) |
| 401 | Missing or expired JWT |
| 403 | Valid JWT but insufficient role |
| 404 | Resource not found |
| 409 | Conflict (e.g., appointment slot taken) |
| 422 | Pydantic validation failure |
| 429 | Rate limit exceeded (SlowAPI) |
| 500 | Unexpected server error |

---

## 12. Logging

Uses **structlog** for machine-readable structured JSON logs. Every log entry includes `request_id`, `user_id`, `path`, and `duration_ms`.

```python
# app/middleware/request_id.py
import uuid
import time
import structlog
from starlette.middleware.base import BaseHTTPMiddleware

logger = structlog.get_logger()


class RequestLoggingMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request, call_next):
        request_id = str(uuid.uuid4())
        request.state.request_id = request_id
        start = time.perf_counter()

        response = await call_next(request)

        duration_ms = round((time.perf_counter() - start) * 1000, 2)
        logger.info(
            "request_completed",
            request_id=request_id,
            method=request.method,
            path=request.url.path,
            status_code=response.status_code,
            duration_ms=duration_ms,
        )
        response.headers["X-Request-ID"] = request_id
        return response
```

```python
# app/middleware/activity_logger.py
# Logs all mutating actions (POST/PATCH/DELETE) to the activity_logs table.
# Non-blocking: if the log write fails, the request still succeeds.

LOGGED_PATHS = {"/patients", "/appointments", "/visits", "/staff"}


class ActivityLoggerMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request, call_next):
        response = await call_next(request)
        if request.method in ("POST", "PATCH", "DELETE"):
            if any(request.url.path.startswith(p) for p in LOGGED_PATHS):
                asyncio.create_task(self._write_log(request, response))
        return response

    async def _write_log(self, request, response):
        try:
            async with AsyncSessionLocal() as db:
                log = ActivityLog(
                    user_id=getattr(request.state, "user_id", None),
                    action=request.method,
                    entity_type=request.url.path.split("/")[3] if len(request.url.path.split("/")) > 3 else "unknown",
                    metadata={"path": request.url.path, "status": response.status_code},
                )
                db.add(log)
                await db.commit()
        except Exception:
            pass  # Never fail a request because of a logging error
```

### Structlog Configuration

```python
# app/main.py (startup)
import structlog

structlog.configure(
    processors=[
        structlog.stdlib.add_log_level,
        structlog.stdlib.add_logger_name,
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.JSONRenderer(),    # JSON lines in production
    ],
    wrapper_class=structlog.stdlib.BoundLogger,
    context_class=dict,
    logger_factory=structlog.PrintLoggerFactory(),
)
```

> **Security:** Never log `pin`, `pin_hash`, `mobile` (full number), or any patient medical data. Mask mobile numbers in logs: `+91XXXXXX1234`.

---

## 13. Scheduled Tasks

**APScheduler** runs inside the FastAPI process as a background service. Starts on app startup and shuts down cleanly on app shutdown.

```python
# app/main.py — lifespan
from contextlib import asynccontextmanager
from apscheduler.schedulers.asyncio import AsyncIOScheduler
from app.services.whatsapp_service import run_reminder_job

scheduler = AsyncIOScheduler(timezone="Asia/Kolkata")


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    scheduler.add_job(
        run_reminder_job,
        trigger="interval",
        minutes=30,
        id="whatsapp_reminders",
        replace_existing=True,
        max_instances=1,      # Prevent overlapping runs
    )
    scheduler.start()
    yield
    # Shutdown
    scheduler.shutdown(wait=False)


app = FastAPI(lifespan=lifespan)
```

```python
# app/services/whatsapp_service.py
async def run_reminder_job():
    """
    Scans for appointments in the next 24h and 1h windows.
    Sends WhatsApp reminder only if one hasn't been sent already.
    """
    async with AsyncSessionLocal() as db:
        now = datetime.now(timezone.utc)
        windows = [
            ("24h", now + timedelta(hours=23), now + timedelta(hours=25)),
            ("1h",  now + timedelta(minutes=50), now + timedelta(minutes=70)),
        ]
        svc = WhatsAppService()
        for reminder_type, window_start, window_end in windows:
            query = (
                select(Appointment)
                .join(Patient, Appointment.patient_id == Patient.id)
                .where(
                    Appointment.scheduled_at.between(window_start, window_end),
                    Appointment.status == "scheduled",
                    Patient.whatsapp_enabled == True,
                    ~Appointment.id.in_(
                        select(WhatsAppMessage.appointment_id).where(
                            WhatsAppMessage.type == f"reminder_{reminder_type}",
                            WhatsAppMessage.status == "sent",
                        )
                    ),
                )
            )
            appointments = (await db.execute(query)).scalars().all()
            for appt in appointments:
                try:
                    await svc.send_appointment_reminder(appt.patient, appt, reminder_type)
                except Exception as e:
                    logger.warning("whatsapp_send_failed", appointment_id=str(appt.id), error=str(e))
```

---

## 14. Security Checklist

### Authentication & Session

- [x] PINs stored as **bcrypt hashes** — never plain text
- [x] JWT `secret_key` is a long random string (≥ 64 chars), stored in `.env`
- [x] Access tokens expire in 60 minutes; refresh tokens in 7 days
- [x] Refresh tokens are single-use (optional: add Redis blocklist for rotation)
- [x] `flutter_secure_storage` (Android Keystore) on the mobile side
- [x] Auto-logout on idle enforced on client; server validates expiry on every request

### API & Network

- [x] All endpoints are under HTTPS (Let's Encrypt via Certbot + Nginx)
- [x] FastAPI port (8000) **not exposed** to internet — only Nginx on 443
- [x] CORS locked to mobile app origin only
- [x] Rate limiting on all endpoints; strict limits on `/auth/login`
- [x] Role check enforced at the **backend** level — never trust client role claims
- [x] `X-Request-ID` header on every response for tracing

### Data & Storage

- [x] S3 bucket has **Block All Public Access** enabled
- [x] All S3 objects use **SSE-S3** encryption at rest
- [x] Presigned URLs expire in **15 minutes**
- [x] Soft-deleted patients are excluded from all queries (`WHERE is_deleted = FALSE`)
- [x] No PII (patient names, mobile numbers) in logs or error messages
- [x] Database credentials in `.env` — not in codebase, not in version control

### Infrastructure

- [x] Lightsail Managed DB accessible only via **private network** (not public internet)
- [x] SSH access restricted to known IP(s) — port 22 firewall rule
- [x] Uvicorn runs as a **non-root** `systemd` service
- [x] Environment variables loaded from `.env` file via `systemd EnvironmentFile`
- [x] Regular DB snapshots (7-day retention via Lightsail Managed DB)

---

## 15. Testing Strategy

### Test Configuration

```python
# tests/conftest.py
import pytest
import pytest_asyncio
from httpx import AsyncClient, ASGITransport
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker
from app.main import app
from app.database import Base, get_db
from app.utils.security import hash_pin, create_access_token

TEST_DATABASE_URL = "postgresql+asyncpg://test_user:test_pass@localhost:5432/dental_test"

test_engine = create_async_engine(TEST_DATABASE_URL, echo=False)
TestSessionLocal = async_sessionmaker(test_engine, expire_on_commit=False)


@pytest_asyncio.fixture(autouse=True)
async def setup_db():
    async with test_engine.begin() as conn:
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
    return create_access_token({"sub": str(user.id), "role": "admin", "name": "Admin"})


@pytest_asyncio.fixture
async def staff_token(db):
    user = User(name="Staff", role="staff", pin_hash=hash_pin("5678"), is_active=True)
    db.add(user)
    await db.commit()
    return create_access_token({"sub": str(user.id), "role": "staff", "name": "Staff"})
```

### Integration Test Example

```python
# tests/integration/test_patient_routes.py
import pytest


@pytest.mark.asyncio
async def test_create_patient_success(client, admin_token):
    response = await client.post(
        "/api/v1/patients",
        json={"name": "John Doe", "mobile": "+919876543210"},
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert response.status_code == 201
    data = response.json()
    assert data["name"] == "John Doe"
    assert data["patient_uid"].startswith("PAT-")


@pytest.mark.asyncio
async def test_create_patient_requires_auth(client):
    response = await client.post("/api/v1/patients", json={"name": "Jane", "mobile": "+91123"})
    assert response.status_code == 403


@pytest.mark.asyncio
async def test_delete_patient_requires_admin(client, staff_token, db):
    # Create a patient first
    patient = Patient(name="Test", mobile="+91999", patient_uid="PAT-000001", created_by=uuid.uuid4())
    db.add(patient)
    await db.commit()

    response = await client.delete(
        f"/api/v1/patients/{patient.id}?reason=Test deletion",
        headers={"Authorization": f"Bearer {staff_token}"},
    )
    assert response.status_code == 403


@pytest.mark.asyncio
async def test_appointment_conflict_detection(client, admin_token, db):
    patient = Patient(name="P1", mobile="+91111", patient_uid="PAT-000001", created_by=uuid.uuid4())
    db.add(patient)
    await db.commit()
    slot = {"patient_id": str(patient.id), "scheduled_at": "2026-05-10T10:00:00Z", "duration_minutes": 30}

    r1 = await client.post("/api/v1/appointments", json=slot, headers={"Authorization": f"Bearer {admin_token}"})
    assert r1.status_code == 201

    r2 = await client.post("/api/v1/appointments", json=slot, headers={"Authorization": f"Bearer {admin_token}"})
    assert r2.status_code == 409
    assert r2.json()["error_code"] == "APPOINTMENT_CONFLICT"
```

### Unit Test Example

```python
# tests/unit/test_photo_service.py
import pytest
from unittest.mock import AsyncMock, patch, MagicMock
from app.services.photo_service import PhotoService


@pytest.mark.asyncio
async def test_rejects_non_image_file():
    svc = PhotoService(db=AsyncMock())
    fake_file = MagicMock()
    fake_file.content_type = "application/pdf"
    with pytest.raises(HTTPException) as exc:
        svc._validate_file(fake_file)
    assert exc.value.status_code == 400
```

**Run tests:**

```bash
# All tests with coverage report
pytest --cov=app --cov-report=term-missing -v

# Only integration tests
pytest tests/integration/ -v

# Only unit tests
pytest tests/unit/ -v
```

---

## 16. Deployment

### Application (`systemd` service)

```ini
# /etc/systemd/system/dental-backend.service
[Unit]
Description=Dental Clinic FastAPI Backend
After=network.target

[Service]
Type=simple
User=dental
WorkingDirectory=/home/dental/app
EnvironmentFile=/home/dental/app/.env
ExecStart=/home/dental/venv/bin/uvicorn app.main:app --host 127.0.0.1 --port 8000 --workers 2 --log-level warning
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable dental-backend
sudo systemctl start dental-backend
sudo systemctl status dental-backend
```

### Nginx Reverse Proxy

```nginx
# /etc/nginx/sites-available/dental-api
server {
    listen 80;
    server_name api.yourclinic.com;
    return 301 https://$host$request_uri;  # Force HTTPS
}

server {
    listen 443 ssl;
    server_name api.yourclinic.com;

    ssl_certificate     /etc/letsencrypt/live/api.yourclinic.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/api.yourclinic.com/privkey.pem;
    ssl_protocols       TLSv1.2 TLSv1.3;
    ssl_ciphers         HIGH:!aNULL:!MD5;

    # Security headers
    add_header X-Content-Type-Options nosniff;
    add_header X-Frame-Options DENY;
    add_header X-XSS-Protection "1; mode=block";
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

    # Limit upload size (for photo uploads — 10 photos × 1.5MB)
    client_max_body_size 20M;

    location / {
        proxy_pass         http://127.0.0.1:8000;
        proxy_set_header   Host $host;
        proxy_set_header   X-Real-IP $remote_addr;
        proxy_set_header   X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto $scheme;
        proxy_read_timeout 60s;
        proxy_send_timeout 60s;
    }
}
```

```bash
# Get Let's Encrypt certificate
sudo certbot --nginx -d api.yourclinic.com
# Auto-renewal is set up by certbot; verify with:
sudo certbot renew --dry-run
```

### GitHub Actions CI/CD

```yaml
# .github/workflows/deploy.yml
name: Test & Deploy

on:
  push:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:15
        env:
          POSTGRES_USER: test_user
          POSTGRES_PASSWORD: test_pass
          POSTGRES_DB: dental_test
        ports: ["5432:5432"]
        options: --health-cmd pg_isready --health-interval 10s --health-timeout 5s --health-retries 5

    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with: { python-version: "3.12" }
      - run: pip install -r requirements.txt -r requirements-dev.txt
      - run: pytest --cov=app --cov-fail-under=80
        env:
          DATABASE_URL: postgresql+asyncpg://test_user:test_pass@localhost:5432/dental_test
          JWT_SECRET_KEY: test-secret-key-for-ci-only

  deploy:
    needs: test
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    steps:
      - uses: actions/checkout@v4
      - name: Deploy to Lightsail
        uses: appleboy/ssh-action@v1
        with:
          host: ${{ secrets.LIGHTSAIL_HOST }}
          username: dental
          key: ${{ secrets.LIGHTSAIL_SSH_KEY }}
          script: |
            cd /home/dental/app
            git pull origin main
            source venv/bin/activate
            pip install -r requirements.txt --quiet
            alembic upgrade head
            sudo systemctl restart dental-backend
            echo "✅ Deploy complete"
```

### Health Check Endpoint

```python
# app/routers/health.py
@router.get("/health", include_in_schema=False)
async def health_check(db: AsyncSession = Depends(get_db)):
    try:
        await db.execute(text("SELECT 1"))
        return {"status": "ok", "database": "connected"}
    except Exception:
        return JSONResponse(status_code=503, content={"status": "error", "database": "unreachable"})
```

### Deployment Checklist

Before every production deploy:

- [ ] `alembic upgrade head` runs before `systemctl restart`
- [ ] `.env` on the server is up to date (never in Git)
- [ ] Tests pass at ≥ 80% coverage in CI before deploy runs
- [ ] `ENVIRONMENT=production` and `DEBUG=false` in `.env`
- [ ] Nginx `client_max_body_size` is set (≥ 20M for photo uploads)
- [ ] S3 bucket policy has Block All Public Access confirmed
- [ ] Lightsail firewall only allows 443 and SSH from known IPs

---

*Last updated: April 2026 — Dental Clinic App v1.0*
