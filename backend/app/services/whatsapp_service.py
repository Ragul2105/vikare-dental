from __future__ import annotations

from datetime import datetime, timedelta, timezone

from sqlalchemy import select
from sqlalchemy.orm import selectinload
import httpx
import structlog

from app.config import get_settings
from app.database import AsyncSessionLocal
from app.models.appointment import Appointment
from app.models.patient import Patient
from app.models.whatsapp_message import WhatsAppMessage
from app.utils.india_time import ensure_india_time

settings = get_settings()
logger = structlog.get_logger()


class WhatsAppService:
    BASE_URL = settings.wati_api_url
    HEADERS = {"Authorization": f"Bearer {settings.wati_api_token}"}

    async def send_appointment_reminder(self, patient: Patient, appointment: Appointment, reminder_type: str) -> None:
        message = self._build_reminder_message(patient, appointment, reminder_type)
        await self._send_message(patient.mobile, message)
        await self._log_message(
            patient_id=patient.id,
            appointment_id=appointment.id,
            msg_type=f"reminder_{reminder_type}",
            status="sent",
        )

    async def send_prescription_pdf(self, patient: Patient, pdf_url: str) -> None:
        await self._send_document(patient.mobile, pdf_url, filename="prescription.pdf")
        await self._log_message(
            patient_id=patient.id,
            appointment_id=None,
            msg_type="prescription",
            status="sent",
        )

    async def _send_message(self, mobile: str, message: str) -> None:
        async with httpx.AsyncClient(timeout=10) as client:
            response = await client.post(
                f"{self.BASE_URL}/api/v1/sendSessionMessage/{mobile}",
                headers=self.HEADERS,
                json={"messageText": message},
            )
            response.raise_for_status()

    async def _send_document(self, mobile: str, url: str, filename: str) -> None:
        async with httpx.AsyncClient(timeout=15) as client:
            response = await client.post(
                f"{self.BASE_URL}/api/v1/sendFile/{mobile}",
                headers=self.HEADERS,
                json={"url": url, "filename": filename},
            )
            response.raise_for_status()

    def _build_reminder_message(self, patient: Patient, appointment: Appointment, reminder_type: str) -> str:
        scheduled_at = ensure_india_time(appointment.scheduled_at)
        time_str = scheduled_at.strftime("%I:%M %p")
        date_str = scheduled_at.strftime("%d %b %Y")
        window = "tomorrow" if reminder_type == "24h" else "in 1 hour"
        return (
            f"Hello {patient.name},\n"
            f"This is a reminder for your dental appointment {window} "
            f"on {date_str} at {time_str}.\n"
            "Please arrive 5 minutes early. Call us if you need to reschedule."
        )

    async def _log_message(
        self,
        patient_id,
        appointment_id,
        msg_type: str,
        status: str,
        details: dict | None = None,
    ) -> None:
        async with AsyncSessionLocal() as db:
            db.add(
                WhatsAppMessage(
                    patient_id=patient_id,
                    appointment_id=appointment_id,
                    message_type=msg_type,
                    status=status,
                    details=details,
                )
            )
            await db.commit()


async def run_reminder_job() -> None:
    async with AsyncSessionLocal() as db:
        now = datetime.now(timezone.utc)
        windows = [
            ("24h", now + timedelta(hours=23), now + timedelta(hours=25)),
            ("1h", now + timedelta(minutes=50), now + timedelta(minutes=70)),
        ]
        service = WhatsAppService()

        for reminder_type, window_start, window_end in windows:
            query = (
                select(Appointment)
                .options(selectinload(Appointment.patient))
                .where(
                    Appointment.scheduled_at.between(window_start, window_end),
                    Appointment.status == "scheduled",
                )
            )
            appointments = (await db.execute(query)).scalars().all()
            sent_query = await db.execute(
                select(WhatsAppMessage.appointment_id).where(
                    WhatsAppMessage.message_type == f"reminder_{reminder_type}",
                    WhatsAppMessage.status == "sent",
                )
            )
            sent_ids = {row for row in sent_query.scalars().all() if row is not None}

            for appointment in appointments:
                if appointment.id in sent_ids:
                    continue
                patient = appointment.patient
                if not patient or not patient.whatsapp_enabled:
                    continue
                try:
                    await service.send_appointment_reminder(patient, appointment, reminder_type)
                except Exception as exc:
                    logger.warning(
                        "whatsapp_send_failed",
                        appointment_id=str(appointment.id),
                        error=str(exc),
                    )
