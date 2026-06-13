from __future__ import annotations

from datetime import datetime, timezone
import uuid

from fastapi import HTTPException
from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.patient import Patient
from app.models.visit import Visit
from app.models.visit_medication import VisitMedication
from app.models.visit_treatment import VisitTreatment
from app.schemas.patient import PatientCreate, PatientUpdate
from app.utils.pagination import calculate_offset
from app.utils.uid import generate_patient_uid


class PatientService:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def create_patient(self, data: PatientCreate, created_by: uuid.UUID) -> Patient:
        uid = await generate_patient_uid(self.db)
        patient = Patient(**data.model_dump(), patient_uid=uid, created_by=created_by)
        self.db.add(patient)
        await self.db.flush()
        return patient

    async def list_patients(self, search: str | None, page: int, page_size: int) -> dict:
        query = select(Patient).where(Patient.is_deleted.is_(False))
        count_query = select(func.count()).select_from(Patient).where(Patient.is_deleted.is_(False))

        if search:
            filters = or_(
                Patient.name.ilike(f"%{search}%"),
                Patient.patient_uid.ilike(f"%{search}%"),
                Patient.mobile.ilike(f"%{search}%"),
            )
            query = query.where(filters)
            count_query = count_query.where(filters)

        total = (await self.db.execute(count_query)).scalar() or 0
        result = await self.db.execute(
            query.order_by(Patient.name)
            .offset(calculate_offset(page, page_size))
            .limit(page_size)
        )
        return {
            "items": result.scalars().all(),
            "total": total,
            "page": page,
            "page_size": page_size,
        }

    async def get_patient(self, patient_id: uuid.UUID) -> Patient:
        return await self._get_or_404(patient_id)

    async def update_patient(self, patient_id: uuid.UUID, data: PatientUpdate) -> Patient:
        patient = await self._get_or_404(patient_id)
        for field, value in data.model_dump(exclude_unset=True).items():
            setattr(patient, field, value)
        await self.db.flush()
        return patient

    async def soft_delete(self, patient_id: uuid.UUID, reason: str, deleted_by: uuid.UUID) -> None:
        patient = await self._get_or_404(patient_id)
        if patient.is_deleted:
            return
        patient.is_deleted = True
        patient.deleted_at = datetime.now(timezone.utc)
        patient.deletion_reason = reason
        await self.db.flush()

    async def list_patient_visits(self, patient_id: uuid.UUID) -> list[Visit]:
        patient = await self._get_or_404(patient_id)
        result = await self.db.execute(
            select(Visit)
            .options(
                selectinload(Visit.photos),
                selectinload(Visit.treatments).selectinload(VisitTreatment.treatment),
                selectinload(Visit.medications).selectinload(VisitMedication.medication),
                selectinload(Visit.prescription),
            )
            .where(Visit.patient_id == patient.id)
            .order_by(Visit.visit_date.desc(), Visit.created_at.desc())
        )
        return result.scalars().all()

    async def _get_or_404(self, patient_id: uuid.UUID) -> Patient:
        result = await self.db.execute(
            select(Patient).where(Patient.id == patient_id, Patient.is_deleted.is_(False))
        )
        patient = result.scalar_one_or_none()
        if not patient:
            raise HTTPException(status_code=404, detail="Patient not found")
        return patient

