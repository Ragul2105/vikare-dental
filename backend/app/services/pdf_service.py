from __future__ import annotations

from datetime import datetime, timezone
from io import BytesIO
from pathlib import Path
import uuid

from fastapi import HTTPException
from jinja2 import Environment, FileSystemLoader
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

try:
    from weasyprint import HTML
except Exception:  # pragma: no cover - depends on host native libraries
    HTML = None

try:
    from reportlab.lib import colors
    from reportlab.lib.pagesizes import A4
    from reportlab.lib.styles import getSampleStyleSheet
    from reportlab.platypus import Paragraph, SimpleDocTemplate, Spacer, Table, TableStyle
except Exception:  # pragma: no cover - optional fallback dependency
    SimpleDocTemplate = None

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

        if HTML is None and SimpleDocTemplate is None:
            raise HTTPException(
                status_code=503,
                detail=(
                    "Prescription PDF generation is unavailable because neither WeasyPrint "
                    "nor the ReportLab fallback is available on this machine."
                ),
            )

        try:
            if HTML is not None:
                html_content = self._render_template(visit)
                pdf_bytes = HTML(string=html_content).write_pdf()
            else:
                pdf_bytes = self._render_reportlab_pdf(visit)
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

    def _render_reportlab_pdf(self, visit: Visit) -> bytes:
        if SimpleDocTemplate is None:
            raise RuntimeError("ReportLab is not available")

        buffer = BytesIO()
        document = SimpleDocTemplate(buffer, pagesize=A4, title="Vikare Dental Visit Record")
        styles = getSampleStyleSheet()
        story = [
            Paragraph("Vikare Dental Clinic Visit Record", styles["Title"]),
            Paragraph(
                f"Generated at {datetime.now(timezone.utc).strftime('%d %b %Y %I:%M %p UTC')}",
                styles["Normal"],
            ),
            Spacer(1, 16),
        ]

        patient = visit.patient
        patient_rows = [
            ["Name", patient.name],
            ["Patient ID", patient.patient_uid],
            ["Mobile", patient.mobile],
            ["Age / Gender", f"{patient.age or 'N/A'} / {patient.gender or 'N/A'}"],
            ["Blood Type", patient.blood_type or "N/A"],
            ["Allergies", patient.allergies or "N/A"],
            ["Medical History", patient.medical_history or "N/A"],
            ["Current Medications", patient.current_medications or "N/A"],
            ["Past Dental History", patient.past_dental_history or "N/A"],
        ]
        story.extend(self._table_section("Patient", patient_rows, styles))

        visit_rows = [
            ["Visit Date", visit.visit_date.strftime("%d %b %Y")],
            ["Diagnosis", visit.diagnosis or "N/A"],
            ["Notes", visit.notes or "N/A"],
        ]
        if visit.follow_up_required:
            visit_rows.extend(
                [
                    [
                        "Follow-up Date",
                        visit.follow_up_date.strftime("%d %b %Y")
                        if visit.follow_up_date
                        else "Date pending",
                    ],
                    ["Follow-up Notes", visit.follow_up_notes or "N/A"],
                ]
            )
        story.extend(self._table_section("Visit", visit_rows, styles))

        treatments = [
            ["Treatment", treatment.treatment.name]
            for treatment in visit.treatments
            if treatment.treatment
        ] or [["Treatment", "No treatments recorded"]]
        story.extend(self._table_section("Treatments", treatments, styles))

        medications = [
            [
                medication.medication.name if medication.medication else "Medication",
                medication.dosage,
                str(medication.quantity),
            ]
            for medication in visit.medications
        ] or [["Medication", "No medications prescribed", ""]]
        story.append(Paragraph("Medications", styles["Heading2"]))
        story.append(
            Table(
                [["Medication", "Dosage", "Quantity"], *medications],
                colWidths=[180, 220, 80],
            )
        )

        document.build(story)
        return buffer.getvalue()

    def _table_section(self, title: str, rows: list[list[str]], styles) -> list:
        table = Table(rows, colWidths=[150, 330])
        table.setStyle(
            TableStyle(
                [
                    ("GRID", (0, 0), (-1, -1), 0.5, colors.HexColor("#DDE5EF")),
                    ("BACKGROUND", (0, 0), (0, -1), colors.HexColor("#EAF5FD")),
                    ("TEXTCOLOR", (0, 0), (0, -1), colors.HexColor("#287FB7")),
                    ("VALIGN", (0, 0), (-1, -1), "TOP"),
                    ("LEFTPADDING", (0, 0), (-1, -1), 8),
                    ("RIGHTPADDING", (0, 0), (-1, -1), 8),
                    ("TOPPADDING", (0, 0), (-1, -1), 7),
                    ("BOTTOMPADDING", (0, 0), (-1, -1), 7),
                ]
            )
        )
        return [Paragraph(title, styles["Heading2"]), table, Spacer(1, 14)]
