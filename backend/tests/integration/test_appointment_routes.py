from __future__ import annotations

from datetime import datetime
from zoneinfo import ZoneInfo

from sqlalchemy import select

from app.models.appointment import Appointment
from app.models.patient import Patient
from app.models.user import User

INDIA_TZ = ZoneInfo("Asia/Kolkata")


async def test_appointment_conflict_detection(client, admin_token, db):
    admin_user = (await db.execute(select(User).where(User.name == "Admin"))).scalar_one()
    patient = Patient(
        name="Patient One",
        mobile="+919876543212",
        patient_uid="PAT-000001",
        created_by=admin_user.id,
    )
    db.add(patient)
    await db.commit()
    await db.refresh(patient)

    slot = {
        "patient_id": str(patient.id),
        "scheduled_at": "2026-05-10T10:00:00+05:30",
        "duration_minutes": 30,
    }

    first = await client.post(
        "/api/v1/appointments",
        json=slot,
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert first.status_code == 201

    second = await client.post(
        "/api/v1/appointments",
        json=slot,
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert second.status_code == 409
    assert second.json()["error_code"] == "APPOINTMENT_CONFLICT"


async def test_create_appointment_returns_patient_name(client, admin_token, db):
    admin_user = (await db.execute(select(User).where(User.name == "Admin"))).scalar_one()
    patient = Patient(
        name="Patient Two",
        mobile="+919876543214",
        patient_uid="PAT-000002",
        created_by=admin_user.id,
    )
    db.add(patient)
    await db.commit()
    await db.refresh(patient)

    response = await client.post(
        "/api/v1/appointments",
        json={
            "patient_id": str(patient.id),
            "scheduled_at": "2026-05-11T09:30:00+05:30",
            "duration_minutes": 45,
            "reason": "Consultation",
        },
        headers={"Authorization": f"Bearer {admin_token}"},
    )

    assert response.status_code == 201
    data = response.json()
    assert data["patient_id"] == str(patient.id)
    assert data["patient_name"] == "Patient Two"
    assert data["status"] == "scheduled"
    assert data["scheduled_at"] == "2026-05-11T09:30:00+05:30"


async def test_update_appointment_keeps_patient_name_in_response(client, admin_token, db):
    admin_user = (await db.execute(select(User).where(User.name == "Admin"))).scalar_one()
    patient = Patient(
        name="Patient Three",
        mobile="+919876543215",
        patient_uid="PAT-000003",
        created_by=admin_user.id,
    )
    db.add(patient)
    await db.commit()
    await db.refresh(patient)

    appointment = Appointment(
        patient_id=patient.id,
        scheduled_at=datetime.fromisoformat("2026-05-12T10:00:00+00:00"),
        duration_minutes=30,
        status="scheduled",
        created_by=admin_user.id,
    )
    db.add(appointment)
    await db.commit()
    await db.refresh(appointment)

    response = await client.patch(
        f"/api/v1/appointments/{appointment.id}",
        json={
            "reason": "Follow up",
            "duration_minutes": 40,
        },
        headers={"Authorization": f"Bearer {admin_token}"},
    )

    assert response.status_code == 200
    data = response.json()
    assert data["patient_id"] == str(patient.id)
    assert data["patient_name"] == "Patient Three"
    assert data["duration_minutes"] == 40
    assert data["reason"] == "Follow up"


async def test_list_appointments_uses_india_day_boundaries(client, admin_token, db):
    admin_user = (await db.execute(select(User).where(User.name == "Admin"))).scalar_one()
    patient = Patient(
        name="Boundary Patient",
        mobile="+919876543216",
        patient_uid="PAT-000004",
        created_by=admin_user.id,
    )
    db.add(patient)
    await db.flush()
    appointment = Appointment(
        patient_id=patient.id,
        scheduled_at=datetime(2026, 5, 11, 0, 15, tzinfo=INDIA_TZ),
        duration_minutes=20,
        status="scheduled",
        created_by=admin_user.id,
    )
    db.add(appointment)
    await db.commit()

    response = await client.get(
        "/api/v1/appointments",
        params={"date": "2026-05-11", "range": "day"},
        headers={"Authorization": f"Bearer {admin_token}"},
    )

    assert response.status_code == 200
    data = response.json()
    assert len(data["items"]) == 1
    assert data["items"][0]["patient_name"] == "Boundary Patient"
    assert data["items"][0]["scheduled_at"] == "2026-05-11T00:15:00+05:30"
