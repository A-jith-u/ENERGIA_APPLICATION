"""Centralized configuration loader for the backend.
Reads environment variables from a .env file (if present) and exposes
helpers for required settings like DB_URL, JWT secret, and mail config.
"""
from __future__ import annotations

import os
from dataclasses import dataclass
from typing import Optional

from dotenv import load_dotenv
from sqlalchemy.engine.url import make_url


# Load environment from backend/.env explicitly so we don't accidentally pick up
# a different working directory or machine-level DB_URL.
BASE_DIR = os.path.dirname(__file__)
DOTENV_PATH = os.path.join(BASE_DIR, ".env")
load_dotenv(DOTENV_PATH, override=True)


def _as_bool(val: Optional[str], default: bool = False) -> bool:
    if val is None:
        return default
    return val.strip().lower() in {"1", "true", "yes", "on"}


def get_db_url(required: bool = True) -> str:
    """Return DB_URL from env.

    Enforces PostgreSQL for all environments. This prevents accidental fallback
    to SQLite or other drivers that are incompatible with the deployed schema.
    """
    db_url = os.environ.get("DB_URL")
    if not db_url:
        if required:
            raise RuntimeError(
                "DB_URL is not set. Configure it in your environment or .env, e.g.\n"
                "DB_URL=postgresql+psycopg2://postgres:postgres@localhost:5432/energia"
            )
        return ""

    try:
        url = make_url(db_url)
    except Exception as exc:  # noqa: BLE001
        if required:
            raise RuntimeError(f"Invalid DB_URL: {db_url}. Error: {exc}") from exc
        return db_url

    backend = url.get_backend_name()
    if backend != "postgresql":
        raise RuntimeError(
            "DB_URL must point to PostgreSQL. "
            f"Got '{url.render_as_string(hide_password=False)}'."
        )

    return db_url


def get_jwt_secret() -> str:
    return os.environ.get("JWT_SECRET", "change-me-in-prod")


@dataclass
class MailSettings:
    username: Optional[str]
    password: Optional[str]
    from_addr: Optional[str]
    server: str
    port: int
    starttls: bool
    ssl_tls: bool
    use_credentials: bool


def get_mail_settings() -> MailSettings:
    return MailSettings(
        username=os.environ.get("MAIL_USERNAME"),
        password=os.environ.get("MAIL_PASSWORD"),
        from_addr=os.environ.get("MAIL_FROM"),
        server=os.environ.get("MAIL_SERVER", "smtp.gmail.com"),
        port=int(os.environ.get("MAIL_PORT", "587")),
        starttls=_as_bool(os.environ.get("MAIL_STARTTLS"), True),
        ssl_tls=_as_bool(os.environ.get("MAIL_SSL_TLS"), False),
        use_credentials=_as_bool(os.environ.get("MAIL_USE_CREDENTIALS"), True),
    )
