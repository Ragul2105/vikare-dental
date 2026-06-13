from __future__ import annotations

import uuid

from fastapi import HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.medication_master import MedicationMaster
from app.models.treatment_master import TreatmentMaster
from app.schemas.master import (
    MedicationCreate,
    MedicationUpdate,
    TreatmentCreate,
    TreatmentUpdate,
)


class MasterService:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def list_treatments(self) -> dict:
        result = await self.db.execute(
            select(TreatmentMaster)
            .where(TreatmentMaster.is_active.is_(True))
            .order_by(TreatmentMaster.name)
        )
        return {"items": result.scalars().all()}

    async def create_treatment(self, data: TreatmentCreate, created_by: uuid.UUID) -> TreatmentMaster:
        await self._ensure_unique_treatment_name(data.name)
        treatment = TreatmentMaster(created_by=created_by, **data.model_dump())
        self.db.add(treatment)
        await self.db.flush()
        return treatment

    async def update_treatment(self, treatment_id: uuid.UUID, data: TreatmentUpdate) -> TreatmentMaster:
        treatment = await self.db.get(TreatmentMaster, treatment_id)
        if not treatment:
            raise HTTPException(status_code=404, detail="Treatment not found")

        payload = data.model_dump(exclude_unset=True)
        if "name" in payload and payload["name"] != treatment.name:
            await self._ensure_unique_treatment_name(payload["name"])
        for field, value in payload.items():
            setattr(treatment, field, value)
        await self.db.flush()
        return treatment

    async def list_medications(self) -> dict:
        result = await self.db.execute(
            select(MedicationMaster)
            .where(MedicationMaster.is_active.is_(True))
            .order_by(MedicationMaster.name)
        )
        return {"items": result.scalars().all()}

    async def create_medication(
        self,
        data: MedicationCreate,
        created_by: uuid.UUID,
    ) -> MedicationMaster:
        await self._ensure_unique_medication_name(data.name)
        medication = MedicationMaster(created_by=created_by, **data.model_dump())
        self.db.add(medication)
        await self.db.flush()
        return medication

    async def update_medication(
        self,
        medication_id: uuid.UUID,
        data: MedicationUpdate,
    ) -> MedicationMaster:
        medication = await self.db.get(MedicationMaster, medication_id)
        if not medication:
            raise HTTPException(status_code=404, detail="Medication not found")

        payload = data.model_dump(exclude_unset=True)
        if "name" in payload and payload["name"] != medication.name:
            await self._ensure_unique_medication_name(payload["name"])
        for field, value in payload.items():
            setattr(medication, field, value)
        await self.db.flush()
        return medication

    async def _ensure_unique_treatment_name(self, name: str) -> None:
        result = await self.db.execute(
            select(TreatmentMaster).where(TreatmentMaster.name == name)
        )
        if result.scalar_one_or_none():
            raise HTTPException(status_code=409, detail="Treatment already exists")

    async def _ensure_unique_medication_name(self, name: str) -> None:
        result = await self.db.execute(
            select(MedicationMaster).where(MedicationMaster.name == name)
        )
        if result.scalar_one_or_none():
            raise HTTPException(status_code=409, detail="Medication already exists")
