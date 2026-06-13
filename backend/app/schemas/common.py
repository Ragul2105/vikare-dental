from __future__ import annotations

from pydantic import BaseModel


class ErrorResponse(BaseModel):
    error_code: str
    message: str
    details: dict | list | None = None


class SuccessResponse(BaseModel):
    message: str

