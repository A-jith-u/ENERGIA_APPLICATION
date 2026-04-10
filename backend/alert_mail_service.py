"""
Dedicated Alert Mail Service for anomaly notifications.

This service is intentionally separated from in-app notification storage so
email delivery can be managed independently while preserving existing behavior.

Environment variables (dedicated, preferred):
- ALERT_SMTP_HOST
- ALERT_SMTP_PORT
- ALERT_SMTP_USER
- ALERT_SMTP_PASSWORD
- ALERT_SMTP_FROM
- ALERT_SMTP_USE_SSL

Fallback compatibility variables (existing):
- SMTP_HOST
- SMTP_PORT
- SMTP_USER
- SMTP_PASSWORD
- SMTP_FROM
- SMTP_USE_SSL
"""

from __future__ import annotations

import os
import smtplib
import ssl
from email.message import EmailMessage
from typing import Iterable
from dotenv import load_dotenv


# Ensure dedicated mail service can read backend/.env regardless of launch cwd.
_HERE = os.path.dirname(os.path.abspath(__file__))
_ENV_PATH = os.path.join(_HERE, ".env")
if os.path.exists(_ENV_PATH):
    load_dotenv(dotenv_path=_ENV_PATH, override=False)
else:
    load_dotenv(override=False)


class AlertMailService:
    """Dedicated SMTP email sender for alert push notifications."""

    def __init__(self) -> None:
        self.smtp_host = (
            os.environ.get("ALERT_SMTP_HOST")
            or os.environ.get("SMTP_HOST")
            or os.environ.get("MAIL_SERVER")
            or "smtp.gmail.com"
        )
        self.smtp_port = int(
            os.environ.get("ALERT_SMTP_PORT")
            or os.environ.get("SMTP_PORT")
            or os.environ.get("MAIL_PORT")
            or "587"
        )
        self.smtp_user = (
            os.environ.get("ALERT_SMTP_USER")
            or os.environ.get("SMTP_USER")
            or os.environ.get("MAIL_USERNAME")
            or ""
        )
        self.smtp_password = (
            os.environ.get("ALERT_SMTP_PASSWORD")
            or os.environ.get("SMTP_PASSWORD")
            or os.environ.get("MAIL_PASSWORD")
            or ""
        )
        self.smtp_from = (
            os.environ.get("ALERT_SMTP_FROM")
            or os.environ.get("SMTP_FROM")
            or os.environ.get("MAIL_FROM")
            or "ENERGIA ALERTS <energia.application.service@gmail.com>"
        )
        use_ssl_raw = os.environ.get("ALERT_SMTP_USE_SSL")
        if use_ssl_raw is None:
            use_ssl_raw = os.environ.get("SMTP_USE_SSL")
        if use_ssl_raw is None:
            # MAIL_STARTTLS=true means SSL should be false.
            mail_ssl = os.environ.get("MAIL_SSL_TLS", "false").strip().lower()
            use_ssl_raw = "1" if mail_ssl in {"1", "true", "yes", "on"} else "0"
        self.smtp_use_ssl = str(use_ssl_raw).strip().lower() in {"1", "true", "yes", "on"}

    def is_configured(self) -> bool:
        return bool(self.smtp_host and self.smtp_user and self.smtp_password and self.smtp_from)

    def send_html_email(self, *, subject: str, html_body: str, recipients: Iterable[str]) -> None:
        recipients = [r.strip() for r in recipients if str(r).strip()]
        if not recipients:
            raise ValueError("At least one recipient is required")
        if not self.is_configured():
            raise RuntimeError("Alert mail service is not configured")

        msg = EmailMessage()
        msg["Subject"] = subject
        msg["From"] = self.smtp_from
        msg["To"] = ", ".join(recipients)
        msg.set_content(html_body, subtype="html")

        ctx = ssl.create_default_context()
        if self.smtp_use_ssl or self.smtp_port == 465:
            with smtplib.SMTP_SSL(self.smtp_host, self.smtp_port, context=ctx) as server:
                server.login(self.smtp_user, self.smtp_password)
                server.send_message(msg)
        else:
            with smtplib.SMTP(self.smtp_host, self.smtp_port) as server:
                server.starttls(context=ctx)
                server.login(self.smtp_user, self.smtp_password)
                server.send_message(msg)
