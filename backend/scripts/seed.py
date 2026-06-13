from __future__ import annotations

import asyncio
from pathlib import Path
import sys

from sqlalchemy import select

sys.path.append(str(Path(__file__).resolve().parents[1]))

from app.database import AsyncSessionLocal
from app.models.medication_master import MedicationMaster
from app.models.treatment_master import TreatmentMaster
from app.models.user import User
from app.utils.security import hash_pin


async def seed() -> None:
    async with AsyncSessionLocal() as db:
        existing_users = (await db.execute(select(User))).scalars().all()
        if not existing_users:
            db.add_all(
                [
                    User(name="Dr. Admin", role="admin", pin_hash=hash_pin("1234"), is_active=True),
                    User(name="Front Desk", role="staff", pin_hash=hash_pin("5678"), is_active=True),
                ]
            )

        existing_treatments = (await db.execute(select(TreatmentMaster))).scalars().all()
        if not existing_treatments:
            db.add_all(
                [
                    TreatmentMaster(name="Scaling", description="Dental scaling"),
                    TreatmentMaster(name="Root Canal", description="Root canal treatment"),
                    TreatmentMaster(name="Filling", description="Dental filling"),
                ]
            )

        existing_medications = (await db.execute(select(MedicationMaster))).scalars().all()
        if not existing_medications:
            db.add_all(
                [
                    MedicationMaster(name="Amoxicillin", default_dosage="500mg"),
                    MedicationMaster(name="Ibuprofen", default_dosage="400mg"),
                    MedicationMaster(name="Paracetamol", default_dosage="650mg"),
                ]
            )

        await db.commit()


if __name__ == "__main__":
    asyncio.run(seed())
