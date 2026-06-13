from __future__ import annotations

from starlette.background import BackgroundTask, BackgroundTasks
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request

from app.database import AsyncSessionLocal
from app.models.activity_log import ActivityLog

LOGGED_PATHS = {"patients", "appointments", "visits", "staff", "treatments", "medications", "inventory"}


class ActivityLoggerMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        response = await call_next(request)
        path_parts = [part for part in request.url.path.split("/") if part]
        entity_type = path_parts[2] if len(path_parts) >= 3 else "unknown"

        if request.method in {"POST", "PATCH", "DELETE"} and entity_type in LOGGED_PATHS:
            self._attach_background_task(
                response,
                self._write_log,
                request,
                response,
                entity_type,
                path_parts,
            )
        return response

    async def _write_log(self, request: Request, response, entity_type: str, path_parts: list[str]) -> None:
        entity_id = path_parts[3] if len(path_parts) >= 4 else None

        try:
            async with AsyncSessionLocal() as db:
                db.add(
                    ActivityLog(
                        user_id=getattr(request.state, "user_id", None),
                        action=request.method,
                        entity_type=entity_type,
                        entity_id=entity_id,
                        details={"path": request.url.path, "status": response.status_code},
                    )
                )
                await db.commit()
        except Exception:
            return

    def _attach_background_task(self, response, func, *args) -> None:
        if response.background is None:
            response.background = BackgroundTask(func, *args)
            return

        if isinstance(response.background, BackgroundTasks):
            response.background.add_task(func, *args)
            return

        existing = response.background
        background_tasks = BackgroundTasks()
        background_tasks.add_task(existing.func, *existing.args, **existing.kwargs)
        background_tasks.add_task(func, *args)
        response.background = background_tasks
