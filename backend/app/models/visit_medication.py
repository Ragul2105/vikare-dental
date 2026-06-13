from __future__ import annotations

import uuid
from typing import TYPE_CHECKING

from sqlalchemy import ForeignKey, Integer, String
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base

if TYPE_CHECKING:
    from app.models.medication_master import MedicationMaster
    from app.models.visit import Visit


class VisitMedication(Base):
    __tablename__ = "visit_medications"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    visit_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("visits.id"),
        nullable=False,
        index=True,
    )
    medication_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("medication_masters.id"),
        nullable=False,
        index=True,
    )
    dosage: Mapped[str] = mapped_column(String(100), nullable=False)
    quantity: Mapped[int] = mapped_column(Integer, nullable=False)

    visit: Mapped["Visit"] = relationship("Visit", back_populates="medications")
    medication: Mapped["MedicationMaster"] = relationship(
        "MedicationMaster",
        back_populates="visit_medications",
    )

    @property
    def medication_name(self) -> str:
        medication = self.__dict__.get("medication")
        return medication.name if medication else ""
