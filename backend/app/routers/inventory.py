import uuid

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.dependencies import get_db, require_admin
from app.schemas.inventory import InventoryCreate, InventoryListResponse, InventoryResponse, InventoryUpdate
from app.services.inventory_service import InventoryService

router = APIRouter(prefix="/inventory", tags=["Inventory"])


@router.get("", response_model=InventoryListResponse)
async def list_items(current_user=Depends(require_admin), db: AsyncSession = Depends(get_db)):
    return await InventoryService(db).list_items()


@router.post("", response_model=InventoryResponse, status_code=201)
async def create_item(
    body: InventoryCreate,
    current_user=Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    return await InventoryService(db).create_item(body, created_by=current_user.id)


@router.patch("/{item_id}", response_model=InventoryResponse)
async def update_item(
    item_id: uuid.UUID,
    body: InventoryUpdate,
    current_user=Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    return await InventoryService(db).update_item(item_id, body)


@router.get("/alerts", response_model=InventoryListResponse)
async def low_stock_alerts(
    current_user=Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    return await InventoryService(db).list_low_stock_items()
