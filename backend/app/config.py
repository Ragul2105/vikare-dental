from __future__ import annotations

from functools import lru_cache

from pydantic import Field, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
    )

    app_name: str = "Dental Clinic API"
    environment: str = "development"
    debug: bool = False
    api_prefix: str = "/api/v1"

    database_url: str
    db_pool_size: int = 10
    db_max_overflow: int = 20

    jwt_secret_key: str
    jwt_algorithm: str = "HS256"
    access_token_expire_minutes: int = 60
    refresh_token_expire_days: int = 7

    aws_access_key_id: str
    aws_secret_access_key: str
    aws_region: str = "ap-south-1"
    s3_bucket_name: str
    s3_presigned_url_expiry: int = 900
    file_storage_backend: str = "local"
    local_storage_path: str = "data/storage"

    wati_api_url: str
    wati_api_token: str

    inventory_addon_enabled: bool = False
    cors_origins: list[str] = Field(default_factory=list)

    @field_validator("debug", mode="before")
    @classmethod
    def parse_debug(cls, value):
        if isinstance(value, str):
            normalized = value.strip().lower()
            if normalized in {"1", "true", "yes", "on", "debug"}:
                return True
            if normalized in {"0", "false", "no", "off", "release", "prod", "production"}:
                return False
        return value

    @field_validator("cors_origins", mode="before")
    @classmethod
    def parse_cors_origins(cls, value):
        if value is None or value == "":
            return []
        if isinstance(value, str):
            return [item.strip() for item in value.split(",") if item.strip()]
        return value

    @field_validator("file_storage_backend", mode="before")
    @classmethod
    def parse_file_storage_backend(cls, value):
        normalized = str(value or "local").strip().lower()
        if normalized not in {"local", "s3"}:
            raise ValueError("FILE_STORAGE_BACKEND must be either 'local' or 's3'")
        return normalized


@lru_cache
def get_settings() -> Settings:
    return Settings()
