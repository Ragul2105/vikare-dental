from __future__ import annotations

from datetime import datetime
import uuid

from pydantic import BaseModel, ConfigDict, Field


class PatientCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=150)
    mobile: str = Field(..., pattern=r"^\+?[0-9]{10,15}$")
    age: int | None = Field(None, ge=1, le=120)
    gender: str | None = Field(None, pattern=r"^(Male|Female|Other)$")
    address: str | None = None
    medical_history: str | None = None
    allergies: str | None = None
    whatsapp_enabled: bool = True


class PatientUpdate(BaseModel):
    name: str | None = Field(None, min_length=1, max_length=150)
    mobile: str | None = Field(None, pattern=r"^\+?[0-9]{10,15}$")
    age: int | None = Field(None, ge=1, le=120)
    gender: str | None = Field(None, pattern=r"^(Male|Female|Other)$")
    address: str | None = None
    medical_history: str | None = None
    allergies: str | None = None
    whatsapp_enabled: bool | None = None


class PatientResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    patient_uid: str
    name: str
    mobile: str
    age: int | None
    gender: str | None
    address: str | None
    medical_history: str | None
    allergies: str | None
    whatsapp_enabled: bool
    is_deleted: bool
    created_at: datetime
    updated_at: datetime


class PatientListResponse(BaseModel):
    items: list[PatientResponse]
    total: int
    page: int
    page_size: int

