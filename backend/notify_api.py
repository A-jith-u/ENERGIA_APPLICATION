"""
Notification service — SMTP email + in-app notifications stored in DB.
In-app notifications are polled by Flutter via GET /notifications.

Environment variables:
- SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASSWORD, SMTP_FROM, SMTP_USE_SSL
- DATABASE_URL (for in-app notification storage)
"""
import os
import sys
import importlib
import smtplib
import ssl
from email.message import EmailMessage
from typing import List, Optional
from datetime import datetime, timezone

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, EmailStr, Field
from sqlalchemy import create_engine, text

app = FastAPI(title="Notification Service")

# ── SMTP config ───────────────────────────────────────────────────────────────
SMTP_HOST     = os.environ.get("SMTP_HOST", "smtp.gmail.com")
SMTP_PORT     = int(os.environ.get("SMTP_PORT", "587"))
SMTP_USER     = os.environ.get("SMTP_USER", "energia.application.service@gmail.com")
SMTP_PASSWORD = os.environ.get("SMTP_PASSWORD")
SMTP_FROM     = os.environ.get("SMTP_FROM", "ENERGIA ALERTS <energia.application.service@gmail.com>")
SMTP_USE_SSL  = os.environ.get("SMTP_USE_SSL", "0") == "1"

# ── DB config (for in-app notifications) ─────────────────────────────────────
def _load_cfg():
    """Direct file-based load — bypasses __init__.py."""
    import importlib.util as _ilu
    _here = os.path.dirname(os.path.abspath(__file__))
    _fp   = os.path.join(_here, "config.py")
    _spec = _ilu.spec_from_file_location("config", _fp)
    _mod  = _ilu.module_from_spec(_spec)
    sys.modules.setdefault("config", _mod)
    _spec.loader.exec_module(_mod)
    return _mod

cfg = _load_cfg()
engine = create_engine(cfg.get_db_url(), pool_pre_ping=True)

# Ensure notifications table exists with all required columns
def _init_notifications_table():
    with engine.begin() as conn:
        # Drop and recreate if the table exists but is missing columns (partial creation)
        # Use a single transaction so it's atomic
        conn.execute(text("""
            CREATE TABLE IF NOT EXISTS notifications (
                id              SERIAL PRIMARY KEY,
                recipient_email TEXT        NOT NULL,
                recipient_type  TEXT        NOT NULL,
                department      TEXT,
                room_id         TEXT,
                room_name       TEXT,
                title           TEXT        NOT NULL,
                message         TEXT        NOT NULL,
                anomaly_log_id  INTEGER,
                power           FLOAT,
                anomaly_score   FLOAT,
                is_read         BOOLEAN     NOT NULL DEFAULT FALSE,
                is_resolved     BOOLEAN     NOT NULL DEFAULT FALSE,
                resolved_at      TIMESTAMPTZ,
                resolution_note  TEXT,
                created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
            )
        """))

    # Add any missing columns to existing tables (safe to run repeatedly)
    columns_to_ensure = [
        ("recipient_email", "TEXT"),
        ("recipient_type",  "TEXT"),
        ("department",      "TEXT"),
        ("room_id",         "TEXT"),
        ("room_name",       "TEXT"),
        ("title",           "TEXT"),
        ("message",         "TEXT"),
        ("anomaly_log_id",  "INTEGER"),
        ("power",           "FLOAT"),
        ("anomaly_score",   "FLOAT"),
        ("is_read",         "BOOLEAN DEFAULT FALSE"),
        ("is_resolved",     "BOOLEAN DEFAULT FALSE"),
        ("resolved_at",      "TIMESTAMPTZ"),
        ("resolution_note",  "TEXT"),
        ("created_at",      "TIMESTAMPTZ DEFAULT NOW()"),
    ]
    for col_name, col_type in columns_to_ensure:
        try:
            with engine.begin() as conn:
                conn.execute(text(
                    f"ALTER TABLE notifications ADD COLUMN IF NOT EXISTS {col_name} {col_type}"
                ))
        except Exception:
            pass  # Column already exists or other non-fatal error

    # Create indexes only after table + columns are guaranteed to exist
    for idx_sql in [
        "CREATE INDEX IF NOT EXISTS idx_notifications_email ON notifications(recipient_email)",
        "CREATE INDEX IF NOT EXISTS idx_notifications_dept  ON notifications(department)",
    ]:
        try:
            with engine.begin() as conn:
                conn.execute(text(idx_sql))
        except Exception:
            pass

_init_notifications_table()


# ── Helpers ───────────────────────────────────────────────────────────────────
def _require_smtp_config():
    missing = [n for n, v in {
        "SMTP_HOST": SMTP_HOST, "SMTP_USER": SMTP_USER,
        "SMTP_PASSWORD": SMTP_PASSWORD, "SMTP_FROM": SMTP_FROM,
    }.items() if not v]
    if missing:
        raise HTTPException(status_code=500, detail=f"Missing SMTP config: {', '.join(missing)}")


def _send_email(subject: str, body: str, recipients: List[str]):
    _require_smtp_config()
    if not recipients:
        raise HTTPException(status_code=400, detail="Recipients required")
    msg = EmailMessage()
    msg["Subject"] = subject
    msg["From"]    = SMTP_FROM
    msg["To"]      = ", ".join(recipients)
    msg.set_content(body, subtype="html")
    ctx = ssl.create_default_context()
    try:
        if SMTP_USE_SSL or SMTP_PORT == 465:
            with smtplib.SMTP_SSL(SMTP_HOST, SMTP_PORT, context=ctx) as s:
                s.login(SMTP_USER, SMTP_PASSWORD)
                s.send_message(msg)
        else:
            with smtplib.SMTP(SMTP_HOST, SMTP_PORT) as s:
                s.starttls(context=ctx)
                s.login(SMTP_USER, SMTP_PASSWORD)
                s.send_message(msg)
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Failed to send email: {exc}") from exc


