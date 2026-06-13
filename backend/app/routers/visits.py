from typing import Annotated
import uuid

from fastapi import APIRouter, Depends, File, Form, HTTPException, Request, UploadFile
from sqlalchemy.ext.asyncio import AsyncSession

from app.dependencies import get_current_user, get_db
from app.main import limiter
from app.schemas.visit import VisitCreate, VisitPhotoResponse, VisitResponse, VisitUpdate
from app.services.photo_service import PhotoService
from app.services.visit_service import VisitService

router = APIRouter(prefix="/visits", tags=["Visits"])


@router.post("", response_model=VisitResponse, status_code=201)
async def create_visit(
    body: VisitCreate,
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    return await VisitService(db).create_visit(body, created_by=current_user.id)


@router.get("/{visit_id}", response_model=VisitResponse)
async def get_visit(
    visit_id: uuid.UUID,
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    return await VisitService(db).get_visit(visit_id)


@router.patch("/{visit_id}", response_model=VisitResponse)
async def update_visit(
    visit_id: uuid.UUID,
    body: VisitUpdate,
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    return await VisitService(db).update_visit(visit_id, body)


@router.post("/{visit_id}/photos", response_model=list[VisitPhotoResponse], status_code=201)
@limiter.limit("30/minute")
async def upload_photos(
    request: Request,
    visit_id: uuid.UUID,
    files: Annotated[list[UploadFile], File(...)],
    captions: Annotated[list[str] | None, Form()] = None,
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    if len(files) > 10:
        raise HTTPException(status_code=400, detail="Maximum 10 photos per upload")
    return await PhotoService(db).upload_photos(
        visit_id=visit_id,
        files=files,
        captions=captions or [],
        uploaded_by=current_user.id,
    )


@router.delete("/{visit_id}/photos/{photo_id}", status_code=204)
async def delete_photo(
    visit_id: uuid.UUID,
    photo_id: uuid.UUID,
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    await PhotoService(db).delete_photo(photo_id, visit_id)
