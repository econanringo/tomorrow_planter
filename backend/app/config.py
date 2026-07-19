from functools import lru_cache
from typing import List

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    gcp_project_id: str = "tomorrow-planter"
    gcp_location: str = "asia-northeast1"
    firebase_project_id: str = "tomorrow-planter"
    gemini_model: str = "gemini-3.5-flash"
    embedding_model: str = "text-embedding-004"
    embedding_dimensions: int = 768
    cors_origins: str = "*"
    # When true, skip Firebase token verification (local UI-only demos).
    auth_disabled: bool = False

    @property
    def cors_origin_list(self) -> List[str]:
        if self.cors_origins.strip() == "*":
            return ["*"]
        return [o.strip() for o in self.cors_origins.split(",") if o.strip()]


@lru_cache
def get_settings() -> Settings:
    return Settings()