# ── In-app notification writer (called by anomaly_alert_service) ──────────────
def create_in_app_notification(
    recipient_email: str,
    recipient_type: str,        # 'coordinator' or 'class_rep'
    department: str,
    room_id: str,
    room_name: str,
    title: str,
    message: str,
    anomaly_log_id: Optional[int] = None,
    power: Optional[float] = None,
    anomaly_score: Optional[float] = None,
):
    """Write one notification row to the DB. Called internally — not an HTTP endpoint."""
    try:
        with engine.begin() as conn:
            conn.execute(text("""
                INSERT INTO notifications
                    (recipient_email, recipient_type, department, room_id, room_name,
                     title, message, anomaly_log_id, power, anomaly_score)
                VALUES
                    (:email, :rtype, :dept, :room_id, :room_name,
                     :title, :msg, :log_id, :power, :score)
            """), {
                "email":     recipient_email,
                "rtype":     recipient_type,
                "dept":      department,
                "room_id":   room_id,
                "room_name": room_name,
                "title":     title,
                "msg":       message,
                "log_id":    anomaly_log_id,
                "power":     power,
                "score":     anomaly_score,
            })
        print(f"[Notify] In-app notification saved → {recipient_type}: {recipient_email}")
    except Exception as e:
        print(f"[Notify] Failed to save in-app notification: {e}")


# ── Pydantic models ───────────────────────────────────────────────────────────
class NotificationRequest(BaseModel):
    subject:    str           = Field(..., min_length=3, max_length=200)
    body:       str           = Field(..., min_length=3, max_length=5000)
    recipients: List[EmailStr] = Field(..., min_items=1, max_items=100)


# ── HTTP endpoints ────────────────────────────────────────────────────────────
@app.post("/alert")
def send_alert(req: NotificationRequest):
    _send_email(req.subject, req.body, [str(r) for r in req.recipients])
    return {"status": "sent", "type": "alert", "recipients": req.recipients}


@app.post("/update")
def send_update(req: NotificationRequest):
    _send_email(req.subject, req.body, [str(r) for r in req.recipients])
    return {"status": "sent", "type": "update", "recipients": req.recipients}


@app.get("/notifications")
def get_notifications(
    email: str = None,
    department: str = None,
    unread_only: bool = False,
    limit: int = 50,
):
    """
    Flutter polls this endpoint to get in-app notifications.
    Filter by ?email=coord@example.com or ?department=CS
    ?unread_only=true returns only unread ones (for badge count).
    """
    try:
        with engine.connect() as conn:
            conditions = []
            params: dict = {"limit": limit}

            if email:
                conditions.append("recipient_email = :email")
                params["email"] = email
            if department:
                conditions.append("department = :dept")
                params["dept"] = department
            if unread_only:
                conditions.append("is_read = FALSE")

            where = ("WHERE " + " AND ".join(conditions)) if conditions else ""

            rows = conn.execute(text(f"""
                SELECT id, recipient_email, recipient_type, department,
                       room_id, room_name, title, message,
                      power, anomaly_score, is_read, is_resolved,
                      resolved_at, resolution_note, created_at
                FROM notifications
                {where}
                ORDER BY created_at DESC
                LIMIT :limit
            """), params).fetchall()

            data = [{
                "id":             r[0],
                "recipient_email": r[1],
                "recipient_type": r[2],
                "department":     r[3],
                "room_id":        r[4],
                "room_name":      r[5],
                "title":          r[6],
                "message":        r[7],
                "power":          r[8],
                "anomaly_score":  round(r[9], 4) if r[9] is not None else None,
                "is_read":        r[10],
                "is_resolved":    r[11],
                "resolved_at":    r[12].isoformat() if r[12] else None,
                "resolution_note": r[13],
                "created_at":     r[14].isoformat() if r[14] else None,
            } for r in rows]

            unread_count = sum(1 for n in data if not n["is_read"])
            return {"notifications": data, "unread_count": unread_count, "total": len(data)}

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error fetching notifications: {e}")


@app.put("/notifications/{notification_id}/read")
def mark_notification_read(notification_id: int):
    """Mark a single notification as read."""
    with engine.begin() as conn:
        result = conn.execute(text(
            "UPDATE notifications SET is_read = TRUE WHERE id = :id RETURNING id"
        ), {"id": notification_id}).fetchone()
        if not result:
            raise HTTPException(status_code=404, detail="Notification not found")
    return {"status": "ok"}


@app.put("/notifications/read-all")
def mark_all_read(email: str = None, department: str = None):
    """Mark all notifications as read for a user or department."""
    if not email and not department:
        raise HTTPException(status_code=400, detail="Provide email or department")
    with engine.begin() as conn:
        if email:
            conn.execute(text(
                "UPDATE notifications SET is_read = TRUE WHERE recipient_email = :e"
            ), {"e": email})
        else:
            conn.execute(text(
                "UPDATE notifications SET is_read = TRUE WHERE department = :d"
            ), {"d": department})
    return {"status": "ok"}


@app.get("/health")
def health():
    return {"status": "ok"}
