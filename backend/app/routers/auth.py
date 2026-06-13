from fastapi import APIRouter, Depends, Request, Response
from sqlalchemy.ext.asyncio import AsyncSession

from app.dependencies import get_current_user, get_db
from app.main import limiter
from app.schemas.auth import LoginRequest, RefreshRequest, TokenResponse, UserListResponse
from app.services.auth_service import AuthService

router = APIRouter(prefix="/auth", tags=["Auth"])


@router.get("/users", response_model=UserListResponse)
@limiter.limit("60/minute")
async def list_users(request: Request, db: AsyncSession = Depends(get_db)):
    return await AuthService(db).list_active_users()


@router.post("/login", response_model=TokenResponse)
@limiter.limit("10/minute")
async def login(request: Request, body: LoginRequest, db: AsyncSession = Depends(get_db)):
    return await AuthService(db).login(body.user_id, body.pin)


@router.post("/refresh", response_model=TokenResponse)
@limiter.limit("30/minute")
async def refresh(request: Request, body: RefreshRequest, db: AsyncSession = Depends(get_db)):
    return await AuthService(db).refresh_token(body.refresh_token)


@router.post("/logout", status_code=204)
async def logout(current_user=Depends(get_current_user)):
    return Response(status_code=204)
