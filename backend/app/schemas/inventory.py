from __future__ import annotations

from datetime import datetime
import uuid

from pydantic import BaseModel, ConfigDict, Field


class InventoryCreate(BaseModel):
    item_name: str = Field(..., min_length=1, max_length=150)
    sku: str = Field(..., min_length=1, max_length=50)
    unit: str = Field("unit", min_length=1, max_length=30)
    stock_quantity: int = Field(0, ge=0)
    reorder_threshold: int = Field(0, ge=0)


class InventoryUpdate(BaseModel):
    item_name: str | None = Field(None, min_length=1, max_length=150)
    sku: str | None = Field(None, min_length=1, max_length=50)
    unit: str | None = Field(None, min_length=1, max_length=30)
    stock_quantity: int | None = Field(None, ge=0)
    reorder_threshold: int | None = Field(None, ge=0)
    is_active: bool | None = None


class InventoryResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    item_name: str
    sku: str
    unit: str
    stock_quantity: int
    reorder_threshold: int
    invoice_s3_key: str | None
    is_active: bool
    created_at: datetime
    updated_at: datetime


class InventoryListResponse(BaseModel):
    items: list[InventoryResponse]

