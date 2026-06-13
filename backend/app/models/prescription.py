from __future__ import annotations

import uuid

from sqlalchemy import ForeignKey, String
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base
from app.models.mixins import TimestampMixin


class Prescription(Base, TimestampMixin):
    __tablename__ = "prescriptions"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    visit_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("visits.id"),
        nullable=False,
        unique=True,
        index=True,
    )
    s3_key: Mapped[str] = mapped_column(String(500), nullable=False)
    pdf_url: Mapped[str] = mapped_column(String(1000), nullable=False)

    visit: Mapped["Visit"] = relationship("Visit", back_populates="prescription")

