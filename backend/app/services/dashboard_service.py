from __future__ import annotations

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.appointment import Appointment
from app.models.patient import Patient
from app.models.user import User
from app.utils.india_time import ensure_india_time, india_day_bounds, india_today


class DashboardService:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def get_summary(self) -> dict:
        today = india_today()
        start_at, end_at = india_day_bounds(today)
        appointments = (
            await self.db.execute(
                select(Appointment)
                .options(selectinload(Appointment.patient))
                .where(
                    Appointment.scheduled_at >= start_at,
                    Appointment.scheduled_at < end_at,
                    Appointment.status != "cancelled",
                )
                .order_by(Appointment.scheduled_at)
            )
        ).scalars().all()

        patient_count = (
            await self.db.execute(
                select(func.count()).select_from(Patient).where(Patient.is_deleted.is_(False))
            )
        ).scalar() or 0
        staff_count = (
            await self.db.execute(
                select(func.count()).select_from(User).where(User.is_active.is_(True))
            )
        ).scalar() or 0

        return {
            "today": today,
            "appointments_today": len(appointments),
            "appointments": [
                {
                    "id": appointment.id,
                    "patient_id": appointment.patient_id,
                    "patient_name": appointment.patient.name if appointment.patient else "Unknown",
                    "scheduled_at": ensure_india_time(appointment.scheduled_at),
                    "duration_minutes": appointment.duration_minutes,
                    "status": appointment.status,
                    "reason": appointment.reason,
                }
                for appointment in appointments
            ],
            "total_patients": patient_count,
            "total_staff": staff_count,
        }
