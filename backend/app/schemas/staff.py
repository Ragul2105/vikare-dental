from __future__ import annotations

from datetime import datetime
import uuid
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field


class StaffCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=100)
    role: Literal["admin", "staff"]
    pin: str = Field(..., min_length=4, max_length=4, pattern=r"^\d{4}$")
    email: str | None = Field(None, max_length=255)
    mobile: str | None = Field(None, pattern=r"^\+?[0-9]{10,15}$")
    job_title: str | None = Field(None, max_length=100)
    schedule: str | None = Field(None, max_length=150)


class StaffUpdate(BaseModel):
    name: str | None = Field(None, min_length=1, max_length=100)
    role: Literal["admin", "staff"] | None = None
    is_active: bool | None = None
    email: str | None = Field(None, max_length=255)
    mobile: str | None = Field(None, pattern=r"^\+?[0-9]{10,15}$")
    job_title: str | None = Field(None, max_length=100)
    schedule: str | None = Field(None, max_length=150)


class PinResetRequest(BaseModel):
    new_pin: str = Field(..., min_length=4, max_length=4, pattern=r"^\d{4}$")


class StaffResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    name: str
    role: str
    email: str | None
    mobile: str | None
    job_title: str | None
    schedule: str | None
    is_active: bool
    last_login_at: datetime | None
    created_at: datetime
    updated_at: datetime


class StaffListResponse(BaseModel):
    items: list[StaffResponse]


class ActivityLogResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    user_id: uuid.UUID | None
    action: str
    entity_type: str
    entity_id: str | None
    details: dict | None
    created_at: datetime


class ActivityLogListResponse(BaseModel):
    items: list[ActivityLogResponse]
    total: int
    page: int
    page_size: int
