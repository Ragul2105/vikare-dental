from __future__ import annotations

from datetime import datetime, timedelta, timezone

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
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

    async def send_appointment_confirmation(
        self,
        patient: Patient,
        appointment: Appointment,
        db: AsyncSession | None = None,
    ) -> None:
        message = self._build_confirmation_message(patient, appointment)
        await self._send_message(patient.mobile, message)
        await self._log_message(
            patient_id=patient.id,
            appointment_id=appointment.id,
            msg_type="appointment_confirmation",
            status="sent",
            details={"delivery": self._delivery_mode(), "message": message},
            db=db,
        )

    async def send_appointment_reminder(
        self,
        patient: Patient,
        appointment: Appointment,
        reminder_type: str,
    ) -> None:
        message = self._build_reminder_message(patient, appointment, reminder_type)
        await self._send_message(patient.mobile, message)
        await self._log_message(
            patient_id=patient.id,
            appointment_id=appointment.id,
            msg_type=f"reminder_{reminder_type}",
            status="sent",
            details={"delivery": self._delivery_mode(), "message": message},
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
        if self._mock_delivery:
            logger.info("whatsapp_mock_message", mobile=mobile, message=message)
            return
        async with httpx.AsyncClient(timeout=10) as client:
            response = await client.post(
                f"{self.BASE_URL}/api/v1/sendSessionMessage/{mobile}",
                headers=self.HEADERS,
                json={"messageText": message},
            )
            response.raise_for_status()

    async def _send_document(self, mobile: str, url: str, filename: str) -> None:
        if self._mock_delivery:
            logger.info("whatsapp_mock_document", mobile=mobile, url=url, filename=filename)
            return
        async with httpx.AsyncClient(timeout=15) as client:
            response = await client.post(
                f"{self.BASE_URL}/api/v1/sendFile/{mobile}",
                headers=self.HEADERS,
                json={"url": url, "filename": filename},
            )
            response.raise_for_status()

    def _build_confirmation_message(self, patient: Patient, appointment: Appointment) -> str:
        scheduled_at = ensure_india_time(appointment.scheduled_at)
        time_str = scheduled_at.strftime("%I:%M %p")
        date_str = scheduled_at.strftime("%d %b %Y")
        return (
            f"Hello {patient.name},\n"
            f"Your Vikare Dental Clinic appointment has been booked for "
            f"{date_str} at {time_str}.\n"
            "Please arrive 5 minutes early. Reply or call us if you need to reschedule."
        )

    def _build_reminder_message(self, patient: Patient, appointment: Appointment, reminder_type: str) -> str:
        scheduled_at = ensure_india_time(appointment.scheduled_at)
        time_str = scheduled_at.strftime("%I:%M %p")
        date_str = scheduled_at.strftime("%d %b %Y")
        window = "tomorrow" if reminder_type == "24h" else "in 2 hours"
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
        db: AsyncSession | None = None,
    ) -> None:
        message = WhatsAppMessage(
            patient_id=patient_id,
            appointment_id=appointment_id,
            message_type=msg_type,
            status=status,
            details=details,
        )
        if db is not None:
            db.add(message)
            await db.flush()
            return
        async with AsyncSessionLocal() as db:
            db.add(message)
            await db.commit()

    @property
    def _mock_delivery(self) -> bool:
        token = settings.wati_api_token.strip().lower()
        url = settings.wati_api_url.strip().lower()
        return (
            settings.environment.lower() != "production"
            and (token.startswith("dev-") or "dev-account" in url)
        )

    def _delivery_mode(self) -> str:
        return "mock" if self._mock_delivery else "wati"


async def run_reminder_job() -> None:
    async with AsyncSessionLocal() as db:
        now = datetime.now(timezone.utc)
        windows = [
            ("2h", now + timedelta(minutes=110), now + timedelta(minutes=130)),
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
                if not patient:
                    continue
                try:
                    await service.send_appointment_reminder(patient, appointment, reminder_type)
                except Exception as exc:
                    logger.warning(
                        "whatsapp_send_failed",
                        appointment_id=str(appointment.id),
                        error=str(exc),
                    )
