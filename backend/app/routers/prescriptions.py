import uuid

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.dependencies import get_current_user, get_db
from app.schemas.prescription import PrescriptionResponse
from app.services.pdf_service import PDFService

router = APIRouter(prefix="/visits", tags=["Prescriptions"])


@router.post("/{visit_id}/prescription", response_model=PrescriptionResponse, status_code=201)
async def create_prescription(
    visit_id: uuid.UUID,
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    return await PDFService(db).generate_prescription(visit_id)


@router.get("/{visit_id}/prescription", response_model=PrescriptionResponse)
async def get_prescription(
    visit_id: uuid.UUID,
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    return await PDFService(db).get_prescription(visit_id)
