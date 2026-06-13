import uuid

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.dependencies import get_db, require_admin
from app.schemas.common import SuccessResponse
from app.schemas.staff import (
    ActivityLogListResponse,
    PinResetRequest,
    StaffCreate,
    StaffListResponse,
    StaffResponse,
    StaffUpdate,
)
from app.services.staff_service import StaffService

router = APIRouter(tags=["Staff"])


@router.get("/staff", response_model=StaffListResponse)
async def list_staff(current_user=Depends(require_admin), db: AsyncSession = Depends(get_db)):
    return await StaffService(db).list_staff()


@router.post("/staff", response_model=StaffResponse, status_code=201)
async def create_staff(
    body: StaffCreate,
    current_user=Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    return await StaffService(db).create_staff(body)


@router.patch("/staff/{staff_id}", response_model=StaffResponse)
async def update_staff(
    staff_id: uuid.UUID,
    body: StaffUpdate,
    current_user=Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    return await StaffService(db).update_staff(staff_id, body)


@router.delete("/staff/{staff_id}", response_model=SuccessResponse)
async def deactivate_staff(
    staff_id: uuid.UUID,
    current_user=Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    await StaffService(db).deactivate_staff(staff_id)
    return {"message": "Staff member deactivated successfully"}


@router.post("/staff/{staff_id}/reset-pin", response_model=SuccessResponse)
async def reset_pin(
    staff_id: uuid.UUID,
    body: PinResetRequest,
    current_user=Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    await StaffService(db).reset_pin(staff_id, body.new_pin)
    return {"message": "PIN reset successfully"}


@router.get("/activity-logs", response_model=ActivityLogListResponse)
async def list_activity_logs(
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    current_user=Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    return await StaffService(db).list_activity_logs(page, page_size)
