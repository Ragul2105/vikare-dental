from __future__ import annotations

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.patient import Patient


async def generate_patient_uid(db: AsyncSession) -> str:
    result = await db.execute(select(func.count()).select_from(Patient))
    count = result.scalar() or 0
    return f"PAT-{(count + 1):06d}"

