from __future__ import annotations

from datetime import date, datetime, timedelta
import uuid

from fastapi import HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload
import structlog

from app.models.appointment import Appointment
from app.models.patient import Patient
from app.models.user import User
from app.schemas.appointment import AppointmentCreate, AppointmentUpdate
from app.services.whatsapp_service import WhatsAppService
from app.utils.india_time import (
    ensure_india_time,
    india_date_range_bounds,
    india_day_bounds,
    india_now,
)

logger = structlog.get_logger()

VALID_STATUSES = {"scheduled", "in_progress", "completed", "cancelled", "no_show"}
ALLOWED_TRANSITIONS = {
    "scheduled": {"scheduled", "in_progress", "completed", "cancelled", "no_show"},
    "in_progress": {"in_progress", "completed", "cancelled", "no_show"},
    "completed": {"scheduled", "completed", "cancelled", "no_show"},
    "cancelled": {"cancelled"},
    "no_show": {"no_show"},
}


async def auto_complete_due_appointments(
    db: AsyncSession,
    appointments: list[Appointment] | None = None,
) -> None:
    now = india_now()
    if appointments is None:
        result = await db.execute(
            select(Appointment).where(
                Appointment.status == "scheduled",
                Appointment.scheduled_at < now,
            )
        )
        appointments = list(result.scalars().all())

    changed = False
    for appointment in appointments:
        if appointment.status != "scheduled":
            continue
        ends_at = ensure_india_time(appointment.scheduled_at) + timedelta(
            minutes=appointment.duration_minutes
        )
        if ends_at <= now:
            appointment.status = "completed"
            changed = True

    if changed:
        await db.flush()


