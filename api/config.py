from functools import lru_cache

from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    database_url: str = "postgresql+asyncpg://btf:btf_local@localhost:5432/bethefifth"
    test_database_url: str = "sqlite+aiosqlite:///:memory:"
    firebase_project_id: str = ""
    firebase_service_account_json: str = ""
    allowed_origins: list[str] = [
        "http://localhost:3000",
        "http://localhost:8080",
        "http://localhost:5173",
    ]

    model_config = {"env_file": ".env", "env_file_encoding": "utf-8"}


@lru_cache
def get_settings() -> Settings:
    return Settings()
