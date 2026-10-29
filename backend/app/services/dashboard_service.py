from __future__ import annotations

from collections import Counter
from datetime import date

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.appointment import Appointment
from app.models.patient import Patient
from app.models.user import User
from app.models.treatment_master import TreatmentMaster
from app.models.visit_treatment import VisitTreatment
from app.services.appointment_service import auto_complete_due_appointments
from app.utils.india_time import ensure_india_time, india_day_bounds, india_today


class DashboardService:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def get_summary(self) -> dict:
        today = india_today()
        await auto_complete_due_appointments(self.db)
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

        month_start = today.replace(day=1)
        month_start_at, _ = india_day_bounds(month_start)
        new_patients = (
            await self.db.execute(
                select(func.count())
                .select_from(Patient)
                .where(
                    Patient.is_deleted.is_(False),
                    Patient.created_at >= month_start_at,
                )
            )
        ).scalar() or 0

        top_treatment_rows = (
            await self.db.execute(
                select(TreatmentMaster.name, func.count(VisitTreatment.id))
                .join(VisitTreatment, VisitTreatment.treatment_id == TreatmentMaster.id)
                .group_by(TreatmentMaster.id, TreatmentMaster.name)
                .order_by(func.count(VisitTreatment.id).desc(), TreatmentMaster.name)
                .limit(5)
            )
        ).all()

        month_starts = self._last_six_months(month_start)
        trend_start, _ = india_day_bounds(month_starts[0])
        trend_appointments = (
            await self.db.execute(
                select(Appointment.scheduled_at).where(
                    Appointment.scheduled_at >= trend_start,
                    Appointment.status != "cancelled",
                )
            )
        ).scalars().all()
        trend_counts = Counter(
            (ensure_india_time(value).year, ensure_india_time(value).month)
            for value in trend_appointments
        )

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
            "completed_today": sum(1 for item in appointments if item.status == "completed"),
            "new_patients_this_month": new_patients,
            "top_treatments": [
                {"name": name, "count": count} for name, count in top_treatment_rows
            ],
            "appointment_trend": [
                {
                    "month": item.strftime("%b"),
                    "count": trend_counts[(item.year, item.month)],
                }
                for item in month_starts
            ],
        }

    @staticmethod
    def _last_six_months(month_start: date) -> list[date]:
        months: list[date] = []
        year, month = month_start.year, month_start.month
        for offset in range(5, -1, -1):
            target_month = month - offset
            target_year = year
            while target_month <= 0:
                target_month += 12
                target_year -= 1
            months.append(date(target_year, target_month, 1))
        return months
