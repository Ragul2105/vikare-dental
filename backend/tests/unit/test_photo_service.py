from __future__ import annotations

from unittest.mock import AsyncMock, MagicMock

import pytest
from fastapi import HTTPException

from app.services.photo_service import PhotoService


@pytest.mark.asyncio
async def test_rejects_non_image_file():
    service = PhotoService(db=AsyncMock())
    fake_file = MagicMock()
    fake_file.content_type = "application/pdf"

    with pytest.raises(HTTPException) as exc:
        service._validate_file(fake_file)

    assert exc.value.status_code == 400

