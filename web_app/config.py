"""
Configuration settings for the Excel to SQL Converter Web Application
"""
import os
from pathlib import Path
from pydantic_settings import BaseSettings
from typing import Optional


class Settings(BaseSettings):
    """Application settings loaded from environment variables or defaults"""

    app_name: str = "Excel to SQL Converter"
    app_version: str = "1.0.0"
    debug: bool = True

    host: str = "0.0.0.0"
    port: int = 8000

    upload_dir: Path = Path("web_app/uploads")
    output_dir: Path = Path("web_app/outputs")

    max_upload_size: int = 100 * 1024 * 1024
    allowed_extensions: set = {".xlsx", ".xlsm"}

    cors_origins: list = ["*"]

    openai_api_key: Optional[str] = None
    azure_endpoint: Optional[str] = None
    client_id: Optional[str] = None
    client_secret: Optional[str] = None

    class Config:
        env_file = ".env"
        case_sensitive = False


settings = Settings()

settings.upload_dir.mkdir(parents=True, exist_ok=True)
settings.output_dir.mkdir(parents=True, exist_ok=True)
