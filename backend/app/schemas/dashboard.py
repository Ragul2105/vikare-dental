from __future__ import annotations

from datetime import date, datetime
import uuid

from pydantic import BaseModel, field_serializer

from app.utils.india_time import ensure_india_time


class DashboardAppointmentItem(BaseModel):
    id: uuid.UUID
    patient_id: uuid.UUID
    patient_name: str
    scheduled_at: datetime
    duration_minutes: int
    status: str
    reason: str | None = None

    @field_serializer("scheduled_at")
    def serialize_scheduled_at(self, value: datetime) -> str:
        return ensure_india_time(value).isoformat()


class DashboardSummaryResponse(BaseModel):
    today: date
    appointments_today: int
    appointments: list[DashboardAppointmentItem]
    total_patients: int
    total_staff: int
