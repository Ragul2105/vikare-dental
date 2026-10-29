from __future__ import annotations

from datetime import date, datetime
import uuid

from pydantic import BaseModel, ConfigDict, Field


class VisitPhotoResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    photo_url: str
    caption: str | None
    uploaded_by: uuid.UUID
    uploaded_at: datetime


class VisitMedicationItem(BaseModel):
    medication_id: uuid.UUID
    dosage: str = Field(..., min_length=1, max_length=100)
    quantity: int = Field(..., ge=1)


class VisitCreate(BaseModel):
    patient_id: uuid.UUID
    appointment_id: uuid.UUID | None = None
    visit_date: date
    notes: str | None = None
    diagnosis: str | None = None
    treatment_ids: list[uuid.UUID] = Field(default_factory=list)
    medication_items: list[VisitMedicationItem] = Field(default_factory=list)
    follow_up_required: bool = False
    follow_up_date: date | None = None
    follow_up_notes: str | None = None


class VisitUpdate(BaseModel):
    notes: str | None = None
    diagnosis: str | None = None
    treatment_ids: list[uuid.UUID] | None = None
    medication_items: list[VisitMedicationItem] | None = None
    follow_up_required: bool | None = None
    follow_up_date: date | None = None
    follow_up_notes: str | None = None


class VisitTreatmentResponse(BaseModel):
    id: uuid.UUID
    treatment_id: uuid.UUID
    treatment_name: str
    notes: str | None = None


class VisitMedicationResponse(BaseModel):
    id: uuid.UUID
    medication_id: uuid.UUID
    medication_name: str
    dosage: str
    quantity: int


class VisitResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    patient_id: uuid.UUID
    appointment_id: uuid.UUID | None
    visit_date: date
    notes: str | None
    diagnosis: str | None
    follow_up_required: bool
    follow_up_date: date | None
    follow_up_notes: str | None
    photos: list[VisitPhotoResponse] = Field(default_factory=list)
    treatments: list[VisitTreatmentResponse] = Field(default_factory=list)
    medications: list[VisitMedicationResponse] = Field(default_factory=list)
    created_by: uuid.UUID
    created_at: datetime
    updated_at: datetime
