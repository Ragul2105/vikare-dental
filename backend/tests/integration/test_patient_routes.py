from __future__ import annotations

from sqlalchemy import select

from app.models.patient import Patient
from app.models.user import User


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


async def test_create_patient_requires_auth(client):
    response = await client.post(
        "/api/v1/patients",
        json={"name": "Jane Doe", "mobile": "+919876543210"},
    )
    assert response.status_code == 403


async def test_delete_patient_requires_admin(client, staff_token, db):
    staff_user = (await db.execute(select(User).where(User.name == "Staff"))).scalar_one()
    patient = Patient(
        name="Test",
        mobile="+919876543211",
        patient_uid="PAT-000001",
        created_by=staff_user.id,
    )
    db.add(patient)
    await db.commit()
    await db.refresh(patient)

    response = await client.delete(
        f"/api/v1/patients/{patient.id}?reason=Testing deletion",
        headers={"Authorization": f"Bearer {staff_token}"},
    )
    assert response.status_code == 403
