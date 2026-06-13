# Dental Clinic Workspace

This workspace is now split into:

- `backend/`: FastAPI backend, database migrations, seed script, tests
- `frontend/`: Flutter Android app for doctors and staff

The detailed reference guides remain at the repo root:

- `backend-development-guide.md`
- `frontend-development-guide.md`

## Quick Start

### Backend

```bash
cd backend
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt -r requirements-dev.txt
alembic upgrade head
python scripts/seed.py
uvicorn app.main:app --reload
```

Backend base URL:

- `http://127.0.0.1:8000/api/v1`

Default seeded users:

- `Dr. Admin` / `1234`
- `Front Desk` / `5678`

### Frontend

```bash
cd frontend
flutter pub get
flutter run --dart-define=BASE_URL=http://10.0.2.2:8000/api/v1
```

Use `10.0.2.2` for the Android emulator. If you run the app on a physical device, replace it with your machine's LAN IP.

## What Changed

- The previous backend-only workspace was moved into `backend/`.
- A full Flutter frontend was added in `frontend/`.
- The backend now supports local filesystem-backed asset storage in development, so visit photo uploads and prescription PDFs work without real AWS S3 credentials.
- Appointment responses now include `patient_name`, which simplifies the frontend calendar and detail flows.

## Verification

- Backend tests: `7 passed`
- Frontend analysis: `flutter analyze` passes
- Frontend tests: `flutter test` passes
