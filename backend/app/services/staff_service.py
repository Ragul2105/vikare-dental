from __future__ import annotations

import uuid

from fastapi import HTTPException
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.activity_log import ActivityLog
from app.models.user import User
from app.schemas.staff import StaffCreate, StaffUpdate
from app.utils.pagination import calculate_offset
from app.utils.security import hash_pin


class StaffService:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def list_staff(self) -> dict:
        result = await self.db.execute(select(User).order_by(User.name))
        return {"items": result.scalars().all()}

    async def create_staff(self, data: StaffCreate) -> User:
        await self._ensure_unique_name(data.name)
        self._validate_pin(data.pin)

        user = User(
            name=data.name,
            role=data.role,
            email=data.email,
            mobile=data.mobile,
            job_title=data.job_title,
            schedule=data.schedule,
            pin_hash=hash_pin(data.pin),
            is_active=True,
        )
        self.db.add(user)
        await self.db.flush()
        return user

    async def update_staff(self, staff_id: uuid.UUID, data: StaffUpdate) -> User:
        user = await self._get_staff_or_404(staff_id)
        payload = data.model_dump(exclude_unset=True)

        if "name" in payload and payload["name"] != user.name:
            await self._ensure_unique_name(payload["name"])

        for field, value in payload.items():
            setattr(user, field, value)

        await self.db.flush()
        return user

    async def deactivate_staff(self, staff_id: uuid.UUID) -> None:
        user = await self._get_staff_or_404(staff_id)
        user.is_active = False
        await self.db.flush()

    async def reset_pin(self, staff_id: uuid.UUID, new_pin: str) -> None:
        self._validate_pin(new_pin)
        user = await self._get_staff_or_404(staff_id)
        user.pin_hash = hash_pin(new_pin)
        await self.db.flush()

    async def list_activity_logs(self, page: int, page_size: int) -> dict:
        total = (await self.db.execute(select(func.count()).select_from(ActivityLog))).scalar() or 0
        result = await self.db.execute(
            select(ActivityLog)
            .order_by(ActivityLog.created_at.desc())
            .offset(calculate_offset(page, page_size))
            .limit(page_size)
        )
        return {
            "items": result.scalars().all(),
            "total": total,
            "page": page,
            "page_size": page_size,
        }

    async def _get_staff_or_404(self, staff_id: uuid.UUID) -> User:
        user = await self.db.get(User, staff_id)
        if not user:
            raise HTTPException(status_code=404, detail="Staff member not found")
        return user

    async def _ensure_unique_name(self, name: str) -> None:
        result = await self.db.execute(select(User).where(User.name == name))
        if result.scalar_one_or_none():
            raise HTTPException(status_code=409, detail="Staff member name already exists")

    def _validate_pin(self, pin: str) -> None:
        if len(pin) != 4:
            raise HTTPException(status_code=422, detail="PIN must be exactly 4 digits")
        if not pin.isdigit():
            raise HTTPException(status_code=422, detail="PIN must contain digits only")
