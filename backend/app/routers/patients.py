import uuid

from fastapi import APIRouter, Depends, Query, Request
from sqlalchemy.ext.asyncio import AsyncSession

from app.dependencies import get_current_user, get_db, require_admin
from app.main import limiter
from app.schemas.common import SuccessResponse
from app.schemas.patient import PatientCreate, PatientListResponse, PatientResponse, PatientUpdate
from app.schemas.visit import VisitResponse
from app.services.patient_service import PatientService

router = APIRouter(prefix="/patients", tags=["Patients"])


@router.get("", response_model=PatientListResponse)
@limiter.limit("100/minute")
async def list_patients(
    request: Request,
    search: str | None = Query(None, max_length=100),
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    return await PatientService(db).list_patients(search=search, page=page, page_size=page_size)


@router.post("", response_model=PatientResponse, status_code=201)
@limiter.limit("60/minute")
async def create_patient(
    request: Request,
    body: PatientCreate,
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    return await PatientService(db).create_patient(body, created_by=current_user.id)


@router.get("/{patient_id}/visits", response_model=list[VisitResponse])
async def list_patient_visits(
    patient_id: uuid.UUID,
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    return await PatientService(db).list_patient_visits(patient_id)


@router.get("/{patient_id}", response_model=PatientResponse)
async def get_patient(
    patient_id: uuid.UUID,
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    return await PatientService(db).get_patient(patient_id)


@router.patch("/{patient_id}", response_model=PatientResponse)
async def update_patient(
    patient_id: uuid.UUID,
    body: PatientUpdate,
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    return await PatientService(db).update_patient(patient_id, body)


@router.delete("/{patient_id}", response_model=SuccessResponse)
async def delete_patient(
    patient_id: uuid.UUID,
    reason: str = Query(..., min_length=5, max_length=500),
    current_user=Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    await PatientService(db).soft_delete(patient_id, reason=reason, deleted_by=current_user.id)
    return {"message": "Patient deleted successfully"}
