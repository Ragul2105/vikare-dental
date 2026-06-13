from datetime import date
import uuid
from typing import Literal

from fastapi import APIRouter, Depends, Query, Request
from sqlalchemy.ext.asyncio import AsyncSession

from app.dependencies import get_current_user, get_db
from app.main import limiter
from app.schemas.appointment import (
    AppointmentCreate,
    AppointmentListResponse,
    AppointmentResponse,
    AppointmentUpdate,
)
from app.schemas.common import SuccessResponse
from app.services.appointment_service import AppointmentService
from app.utils.india_time import india_today

router = APIRouter(prefix="/appointments", tags=["Appointments"])


@router.get("", response_model=AppointmentListResponse)
@limiter.limit("100/minute")
async def list_appointments(
    request: Request,
    query_date: date | None = Query(None, alias="date"),
    range_: Literal["day", "week"] = Query("day", alias="range"),
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    return await AppointmentService(db).list_appointments(query_date or india_today(), range_)


@router.post("", response_model=AppointmentResponse, status_code=201)
@limiter.limit("60/minute")
async def create_appointment(
    request: Request,
    body: AppointmentCreate,
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    return await AppointmentService(db).create_appointment(body, created_by=current_user.id)


@router.get("/{appointment_id}", response_model=AppointmentResponse)
async def get_appointment(
    appointment_id: uuid.UUID,
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    return await AppointmentService(db).get_appointment(appointment_id)


@router.patch("/{appointment_id}", response_model=AppointmentResponse)
async def update_appointment(
    appointment_id: uuid.UUID,
    body: AppointmentUpdate,
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    return await AppointmentService(db).update_appointment(appointment_id, body)


@router.delete("/{appointment_id}", response_model=SuccessResponse)
async def cancel_appointment(
    appointment_id: uuid.UUID,
    reason: str | None = Query(None, min_length=5, max_length=500),
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    await AppointmentService(db).cancel_appointment(appointment_id, reason=reason)
    return {"message": "Appointment cancelled successfully"}
