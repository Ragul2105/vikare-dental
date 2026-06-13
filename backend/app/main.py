from __future__ import annotations

from contextlib import asynccontextmanager
import logging
from pathlib import Path

from apscheduler.schedulers.asyncio import AsyncIOScheduler
from fastapi import FastAPI, HTTPException, Request
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
from slowapi.util import get_remote_address
import structlog

from app.config import get_settings
from app.middleware.activity_logger import ActivityLoggerMiddleware
from app.middleware.request_id import RequestLoggingMiddleware
from app.services.whatsapp_service import run_reminder_job

settings = get_settings()
limiter = Limiter(key_func=get_remote_address, default_limits=["200/minute"])
scheduler = AsyncIOScheduler(timezone="Asia/Kolkata")
logger = structlog.get_logger()


def configure_logging() -> None:
    logging.basicConfig(level=logging.INFO, format="%(message)s")
    structlog.configure(
        processors=[
            structlog.stdlib.add_log_level,
            structlog.stdlib.add_logger_name,
            structlog.processors.TimeStamper(fmt="iso"),
            structlog.processors.JSONRenderer(),
        ],
        wrapper_class=structlog.stdlib.BoundLogger,
        context_class=dict,
        logger_factory=structlog.stdlib.LoggerFactory(),
    )


async def validation_error_handler(request: Request, exc: RequestValidationError) -> JSONResponse:
    return JSONResponse(
        status_code=422,
        content={
            "error_code": "VALIDATION_ERROR",
            "message": "Request validation failed",
            "details": exc.errors(),
        },
    )


async def http_exception_handler(request: Request, exc: HTTPException) -> JSONResponse:
    detail = exc.detail
    if isinstance(detail, dict):
        error_code = detail.get("error_code", "HTTP_ERROR")
        message = detail.get("message", "An error occurred")
        details = detail
    else:
        error_code = "HTTP_ERROR"
        message = str(detail)
        details = None

    return JSONResponse(
        status_code=exc.status_code,
        content={"error_code": error_code, "message": message, "details": details},
    )


async def unhandled_exception_handler(request: Request, exc: Exception) -> JSONResponse:
    logger.error(
        "unhandled_exception",
        error=str(exc),
        path=request.url.path,
        request_id=getattr(request.state, "request_id", None),
    )
    return JSONResponse(
        status_code=500,
        content={
            "error_code": "INTERNAL_SERVER_ERROR",
            "message": "An unexpected error occurred. Please try again.",
        },
    )


@asynccontextmanager
async def lifespan(app: FastAPI):
    if scheduler.get_job("whatsapp_reminders") is None:
        scheduler.add_job(
            run_reminder_job,
            trigger="interval",
            minutes=30,
            id="whatsapp_reminders",
            replace_existing=True,
            max_instances=1,
        )
    if not scheduler.running:
        scheduler.start()

    yield

    if scheduler.running:
        scheduler.shutdown(wait=False)


def create_app() -> FastAPI:
    configure_logging()

    app = FastAPI(
        title=settings.app_name,
        debug=settings.debug,
        lifespan=lifespan,
    )
    app.state.limiter = limiter
    app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)
    app.add_exception_handler(RequestValidationError, validation_error_handler)
    app.add_exception_handler(HTTPException, http_exception_handler)
    app.add_exception_handler(Exception, unhandled_exception_handler)

    if settings.cors_origins:
        app.add_middleware(
            CORSMiddleware,
            allow_origins=settings.cors_origins,
            allow_credentials=True,
            allow_methods=["*"],
            allow_headers=["*"],
        )

    app.add_middleware(RequestLoggingMiddleware)
    app.add_middleware(ActivityLoggerMiddleware)

    if settings.file_storage_backend == "local":
        storage_dir = Path(settings.local_storage_path).resolve()
        storage_dir.mkdir(parents=True, exist_ok=True)
        app.mount(
            f"{settings.api_prefix.rstrip('/')}/assets",
            StaticFiles(directory=storage_dir),
            name="local-assets",
        )

    from app.routers import (
        appointments,
        auth,
        dashboard,
        health,
        masters,
        patients,
        prescriptions,
        staff,
        visits,
    )

    app.include_router(auth.router, prefix=settings.api_prefix)
    app.include_router(patients.router, prefix=settings.api_prefix)
    app.include_router(appointments.router, prefix=settings.api_prefix)
    app.include_router(visits.router, prefix=settings.api_prefix)
    app.include_router(prescriptions.router, prefix=settings.api_prefix)
    app.include_router(dashboard.router, prefix=settings.api_prefix)
    app.include_router(staff.router, prefix=settings.api_prefix)
    app.include_router(masters.router, prefix=settings.api_prefix)
    app.include_router(health.router, prefix=settings.api_prefix)

    if settings.inventory_addon_enabled:
        from app.routers import inventory

        app.include_router(inventory.router, prefix=settings.api_prefix)

    return app


app = create_app()
