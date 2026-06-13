from __future__ import annotations

import uuid

from fastapi import HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.appointment import Appointment
from app.models.medication_master import MedicationMaster
from app.models.patient import Patient
from app.models.treatment_master import TreatmentMaster
from app.models.visit import Visit
from app.models.visit_medication import VisitMedication
from app.models.visit_treatment import VisitTreatment
from app.schemas.visit import VisitCreate, VisitMedicationItem, VisitUpdate
from app.services.s3_service import S3Service


class VisitService:
    def __init__(self, db: AsyncSession):
        self.db = db
        self.s3 = S3Service()

    async def create_visit(self, data: VisitCreate, created_by: uuid.UUID) -> Visit:
        patient = await self._get_patient_or_404(data.patient_id)
        appointment = await self._get_appointment_if_provided(data.appointment_id, patient.id)

        visit = Visit(
            patient_id=patient.id,
            appointment_id=data.appointment_id,
            visit_date=data.visit_date,
            notes=data.notes,
            diagnosis=data.diagnosis,
            created_by=created_by,
            treatments=[],
            medications=[],
        )
        self.db.add(visit)

        await self._replace_treatments(visit, data.treatment_ids)
        await self._replace_medications(visit, data.medication_items)

        if appointment and appointment.status == "scheduled":
            appointment.status = "completed"

        await self.db.flush()
        return await self.get_visit(visit.id)

    async def get_visit(self, visit_id: uuid.UUID) -> Visit:
        result = await self.db.execute(
            select(Visit)
            .options(
                selectinload(Visit.patient),
                selectinload(Visit.photos),
                selectinload(Visit.prescription),
                selectinload(Visit.treatments).selectinload(VisitTreatment.treatment),
                selectinload(Visit.medications).selectinload(VisitMedication.medication),
            )
            .where(Visit.id == visit_id)
        )
        visit = result.scalar_one_or_none()
        if not visit:
            raise HTTPException(status_code=404, detail="Visit not found")

        await self._refresh_asset_urls(visit)
        return visit

    async def update_visit(self, visit_id: uuid.UUID, data: VisitUpdate) -> Visit:
        visit = await self.get_visit(visit_id)
        payload = data.model_dump(exclude_unset=True)

        treatment_ids = payload.pop("treatment_ids", None)
        medication_items = payload.pop("medication_items", None)

        for field, value in payload.items():
            setattr(visit, field, value)

        if treatment_ids is not None:
            await self._replace_treatments(visit, treatment_ids)
        if medication_items is not None:
            await self._replace_medications(visit, medication_items)

        await self.db.flush()
        return await self.get_visit(visit.id)

    async def _replace_treatments(self, visit: Visit, treatment_ids: list[uuid.UUID]) -> None:
        visit.treatments.clear()
        if not treatment_ids:
            return

        result = await self.db.execute(
            select(TreatmentMaster).where(
                TreatmentMaster.id.in_(treatment_ids),
                TreatmentMaster.is_active.is_(True),
            )
        )
        masters = {master.id: master for master in result.scalars().all()}
        missing_ids = [str(treatment_id) for treatment_id in treatment_ids if treatment_id not in masters]
        if missing_ids:
            raise HTTPException(
                status_code=404,
                detail=f"Unknown treatment ids: {', '.join(missing_ids)}",
            )

        for treatment_id in treatment_ids:
            visit.treatments.append(VisitTreatment(treatment_id=treatment_id))

    async def _replace_medications(
        self,
        visit: Visit,
        medication_items: list[VisitMedicationItem],
    ) -> None:
        visit.medications.clear()
        if not medication_items:
            return

        medication_ids = [item.medication_id for item in medication_items]
        result = await self.db.execute(
            select(MedicationMaster).where(
                MedicationMaster.id.in_(medication_ids),
                MedicationMaster.is_active.is_(True),
            )
        )
        masters = {master.id: master for master in result.scalars().all()}
        missing_ids = [str(medication_id) for medication_id in medication_ids if medication_id not in masters]
        if missing_ids:
            raise HTTPException(
                status_code=404,
                detail=f"Unknown medication ids: {', '.join(missing_ids)}",
            )

        for item in medication_items:
            visit.medications.append(
                VisitMedication(
                    medication_id=item.medication_id,
                    dosage=item.dosage,
                    quantity=item.quantity,
                )
            )

    async def _get_patient_or_404(self, patient_id: uuid.UUID) -> Patient:
        patient = await self.db.get(Patient, patient_id)
        if not patient or patient.is_deleted:
            raise HTTPException(status_code=404, detail="Patient not found")
        return patient

    async def _get_appointment_if_provided(
        self,
        appointment_id: uuid.UUID | None,
        patient_id: uuid.UUID,
    ) -> Appointment | None:
        if not appointment_id:
            return None

        appointment = await self.db.get(Appointment, appointment_id)
        if not appointment:
            raise HTTPException(status_code=404, detail="Appointment not found")
        if appointment.patient_id != patient_id:
            raise HTTPException(status_code=409, detail="Appointment does not belong to patient")
        return appointment

    async def _refresh_asset_urls(self, visit: Visit) -> None:
        for photo in visit.photos:
            photo.photo_url = await self.s3.get_presigned_url(photo.s3_key)
        if visit.prescription:
            visit.prescription.pdf_url = await self.s3.get_presigned_url(visit.prescription.s3_key)
