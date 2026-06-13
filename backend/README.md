# Dental Backend

Backend for the Dental Clinic application, built with FastAPI, async SQLAlchemy, Alembic, and PostgreSQL.

This backend lives inside the workspace monorepo under `backend/`.

The detailed backend design reference is [../backend-development-guide.md](../backend-development-guide.md). This README covers the concrete backend setup and current development workflow.

## Overview

- Stack: Python 3.12, FastAPI, SQLAlchemy 2.0 async, PostgreSQL, Alembic, Pydantic v2
- Access model: doctor and staff only
- Auth model: PIN-based login with JWT access and refresh tokens
- Storage integrations: AWS S3 for files, WATI for WhatsApp, APScheduler for reminder jobs
- Database mode: async `asyncpg`
- API prefix: `/api/v1`

## What Is Implemented

The current codebase includes:

- App bootstrap, middleware, exception handling, rate limiting, and structured logging
- Auth module
- Patients module
- Appointments module with backend conflict detection
- Visits module with treatments, medications, and photo upload flow
- Prescription PDF generation flow
- Dashboard summary endpoint
- Staff management and activity log endpoints
- Treatment and medication master lists
- Inventory module behind a feature flag
- Alembic migration setup
- Dev seed script
- Unit and integration test scaffolding

## Project Structure

```text
backend/
├── app/
│   ├── config.py
│   ├── database.py
│   ├── dependencies.py
│   ├── main.py
│   ├── middleware/
│   ├── models/
│   ├── routers/
│   ├── schemas/
│   ├── services/
│   ├── templates/
│   └── utils/
├── alembic/
│   ├── env.py
│   └── versions/
├── scripts/
│   └── seed.py
├── tests/
│   ├── integration/
│   ├── unit/
│   └── conftest.py
├── data/
│   └── storage/              # Local development file storage for photos / PDFs
├── pyproject.toml
├── requirements.txt
├── requirements-dev.txt
└── .env.example
```

## Architecture Rules

These rules come from the guide and are followed in this repository:

- Routers handle HTTP concerns only.
- Services contain business logic and database access.
- Models define the persistence layer.
- Schemas define request and response shapes.
- Shared dependencies live in `app/dependencies.py`.
- Middleware handles request tracing and audit logging.

## Prerequisites

You need:

- Python `3.12.12`
- `pyenv` recommended
- Docker running locally
- A PostgreSQL container exposed on `localhost:5432`

The project is pinned via [`.python-version`](.python-version) to `3.12.12`.

## Local Database Setup

This project is configured for a local PostgreSQL instance running in Docker with:

- username: `admin`
- password: `admin`
- host: `localhost`
- port: `5432`

Default databases used by this repo:

- app database: `dental_db`
- test database: `dental_test`

### If you already have a local Postgres container

Make sure it is exposed on `localhost:5432`, then create the databases:

```bash
docker exec my-postgres createdb -U admin dental_db
docker exec my-postgres createdb -U admin dental_test
```

### If you need to start a Postgres container

```bash
docker run -d \
  --name my-postgres \
  -e POSTGRES_USER=admin \
  -e POSTGRES_PASSWORD=admin \
  -e POSTGRES_DB=admin \
  -p 5432:5432 \
  postgres:15
```

Then create the two project databases:

```bash
docker exec my-postgres createdb -U admin dental_db
docker exec my-postgres createdb -U admin dental_test
```

## Environment Variables

The project reads configuration from `.env` using Pydantic Settings.

Start from [`.env.example`](.env.example):

```bash
cp .env.example .env
```

Important variables:

- `DATABASE_URL`
- `JWT_SECRET_KEY`
- `FILE_STORAGE_BACKEND`
- `LOCAL_STORAGE_PATH`
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_REGION`
- `S3_BUCKET_NAME`
- `WATI_API_URL`
- `WATI_API_TOKEN`
- `ENVIRONMENT`
- `DEBUG`
- `API_PREFIX`
- `INVENTORY_ADDON_ENABLED`

### Local default database URL

```dotenv
DATABASE_URL=postgresql+asyncpg://admin:admin@localhost:5432/dental_db
```

### Local file storage vs S3

For development, the backend is configured with:

```dotenv
FILE_STORAGE_BACKEND=local
LOCAL_STORAGE_PATH=data/storage
```

With this mode enabled:

- visit photos are written under `backend/data/storage/`
- prescription PDFs are written under `backend/data/storage/`
- the API returns local asset URLs under `/api/v1/assets/...`

This means photo upload and prescription generation work locally without real S3 credentials.

### Important note about external integrations

When you switch `FILE_STORAGE_BACKEND=s3`, real AWS credentials are required for:

- visit photo upload to S3
- prescription PDF upload to S3

WhatsApp reminder sends still require real WATI credentials.

## Installation

### 1. Use Python 3.12.12

```bash
pyenv install 3.12.12
pyenv local 3.12.12
```

### 2. Create a virtual environment

```bash
python -m venv .venv
source .venv/bin/activate
```

### 3. Install dependencies

```bash
pip install -r requirements.txt -r requirements-dev.txt
```

## Database Migration

Apply the schema:

```bash
alembic upgrade head
```

Check current migration:

```bash
alembic current
```

Create a new migration after model changes:

```bash
alembic revision --autogenerate -m "describe_change"
```

## Seed Data

Seed the development database:

```bash
python scripts/seed.py
```

The seed currently adds:

- `Dr. Admin` with PIN `1234`
- `Front Desk` with PIN `5678`
- starter treatment masters
- starter medication masters

These are development-only defaults. Do not use them in production.

## Running the API

Start the server locally:

```bash
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

