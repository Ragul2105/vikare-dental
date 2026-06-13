from __future__ import annotations

import uuid
from typing import TYPE_CHECKING

from sqlalchemy import ForeignKey, Text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base

if TYPE_CHECKING:
    from app.models.treatment_master import TreatmentMaster
    from app.models.visit import Visit


class VisitTreatment(Base):
    __tablename__ = "visit_treatments"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    visit_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("visits.id"),
        nullable=False,
        index=True,
    )
    treatment_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("treatment_masters.id"),
        nullable=False,
        index=True,
    )
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)

    visit: Mapped["Visit"] = relationship("Visit", back_populates="treatments")
    treatment: Mapped["TreatmentMaster"] = relationship("TreatmentMaster", back_populates="visit_treatments")

    @property
    def treatment_name(self) -> str:
        treatment = self.__dict__.get("treatment")
        return treatment.name if treatment else ""
