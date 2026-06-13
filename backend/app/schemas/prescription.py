from __future__ import annotations

from datetime import datetime
import uuid

from pydantic import BaseModel, ConfigDict


class PrescriptionResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    visit_id: uuid.UUID
    pdf_url: str
    created_at: datetime

