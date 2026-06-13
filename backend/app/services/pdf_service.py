from __future__ import annotations

from datetime import datetime, timezone
from pathlib import Path
import uuid

from fastapi import HTTPException
from jinja2 import Environment, FileSystemLoader
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload
from weasyprint import HTML

from app.models.prescription import Prescription
from app.models.visit import Visit
from app.models.visit_medication import VisitMedication
from app.models.visit_treatment import VisitTreatment
from app.services.s3_service import S3Service


class PDFService:
    def __init__(self, db: AsyncSession):
        self.db = db
        self.s3 = S3Service()
        template_dir = Path(__file__).resolve().parent.parent / "templates"
        self.jinja_env = Environment(loader=FileSystemLoader(str(template_dir)), autoescape=True)

    async def generate_prescription(self, visit_id: uuid.UUID) -> Prescription:
        existing = await self._get_existing_prescription(visit_id)
        if existing:
            existing.pdf_url = await self.s3.get_presigned_url(existing.s3_key)
            return existing

        visit = await self._get_visit_with_relations(visit_id)
        html_content = self._render_template(visit)
        try:
            pdf_bytes = HTML(string=html_content).write_pdf()
        except Exception as exc:
            raise HTTPException(status_code=500, detail=f"Failed to generate PDF: {exc}") from exc

        s3_key = (
            f"prescriptions/{visit.visit_date.year}/{visit.visit_date.month:02d}/"
            f"{visit.patient_id}/{visit_id}.pdf"
        )
        await self.s3.upload_bytes(s3_key, pdf_bytes, content_type="application/pdf")
        pdf_url = await self.s3.get_presigned_url(s3_key)
        prescription = Prescription(visit_id=visit_id, s3_key=s3_key, pdf_url=pdf_url)
        self.db.add(prescription)
        await self.db.flush()
        return prescription

    async def get_prescription(self, visit_id: uuid.UUID) -> Prescription:
        prescription = await self._get_existing_prescription(visit_id)
        if not prescription:
            raise HTTPException(status_code=404, detail="Prescription not found")

        prescription.pdf_url = await self.s3.get_presigned_url(prescription.s3_key)
        return prescription

    async def _get_existing_prescription(self, visit_id: uuid.UUID) -> Prescription | None:
        result = await self.db.execute(
            select(Prescription).where(Prescription.visit_id == visit_id)
        )
        return result.scalar_one_or_none()

    async def _get_visit_with_relations(self, visit_id: uuid.UUID) -> Visit:
        result = await self.db.execute(
            select(Visit)
            .options(
                selectinload(Visit.patient),
                selectinload(Visit.treatments).selectinload(VisitTreatment.treatment),
                selectinload(Visit.medications).selectinload(VisitMedication.medication),
            )
            .where(Visit.id == visit_id)
        )
        visit = result.scalar_one_or_none()
        if not visit:
            raise HTTPException(status_code=404, detail="Visit not found")
        return visit

    def _render_template(self, visit: Visit) -> str:
        template = self.jinja_env.get_template("prescription.html")
        return template.render(visit=visit, patient=visit.patient, generated_at=datetime.now(timezone.utc))

