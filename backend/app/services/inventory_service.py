from __future__ import annotations

import uuid

from fastapi import HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.inventory import InventoryItem
from app.schemas.inventory import InventoryCreate, InventoryUpdate


class InventoryService:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def list_items(self) -> dict:
        result = await self.db.execute(
            select(InventoryItem).order_by(InventoryItem.item_name)
        )
        return {"items": result.scalars().all()}

    async def create_item(self, data: InventoryCreate, created_by: uuid.UUID) -> InventoryItem:
        await self._ensure_unique_sku(data.sku)
        item = InventoryItem(created_by=created_by, **data.model_dump())
        self.db.add(item)
        await self.db.flush()
        return item

    async def update_item(self, item_id: uuid.UUID, data: InventoryUpdate) -> InventoryItem:
        item = await self.db.get(InventoryItem, item_id)
        if not item:
            raise HTTPException(status_code=404, detail="Inventory item not found")

        payload = data.model_dump(exclude_unset=True)
        if "sku" in payload and payload["sku"] != item.sku:
            await self._ensure_unique_sku(payload["sku"])
        for field, value in payload.items():
            setattr(item, field, value)
        await self.db.flush()
        return item

    async def list_low_stock_items(self) -> dict:
        result = await self.db.execute(
            select(InventoryItem)
            .where(
                InventoryItem.is_active.is_(True),
                InventoryItem.stock_quantity <= InventoryItem.reorder_threshold,
            )
            .order_by(InventoryItem.item_name)
        )
        return {"items": result.scalars().all()}

    async def _ensure_unique_sku(self, sku: str) -> None:
        result = await self.db.execute(select(InventoryItem).where(InventoryItem.sku == sku))
        if result.scalar_one_or_none():
            raise HTTPException(status_code=409, detail="Inventory SKU already exists")

