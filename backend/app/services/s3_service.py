from __future__ import annotations

from pathlib import Path

import boto3
from botocore.exceptions import ClientError
from fastapi import HTTPException

from app.config import get_settings

settings = get_settings()


class S3Service:
    def __init__(self):
        self.backend = settings.file_storage_backend
        self.bucket = settings.s3_bucket_name
        self.local_root = Path(settings.local_storage_path).resolve()
        self.local_root.mkdir(parents=True, exist_ok=True)
        self.api_prefix = settings.api_prefix.rstrip("/")

        self.client = None
        if self.backend == "s3":
            self.client = boto3.client(
                "s3",
                aws_access_key_id=settings.aws_access_key_id,
                aws_secret_access_key=settings.aws_secret_access_key,
                region_name=settings.aws_region,
            )

    async def upload_bytes(self, key: str, data: bytes, content_type: str) -> None:
        if self.backend == "local":
            target = self._local_path_for_key(key)
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)
            return

        self.client.put_object(
            Bucket=self.bucket,
            Key=key,
            Body=data,
            ContentType=content_type,
            ServerSideEncryption="AES256",
        )

    async def get_presigned_url(self, key: str) -> str:
        if self.backend == "local":
            normalized_key = "/".join(Path(key).parts)
            return f"{self.api_prefix}/assets/{normalized_key}"

        return self.client.generate_presigned_url(
            "get_object",
            Params={"Bucket": self.bucket, "Key": key},
            ExpiresIn=settings.s3_presigned_url_expiry,
        )

    async def delete_object(self, key: str) -> None:
        if self.backend == "local":
            target = self._local_path_for_key(key)
            if target.exists():
                target.unlink()
            return

        try:
            self.client.delete_object(Bucket=self.bucket, Key=key)
        except ClientError as exc:
            raise HTTPException(status_code=500, detail=f"S3 delete failed: {exc}") from exc

    def _local_path_for_key(self, key: str) -> Path:
        relative_path = Path(key)
        if relative_path.is_absolute() or ".." in relative_path.parts:
            raise HTTPException(status_code=400, detail="Invalid storage key")

        resolved = (self.local_root / relative_path).resolve()
        if not str(resolved).startswith(str(self.local_root)):
            raise HTTPException(status_code=400, detail="Invalid storage key")
        return resolved
