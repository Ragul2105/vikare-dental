from __future__ import annotations

from datetime import date, datetime
import uuid
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, field_serializer

from app.utils.india_time import ensure_india_time


class AppointmentCreate(BaseModel):
    patient_id: uuid.UUID
    scheduled_at: datetime
    duration_minutes: int = Field(..., ge=5, le=480)
    reason: str | None = Field(None, max_length=500)
    notes: str | None = Field(None, max_length=2000)
    assigned_practitioner_id: uuid.UUID | None = None


class AppointmentUpdate(BaseModel):
    scheduled_at: datetime | None = None
    duration_minutes: int | None = Field(None, ge=5, le=480)
    status: Literal["scheduled", "in_progress", "completed", "cancelled", "no_show"] | None = None
    reason: str | None = Field(None, max_length=500)
    notes: str | None = Field(None, max_length=2000)
    assigned_practitioner_id: uuid.UUID | None = None


class AppointmentResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    patient_id: uuid.UUID
    patient_name: str | None = None
    scheduled_at: datetime
    duration_minutes: int
    status: str
    reason: str | None
    notes: str | None
    assigned_practitioner_id: uuid.UUID | None
    practitioner_name: str | None = None
    created_by: uuid.UUID
    created_at: datetime
    updated_at: datetime

    @field_serializer("scheduled_at")
    def serialize_scheduled_at(self, value: datetime) -> str:
        return ensure_india_time(value).isoformat()


class AppointmentListResponse(BaseModel):
    items: list[AppointmentResponse]
    range: Literal["day", "week"]
    date: date