By default, the app will be available at:

- API base: `http://127.0.0.1:8000/api/v1`
- Swagger docs: `http://127.0.0.1:8000/docs`
- ReDoc: `http://127.0.0.1:8000/redoc`
- Health check: `http://127.0.0.1:8000/api/v1/health`

## Main API Modules

Implemented route groups:

- `/auth`
  - `GET /users`
  - `POST /login`
  - `POST /refresh`
  - `POST /logout`
- `/patients`
  - list, create, detail, update, soft delete, patient visit history
- `/appointments`
  - list, create, detail, update, cancel
- `/visits`
  - create, detail, update, upload photos, delete photos
- `/visits/{visit_id}/prescription`
  - generate and fetch prescription PDF
- `/dashboard/summary`

## Validation

Run the backend test suite from inside `backend/`:

```bash
.venv/bin/python -m pytest -q
```
- `/staff`
  - list, create, update, deactivate, reset PIN
- `/activity-logs`
- `/treatments`
- `/medications`
- `/inventory`
  - only when `INVENTORY_ADDON_ENABLED=true`

## Auth Flow

The API uses PIN-based login instead of username/password.

Typical flow:

1. Call `GET /api/v1/auth/users`
2. Choose a user profile
3. Call `POST /api/v1/auth/login` with `user_id` and `pin`
4. Use the returned bearer token in `Authorization: Bearer <token>`

## Local Development Workflow

Typical daily workflow:

1. Start Docker and ensure Postgres is up
2. Activate the virtualenv
3. Run `alembic upgrade head`
4. Run `python scripts/seed.py` if needed
5. Start the app with `uvicorn app.main:app --reload`
6. Run tests before committing changes

## Testing

Run the full test suite:

```bash
pytest -v
```

Run with coverage:

```bash
pytest --cov=app --cov-report=term-missing -v
```

Run only integration tests:

```bash
pytest tests/integration -v
```

Run only unit tests:

```bash
pytest tests/unit -v
```

### Test database

Tests expect a PostgreSQL database at:

```dotenv
TEST_DATABASE_URL=postgresql+asyncpg://admin:admin@localhost:5432/dental_test
```

You can export it explicitly if needed:

```bash
export TEST_DATABASE_URL=postgresql+asyncpg://admin:admin@localhost:5432/dental_test
```

## Implemented Middleware and Platform Concerns

- Request ID middleware adds `X-Request-ID`
- Activity log middleware records mutating requests
- Structured JSON logging via `structlog`
- Global validation and exception handlers
- SlowAPI rate limiting
- APScheduler reminder job bootstrap in app lifespan

## Feature Flags

Inventory routes are disabled by default.

Enable them with:

```dotenv
INVENTORY_ADDON_ENABLED=true
```

## Files Worth Knowing

- [app/main.py](app/main.py): app factory, middleware, routers, exception handlers, scheduler
- [app/config.py](app/config.py): environment settings
- [app/database.py](app/database.py): async engine and session setup
- [app/dependencies.py](app/dependencies.py): DB and auth dependencies
- [alembic/env.py](alembic/env.py): Alembic wiring
- [scripts/seed.py](scripts/seed.py): development seed data
- [backend-development-guide.md](backend-development-guide.md): design and implementation guide

## Operational Notes

- Patients are soft-deleted, not hard-deleted.
- Treatment and medication masters are intended to be soft-deactivated, not removed.
- Appointment overlap detection is enforced in the backend.
- Photo upload and prescription generation depend on working S3 credentials.
- Reminder scheduling is bootstrapped automatically when the app starts.

## Troubleshooting

### Python version issues

If dependency installation fails, verify you are using Python `3.12.12`:

```bash
python --version
cat .python-version
```

### Postgres connection issues

Check that Docker is running and the container is exposing `5432`:

```bash
docker ps
pg_isready -h localhost -p 5432 -U admin
```

### Migration issues

If the schema is out of sync:

```bash
alembic current
alembic upgrade head
```

### External service issues

If S3, PDF upload, or WhatsApp flows fail locally, verify the relevant credentials in `.env`. The app can start with placeholder values, but those integrations require real configuration.

## Current Verified Local Flow

The following flow has already been validated for this repository:

1. Python `3.12.12` environment created
2. Dependencies installed in `.venv`
3. `dental_db` and `dental_test` created in local Docker Postgres
4. `alembic upgrade head` applied successfully
5. `python scripts/seed.py` executed successfully
6. Focused unit and integration tests passed

## Future Documentation Source of Truth

If you extend the backend, update both:

- this `README.md` for practical setup and usage
- [backend-development-guide.md](backend-development-guide.md) for design-level standards
