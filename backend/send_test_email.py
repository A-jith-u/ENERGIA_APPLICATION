"""
Send a test email using MAIL_* settings from backend/.env or environment.
Usage:
    python backend/send_test_email.py <recipient@example.com>

This script avoids starting the API server or connecting to the database.
"""
from __future__ import annotations

import asyncio
import os
import sys
from dotenv import load_dotenv
from fastapi_mail import FastMail, MessageSchema, ConnectionConfig

# Ensure we load backend/.env specifically
BASE_DIR = os.path.dirname(__file__)
DOTENV_PATH = os.path.join(BASE_DIR, ".env")
load_dotenv(DOTENV_PATH, override=False)

# Import config after loading env
try:
    import backend.config as cfg  # when executed from repo root
except Exception:
    # Fallback when run from backend directory
    sys.path.insert(0, os.path.dirname(BASE_DIR))
    import backend.config as cfg


def build_mail_conf() -> ConnectionConfig:
    m = cfg.get_mail_settings()
    return ConnectionConfig(
        MAIL_USERNAME=m.username,
        MAIL_PASSWORD=m.password,
        MAIL_FROM=m.from_addr,
        MAIL_PORT=m.port,
        MAIL_SERVER=m.server,
        MAIL_STARTTLS=m.starttls,
        MAIL_SSL_TLS=m.ssl_tls,
        USE_CREDENTIALS=m.use_credentials,
    )


async def send_test(recipient: str) -> None:
    conf = build_mail_conf()
    fm = FastMail(conf)
    msg = MessageSchema(
        subject="ENERGIA - Test Email",
        recipients=[recipient],
        body=(
            "<html><body>"
            "<h3>ENERGIA Test Email</h3>"
            "<p>If you received this, your MAIL_* configuration works.\n" 
            "</p>"
            "</body></html>"
        ),
        subtype="html",
    )
    await fm.send_message(msg)


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print("Usage: python backend/send_test_email.py <recipient@example.com>")
        return 2
    recipient = argv[1]
    try:
        asyncio.run(send_test(recipient))
        print(f"Sent test email to {recipient}")
        return 0
    except Exception as exc:
        print(f"Failed to send test email: {exc}")
        return 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
