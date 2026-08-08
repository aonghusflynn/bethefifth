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
    # Transactional email (Resend). Unset in dev/test — EmailService then logs
    # instead of sending, so nothing depends on an external provider locally.
    resend_api_key: str = ""
    email_from: str = "BeTheFifth <noreply@bethefifth.com>"
    app_base_url: str = "http://localhost:5173"

    model_config = {"env_file": ".env", "env_file_encoding": "utf-8"}


@lru_cache
def get_settings() -> Settings:
    return Settings()