class AppointmentService:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def list_appointments(self, target_date: date, range_: str) -> dict:
        day_count = 1 if range_ == "day" else 7
        start_at, end_at = india_date_range_bounds(target_date, day_count)
        result = await self.db.execute(
            select(Appointment)
            .options(
                selectinload(Appointment.patient),
                selectinload(Appointment.assigned_practitioner),
            )
            .where(
                Appointment.scheduled_at >= start_at,
                Appointment.scheduled_at < end_at,
            )
            .order_by(Appointment.scheduled_at)
        )
        appointments = list(result.scalars().all())
        await auto_complete_due_appointments(self.db, appointments)
        return {"items": appointments, "range": range_, "date": target_date}

    async def create_appointment(
        self,
        data: AppointmentCreate,
        created_by: uuid.UUID,
    ) -> Appointment:
        patient = await self._get_patient_or_404(data.patient_id)
        await self._get_practitioner_if_provided(data.assigned_practitioner_id)
        scheduled_at = self._ensure_timezone(data.scheduled_at)
        await self._check_conflict(scheduled_at, data.duration_minutes)

        appointment = Appointment(
            patient_id=patient.id,
            scheduled_at=scheduled_at,
            duration_minutes=data.duration_minutes,
            status="scheduled",
            reason=data.reason,
            notes=data.notes,
            assigned_practitioner_id=data.assigned_practitioner_id,
            created_by=created_by,
        )
        appointment.patient = patient
        self.db.add(appointment)
        await self.db.flush()
        try:
            await WhatsAppService().send_appointment_confirmation(
                patient,
                appointment,
                db=self.db,
            )
        except Exception as exc:  # pragma: no cover - external delivery path
            logger.warning(
                "appointment_confirmation_send_failed",
                appointment_id=str(appointment.id),
                error=str(exc),
            )
        return await self.get_appointment(appointment.id, auto_complete=False)

    async def get_appointment(
        self,
        appointment_id: uuid.UUID,
        *,
        auto_complete: bool = True,
    ) -> Appointment:
        result = await self.db.execute(
            select(Appointment)
            .options(
                selectinload(Appointment.patient),
                selectinload(Appointment.assigned_practitioner),
            )
            .where(Appointment.id == appointment_id)
        )
        appointment = result.scalar_one_or_none()
        if not appointment:
            raise HTTPException(status_code=404, detail="Appointment not found")
        if auto_complete:
            await auto_complete_due_appointments(self.db, [appointment])
        return appointment

    async def update_appointment(
        self,
        appointment_id: uuid.UUID,
        data: AppointmentUpdate,
    ) -> Appointment:
        appointment = await self.get_appointment(appointment_id)
        payload = data.model_dump(exclude_unset=True)

        new_scheduled_at = self._ensure_timezone(
            payload.get("scheduled_at", appointment.scheduled_at)
        )
        new_duration = payload.get("duration_minutes", appointment.duration_minutes)

        if (
            new_scheduled_at != self._ensure_timezone(appointment.scheduled_at)
            or new_duration != appointment.duration_minutes
        ):
            await self._check_conflict(new_scheduled_at, new_duration, exclude_id=appointment.id)

        if (
            "scheduled_at" in payload
            and payload["scheduled_at"] is not None
            and "status" not in payload
            and appointment.status in {"completed", "cancelled", "no_show"}
        ):
            payload["status"] = "scheduled"

        if "status" in payload:
            self._validate_transition(appointment.status, payload["status"])
        if "assigned_practitioner_id" in payload:
            await self._get_practitioner_if_provided(payload["assigned_practitioner_id"])

        for field, value in payload.items():
            if field == "scheduled_at" and value is not None:
                value = self._ensure_timezone(value)
            setattr(appointment, field, value)

        await self.db.flush()
        return await self.get_appointment(appointment.id)

    async def cancel_appointment(self, appointment_id: uuid.UUID, reason: str | None = None) -> None:
        appointment = await self.get_appointment(appointment_id)
        self._validate_transition(appointment.status, "cancelled")
        appointment.status = "cancelled"
        if reason:
            appointment.notes = f"{appointment.notes}\nCancelled: {reason}".strip() if appointment.notes else f"Cancelled: {reason}"
        await self.db.flush()

    async def _check_conflict(
        self,
        scheduled_at: datetime,
        duration_minutes: int,
        exclude_id: uuid.UUID | None = None,
    ) -> None:
        end_time = scheduled_at + timedelta(minutes=duration_minutes)
        day_start, day_end = india_day_bounds(scheduled_at.date())
        result = await self.db.execute(
            select(Appointment).where(
                Appointment.scheduled_at >= day_start,
                Appointment.scheduled_at < day_end,
                Appointment.status.not_in(["cancelled", "no_show"]),
            )
        )
        for existing in result.scalars().all():
            if exclude_id and existing.id == exclude_id:
                continue
            existing_start = self._ensure_timezone(existing.scheduled_at)
            existing_end = existing_start + timedelta(minutes=existing.duration_minutes)
            if existing_start < end_time and existing_end > scheduled_at:
                raise HTTPException(
                    status_code=409,
                    detail={
                        "error_code": "APPOINTMENT_CONFLICT",
                        "message": "This time slot overlaps with an existing appointment",
                        "conflicting_appointment_id": str(existing.id),
                    },
                )

    async def _get_patient_or_404(self, patient_id: uuid.UUID) -> Patient:
        patient = await self.db.get(Patient, patient_id)
        if not patient or patient.is_deleted:
            raise HTTPException(status_code=404, detail="Patient not found")
        return patient

    async def _get_practitioner_if_provided(
        self, practitioner_id: uuid.UUID | None
    ) -> User | None:
        if practitioner_id is None:
            return None
        practitioner = await self.db.get(User, practitioner_id)
        if not practitioner or not practitioner.is_active:
            raise HTTPException(status_code=404, detail="Practitioner not found")
        return practitioner

    def _ensure_timezone(self, value: datetime) -> datetime:
        return ensure_india_time(value)

    def _validate_transition(self, current: str, new: str) -> None:
        if new not in VALID_STATUSES:
            raise HTTPException(status_code=422, detail="Invalid appointment status")
        if new not in ALLOWED_TRANSITIONS.get(current, {current}):
            raise HTTPException(
                status_code=422,
                detail=f"Invalid status transition: {current} -> {new}",
            )
