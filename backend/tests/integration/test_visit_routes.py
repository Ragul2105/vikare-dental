from __future__ import annotations

from sqlalchemy import select

from app.models.medication_master import MedicationMaster
from app.models.patient import Patient
from app.models.treatment_master import TreatmentMaster
from app.models.user import User
from app.models.visit import Visit
from app.models.visit_medication import VisitMedication
from app.models.visit_treatment import VisitTreatment


async def test_create_visit_with_treatments_and_medications(client, admin_token, db):
    admin_user = (await db.execute(select(User).where(User.name == "Admin"))).scalar_one()
    patient = Patient(
        name="Visit Patient",
        mobile="+919876543213",
        patient_uid="PAT-000001",
        created_by=admin_user.id,
    )
    cleaning = TreatmentMaster(name="Cleaning", created_by=admin_user.id)
    filling = TreatmentMaster(name="Filling", created_by=admin_user.id)
    ibuprofen = MedicationMaster(
        name="Ibuprofen",
        default_dosage="400mg",
        created_by=admin_user.id,
    )
    db.add_all([patient, cleaning, filling, ibuprofen])
    await db.commit()

    response = await client.post(
        "/api/v1/visits",
        json={
            "patient_id": str(patient.id),
            "visit_date": "2026-04-24",
            "notes": "Initial visit",
            "diagnosis": "General checkup",
            "treatment_ids": [str(cleaning.id), str(filling.id)],
            "medication_items": [
                {
                    "medication_id": str(ibuprofen.id),
                    "dosage": "400mg",
                    "quantity": 2,
                }
            ],
        },
        headers={"Authorization": f"Bearer {admin_token}"},
    )

    assert response.status_code == 201
    data = response.json()
    assert data["patient_id"] == str(patient.id)
    assert data["diagnosis"] == "General checkup"
    assert {item["treatment_name"] for item in data["treatments"]} == {"Cleaning", "Filling"}
    assert len(data["medications"]) == 1
    assert data["medications"][0]["medication_name"] == "Ibuprofen"
    assert data["medications"][0]["quantity"] == 2

    visit = (await db.execute(select(Visit))).scalar_one()
    assert visit.patient_id == patient.id
    assert (await db.execute(select(VisitTreatment))).scalars().all()
    assert (await db.execute(select(VisitMedication))).scalars().all()
