"""
Simple notification service to send alert/update emails via SMTP.
Configure via environment variables:
- SMTP_HOST (required)
- SMTP_PORT (default 587)
- SMTP_USER (required)
- SMTP_PASSWORD (required)
- SMTP_FROM (required, display From address)
- SMTP_USE_SSL (optional, set to "1" to force SSL; default uses STARTTLS)
"""
import os
import smtplib
import ssl
from email.message import EmailMessage
from typing import List

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, EmailStr, Field

app = FastAPI(title="Notification Service")

SMTP_HOST = os.environ.get("SMTP_HOST", "smtp.gmail.com")
SMTP_PORT = int(os.environ.get("SMTP_PORT", "587"))
SMTP_USER = os.environ.get("SMTP_USER", "energia.application.service@gmail.com")
SMTP_PASSWORD = os.environ.get("SMTP_PASSWORD")
SMTP_FROM = os.environ.get("SMTP_FROM", "ENERGIA ALERTS <energia.application.service@gmail.com>")
SMTP_USE_SSL = os.environ.get("SMTP_USE_SSL", "0") == "1"


def _require_smtp_config():
    missing = [name for name, val in {
        "SMTP_HOST": SMTP_HOST,
        "SMTP_USER": SMTP_USER,
        "SMTP_PASSWORD": SMTP_PASSWORD,
        "SMTP_FROM": SMTP_FROM,
    }.items() if not val]
    if missing:
        raise HTTPException(status_code=500, detail=f"Missing SMTP config: {', '.join(missing)}")


def _send_email(subject: str, body: str, recipients: List[str]):
    _require_smtp_config()
    if not recipients:
        raise HTTPException(status_code=400, detail="Recipients required")

    msg = EmailMessage()
    msg["Subject"] = subject
    msg["From"] = SMTP_FROM
    msg["To"] = ", ".join(recipients)
    msg.set_content(body)

    context = ssl.create_default_context()
    try:
        if SMTP_USE_SSL or SMTP_PORT == 465:
            with smtplib.SMTP_SSL(SMTP_HOST, SMTP_PORT, context=context) as server:
                server.login(SMTP_USER, SMTP_PASSWORD)
                server.send_message(msg)
        else:
            with smtplib.SMTP(SMTP_HOST, SMTP_PORT) as server:
                server.starttls(context=context)
                server.login(SMTP_USER, SMTP_PASSWORD)
                server.send_message(msg)
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(status_code=500, detail=f"Failed to send email: {exc}") from exc


class NotificationRequest(BaseModel):
    subject: str = Field(..., min_length=3, max_length=200)
    body: str = Field(..., min_length=3, max_length=5000)
    recipients: List[EmailStr] = Field(..., min_items=1, max_items=100)


@app.post("/alert")
def send_alert(req: NotificationRequest):
    _send_email(req.subject, req.body, [str(r) for r in req.recipients])
    return {"status": "sent", "type": "alert", "recipients": req.recipients}


@app.post("/update")
def send_update(req: NotificationRequest):
    _send_email(req.subject, req.body, [str(r) for r in req.recipients])
    return {"status": "sent", "type": "update", "recipients": req.recipients}


@app.get("/health")
def health():
    return {"status": "ok"}

# SQL command to alter the table and add the new column
