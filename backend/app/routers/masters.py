import uuid

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.dependencies import get_current_user, get_db, require_admin
from app.schemas.master import (
    MedicationCreate,
    MedicationListResponse,
    MedicationResponse,
    MedicationUpdate,
    TreatmentCreate,
    TreatmentListResponse,
    TreatmentResponse,
    TreatmentUpdate,
)
from app.services.master_service import MasterService

router = APIRouter(tags=["Masters"])


@router.get("/treatments", response_model=TreatmentListResponse)
async def list_treatments(
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    return await MasterService(db).list_treatments()


@router.post("/treatments", response_model=TreatmentResponse, status_code=201)
async def create_treatment(
    body: TreatmentCreate,
    current_user=Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    return await MasterService(db).create_treatment(body, created_by=current_user.id)


@router.patch("/treatments/{treatment_id}", response_model=TreatmentResponse)
async def update_treatment(
    treatment_id: uuid.UUID,
    body: TreatmentUpdate,
    current_user=Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    return await MasterService(db).update_treatment(treatment_id, body)


@router.get("/medications", response_model=MedicationListResponse)
async def list_medications(
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    return await MasterService(db).list_medications()


@router.post("/medications", response_model=MedicationResponse, status_code=201)
async def create_medication(
    body: MedicationCreate,
    current_user=Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    return await MasterService(db).create_medication(body, created_by=current_user.id)


@router.patch("/medications/{medication_id}", response_model=MedicationResponse)
async def update_medication(
    medication_id: uuid.UUID,
    body: MedicationUpdate,
    current_user=Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    return await MasterService(db).update_medication(medication_id, body)
