from __future__ import annotations

from datetime import date
import uuid

from sqlalchemy import Date, ForeignKey, Text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base
from app.models.mixins import TimestampMixin


class Visit(Base, TimestampMixin):
    __tablename__ = "visits"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    patient_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("patients.id"),
        nullable=False,
        index=True,
    )
    appointment_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("appointments.id"),
        nullable=True,
    )
    visit_date: Mapped[date] = mapped_column(Date, nullable=False, index=True)
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    diagnosis: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_by: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id"),
        nullable=False,
    )

    patient: Mapped["Patient"] = relationship("Patient", back_populates="visits")
    appointment: Mapped["Appointment | None"] = relationship("Appointment", back_populates="visit")
    treatments: Mapped[list["VisitTreatment"]] = relationship(
        "VisitTreatment",
        back_populates="visit",
        cascade="all, delete-orphan",
    )
    medications: Mapped[list["VisitMedication"]] = relationship(
        "VisitMedication",
        back_populates="visit",
        cascade="all, delete-orphan",
    )
    photos: Mapped[list["VisitPhoto"]] = relationship(
        "VisitPhoto",
        back_populates="visit",
        cascade="all, delete-orphan",
        order_by="VisitPhoto.uploaded_at",
    )
    prescription: Mapped["Prescription | None"] = relationship(
        "Prescription",
        back_populates="visit",
        uselist=False,
        cascade="all, delete-orphan",
    )

