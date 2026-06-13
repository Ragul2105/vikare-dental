from __future__ import annotations

from datetime import datetime, timezone
import uuid

from fastapi import HTTPException
from jose import JWTError
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user import User
from app.utils.security import (
    create_access_token,
    create_refresh_token,
    decode_token,
    verify_pin,
)


class AuthService:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def list_active_users(self) -> dict:
        result = await self.db.execute(
            select(User).where(User.is_active.is_(True)).order_by(User.name)
        )
        return {"items": result.scalars().all()}

    async def login(self, user_id: uuid.UUID, pin: str) -> dict:
        user = await self.db.get(User, user_id)
        if not user or not user.is_active:
            raise HTTPException(status_code=401, detail="Invalid credentials")
        if not verify_pin(pin, user.pin_hash):
            raise HTTPException(status_code=401, detail="Invalid credentials")

        user.last_login_at = datetime.now(timezone.utc)
        await self.db.flush()

        payload = {"sub": str(user.id), "role": user.role, "name": user.name}
        return {
            "access_token": create_access_token(payload),
            "refresh_token": create_refresh_token(payload),
            "token_type": "bearer",
        }

    async def refresh_token(self, refresh_token: str) -> dict:
        try:
            payload = decode_token(refresh_token)
            if payload.get("type") != "refresh":
                raise HTTPException(status_code=401, detail="Invalid token type")
        except JWTError:
            raise HTTPException(status_code=401, detail="Invalid refresh token") from None

        new_payload = {
            "sub": payload["sub"],
            "role": payload["role"],
            "name": payload["name"],
        }
        return {
            "access_token": create_access_token(new_payload),
            "refresh_token": create_refresh_token(new_payload),
            "token_type": "bearer",
        }

