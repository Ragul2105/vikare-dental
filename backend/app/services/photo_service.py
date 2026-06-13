from __future__ import annotations

import io
import uuid

from fastapi import HTTPException, UploadFile
from PIL import Image
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.visit import Visit
from app.models.visit_photo import VisitPhoto
from app.services.s3_service import S3Service

MAX_PHOTO_SIZE_KB = 1500
PHOTO_MAX_DIMENSION = 1920


class PhotoService:
    def __init__(self, db: AsyncSession):
        self.db = db
        self.s3 = S3Service()

    async def upload_photos(
        self,
        visit_id: uuid.UUID,
        files: list[UploadFile],
        captions: list[str],
        uploaded_by: uuid.UUID,
    ) -> list[VisitPhoto]:
        visit = await self.db.get(Visit, visit_id)
        if not visit:
            raise HTTPException(status_code=404, detail="Visit not found")

        results: list[VisitPhoto] = []
        year = visit.visit_date.year
        month = f"{visit.visit_date.month:02d}"

        for index, file in enumerate(files):
            self._validate_file(file)
            compressed = await self._compress_image(file)
            photo_id = uuid.uuid4()
            s3_key = (
                f"visit-photos/{year}/{month}/{visit.patient_id}/{visit_id}/{photo_id}.jpg"
            )
            await self.s3.upload_bytes(s3_key, compressed, content_type="image/jpeg")
            photo_url = await self.s3.get_presigned_url(s3_key)
            caption = captions[index] if index < len(captions) else None
            photo = VisitPhoto(
                id=photo_id,
                visit_id=visit_id,
                s3_key=s3_key,
                photo_url=photo_url,
                caption=caption,
                uploaded_by=uploaded_by,
            )
            self.db.add(photo)
            results.append(photo)

        await self.db.flush()
        return results

    async def delete_photo(self, photo_id: uuid.UUID, visit_id: uuid.UUID) -> None:
        photo = await self.db.get(VisitPhoto, photo_id)
        if not photo or photo.visit_id != visit_id:
            raise HTTPException(status_code=404, detail="Photo not found")

        await self.s3.delete_object(photo.s3_key)
        await self.db.delete(photo)
        await self.db.flush()

    def _validate_file(self, file: UploadFile) -> None:
        allowed_types = {"image/jpeg", "image/png", "image/webp"}
        if file.content_type not in allowed_types:
            raise HTTPException(
                status_code=400,
                detail=f"Unsupported file type: {file.content_type}. Allowed: JPEG, PNG, WebP",
            )

    async def _compress_image(self, file: UploadFile) -> bytes:
        contents = await file.read()
        image = Image.open(io.BytesIO(contents)).convert("RGB")
        if max(image.size) > PHOTO_MAX_DIMENSION:
            image.thumbnail((PHOTO_MAX_DIMENSION, PHOTO_MAX_DIMENSION), Image.LANCZOS)

        output = io.BytesIO()
        quality = 85
        image.save(output, format="JPEG", quality=quality, optimize=True)

        while output.tell() > MAX_PHOTO_SIZE_KB * 1024 and quality > 50:
            quality -= 10
            output = io.BytesIO()
            image.save(output, format="JPEG", quality=quality, optimize=True)

        return output.getvalue()

