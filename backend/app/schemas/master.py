from __future__ import annotations

from datetime import datetime
import uuid

from pydantic import BaseModel, ConfigDict, Field


class TreatmentCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=150)
    description: str | None = None
    is_active: bool = True


class TreatmentUpdate(BaseModel):
    name: str | None = Field(None, min_length=1, max_length=150)
    description: str | None = None
    is_active: bool | None = None


class TreatmentResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    name: str
    description: str | None
    is_active: bool
    created_at: datetime
    updated_at: datetime


class TreatmentListResponse(BaseModel):
    items: list[TreatmentResponse]


class MedicationCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=150)
    description: str | None = None
    default_dosage: str | None = Field(None, max_length=100)
    is_active: bool = True


class MedicationUpdate(BaseModel):
    name: str | None = Field(None, min_length=1, max_length=150)
    description: str | None = None
    default_dosage: str | None = Field(None, max_length=100)
    is_active: bool | None = None


class MedicationResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    name: str
    description: str | None
    default_dosage: str | None
    is_active: bool
    created_at: datetime
    updated_at: datetime


class MedicationListResponse(BaseModel):
    items: list[MedicationResponse]

