"""
Minimal authentication API for users.
- /auth/register  POST {"username","password","role"}
- /auth/login     POST {"username","password"} -> returns JWT

This uses SQLAlchemy to talk to Postgres (DB_URL env var) and PyJWT for tokens.
"""

import os
import sys
import importlib
import asyncio
import json
import re
from fastapi import FastAPI, HTTPException, Depends, Request
from pydantic import BaseModel
from sqlalchemy import create_engine, text
from passlib.context import CryptContext
import jwt
from datetime import datetime, timedelta, timezone
import secrets
import string
from fastapi_mail import FastMail, MessageSchema, ConnectionConfig
from sqlalchemy.exc import SQLAlchemyError
from fastapi import APIRouter, Request, HTTPException
from datetime import datetime, timezone
import pandas as pd
import numpy as np
from sqlalchemy import text
import joblib


# --- AI MODEL LOADING ---
BASE_DIR = os.path.dirname(os.path.abspath(__file__)) 
MODEL_PATH = os.path.join(BASE_DIR, "..", "models", "isolation_forest_model.pkl")
FEATURES_PATH = os.path.join(BASE_DIR, "..", "models", "model_features.pkl")

# Initialize these variables so the functions can see them
model = None
model_features = None

try:
    if os.path.exists(MODEL_PATH):
        model = joblib.load(MODEL_PATH)
        model_features = joblib.load(FEATURES_PATH)
        print("[OK] Anomaly Detection Model Loaded Successfully")
except Exception as e:
    print(f"[ERROR] Error loading AI model: {e}")
def _load_cfg():
    """Load config module handling both package and script execution."""
    if __package__:
        from . import config
        return config
    else:
        sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
        return importlib.import_module("config")

def _load_activity_logger():
    """Load activity logger module."""
    if __package__:
        from . import activity_logger
        return activity_logger
    else:
        sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
        return importlib.import_module("activity_logger")

cfg = _load_cfg()
activity_logger = _load_activity_logger()

OTP_TTL_MINUTES = 5
OTP_LENGTH = 6
app = FastAPI(title="Auth Service")

# Load configuration from environment/.env and enforce PostgreSQL
DB_URL = cfg.get_db_url()
JWT_SECRET = cfg.get_jwt_secret()
JWT_ALG = "HS256"
# Use PBKDF2-SHA256 for hashing to avoid bcrypt binary issues in some environments
PWD_CTX = CryptContext(schemes=["pbkdf2_sha256"], deprecated="auto")

engine = create_engine(DB_URL)

# ── Load anomaly alert service for in-app notifications ───────────────────────
def _load_anomaly_alert_service():
    """Direct file-based load — bypasses __init__.py completely."""
    import importlib.util as _ilu
    _here = os.path.dirname(os.path.abspath(__file__))
    _fp   = os.path.join(_here, "anomaly_alert_service.py")
    _spec = _ilu.spec_from_file_location("anomaly_alert_service", _fp)
    _mod  = _ilu.module_from_spec(_spec)
    sys.modules.setdefault("anomaly_alert_service", _mod)
    _spec.loader.exec_module(_mod)
    return _mod

try:
    _alert_svc = _load_anomaly_alert_service()
    print("[auth_api] anomaly_alert_service loaded [OK]")
except Exception as _e:
    _alert_svc = None
    print(f"[auth_api] anomaly_alert_service not available: {_e}")


def _load_alert_mail_service():
    import importlib.util as _ilu
    _here = os.path.dirname(os.path.abspath(__file__))
    _fp = os.path.join(_here, "alert_mail_service.py")
    _spec = _ilu.spec_from_file_location("alert_mail_service", _fp)
    _mod = _ilu.module_from_spec(_spec)
    sys.modules.setdefault("alert_mail_service", _mod)
    _spec.loader.exec_module(_mod)
    return _mod


try:
    _mail_mod = _load_alert_mail_service()
    _invite_mailer = _mail_mod.AlertMailService()
    print("[auth_api] alert_mail_service loaded [OK]")
except Exception as _e:
    _invite_mailer = None
    print(f"[auth_api] alert_mail_service not available: {_e}")


# Ensure password reset table exists (idempotent)
def _init_password_reset_table():
    try:
        with engine.begin() as conn:
            conn.execute(text(
                """
                CREATE TABLE IF NOT EXISTS password_resets (
                    username TEXT PRIMARY KEY,
                    otp_hash TEXT NOT NULL,
                    expires_at TIMESTAMPTZ NOT NULL
                )
                """
            ))
    except SQLAlchemyError as exc:  # noqa: BLE001
        raise RuntimeError(f"Failed to ensure password_resets table: {exc}") from exc


_init_password_reset_table()


def _ensure_rooms_department_column():
    """Ensure legacy databases have rooms.department column required by department filters."""
    try:
        with engine.begin() as conn:
            conn.execute(text("ALTER TABLE rooms ADD COLUMN IF NOT EXISTS department TEXT"))
    except SQLAlchemyError as exc:  # noqa: BLE001
        print(f"Warning: could not ensure rooms.department column: {exc}")


def _ensure_sensor_data_occupancy_column():
    """Ensure sensor_data table has occupancy column for AI processing."""
    try:
        with engine.begin() as conn:
            conn.execute(text("ALTER TABLE sensor_data ADD COLUMN IF NOT EXISTS occupancy INTEGER"))
    except SQLAlchemyError as exc:  # noqa: BLE001
        print(f"Warning: could not ensure sensor_data.occupancy column: {exc}")


def _ensure_sensor_data_frequency_column():
    """Ensure legacy databases have sensor_data.frequency for incoming ESP payloads."""
    try:
        with engine.begin() as conn:
            conn.execute(text("ALTER TABLE sensor_data ADD COLUMN IF NOT EXISTS frequency DOUBLE PRECISION"))
    except SQLAlchemyError as exc:  # noqa: BLE001
        print(f"Warning: could not ensure sensor_data.frequency column: {exc}")


def _ensure_rooms_threshold_range_columns():
    """Ensure rooms table has lower/upper threshold columns for range-based alerts."""
    try:
        with engine.begin() as conn:
            conn.execute(text("ALTER TABLE rooms ADD COLUMN IF NOT EXISTS threshold DOUBLE PRECISION"))
            conn.execute(text("ALTER TABLE rooms ADD COLUMN IF NOT EXISTS lower_threshold DOUBLE PRECISION"))
            conn.execute(text("ALTER TABLE rooms ADD COLUMN IF NOT EXISTS upper_threshold DOUBLE PRECISION"))
            conn.execute(text("""
                UPDATE rooms
                SET lower_threshold = COALESCE(lower_threshold, GREATEST(COALESCE(threshold, 3.0) * 0.8, 0.1)),
                    upper_threshold = COALESCE(upper_threshold, GREATEST(COALESCE(threshold, 3.0), 0.2))
            """))
            conn.execute(text("""
                UPDATE rooms
                SET upper_threshold = GREATEST(upper_threshold, lower_threshold + 0.1)
                WHERE lower_threshold IS NOT NULL AND upper_threshold IS NOT NULL
            """))
            conn.execute(text("UPDATE rooms SET threshold = upper_threshold WHERE upper_threshold IS NOT NULL"))
    except SQLAlchemyError as exc:  # noqa: BLE001
        print(f"Warning: could not ensure rooms threshold range columns: {exc}")


_ensure_rooms_department_column()
_ensure_sensor_data_occupancy_column()
_ensure_sensor_data_frequency_column()
_ensure_rooms_threshold_range_columns()

MAX_CLASS_REPS_PER_ROOM = 3
MAX_COORDINATORS_PER_DEPARTMENT = 3


def _ensure_proxy_user_columns():
    """Ensure proxy-account metadata exists for class reps/coordinators."""
    try:
        with engine.begin() as conn:
            conn.execute(text("ALTER TABLE class_representatives ADD COLUMN IF NOT EXISTS is_proxy BOOLEAN NOT NULL DEFAULT FALSE"))
            conn.execute(text("ALTER TABLE class_representatives ADD COLUMN IF NOT EXISTS proxy_for_email TEXT"))
            conn.execute(text("ALTER TABLE class_representatives ADD COLUMN IF NOT EXISTS assigned_room_id TEXT"))

            conn.execute(text("ALTER TABLE coordinators ADD COLUMN IF NOT EXISTS is_proxy BOOLEAN NOT NULL DEFAULT FALSE"))
            conn.execute(text("ALTER TABLE coordinators ADD COLUMN IF NOT EXISTS proxy_for_email TEXT"))
            conn.execute(text("ALTER TABLE coordinators ADD COLUMN IF NOT EXISTS assigned_room_id TEXT"))
    except SQLAlchemyError as exc:  # noqa: BLE001
        print(f"Warning: could not ensure proxy columns: {exc}")


_ensure_proxy_user_columns()


def _ensure_class_rep_room_mapping_table():
    """Ensure room->class rep mapping exists for class-specific notifications."""
    try:
        with engine.begin() as conn:
            conn.execute(text("""
                CREATE TABLE IF NOT EXISTS class_rep_room_mapping (
                    id               SERIAL PRIMARY KEY,
                    room_id          TEXT NOT NULL,
                    class_rep_email  TEXT NOT NULL,
                    is_active        BOOLEAN NOT NULL DEFAULT TRUE,
                    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                    UNIQUE(room_id, class_rep_email)
                )
            """))
            conn.execute(text(
                "CREATE INDEX IF NOT EXISTS idx_crrm_room_active ON class_rep_room_mapping(room_id, is_active)"
            ))
    except SQLAlchemyError as exc:  # noqa: BLE001
        print(f"Warning: could not ensure class_rep_room_mapping table: {exc}")


_ensure_class_rep_room_mapping_table()


class ClassRepRoomAssignRequest(BaseModel):
    room_id: str
    class_rep_email: str


@app.post("/rooms/assign-class-rep")
def assign_class_rep_to_room(req: ClassRepRoomAssignRequest):
    room_id = req.room_id.strip()
    class_rep_email = req.class_rep_email.strip()
    if not room_id or not class_rep_email:
        raise HTTPException(status_code=400, detail="room_id and class_rep_email are required")

    with engine.begin() as conn:
        resolved_room_id = _resolve_room_id_for_device(conn, room_id)
        if resolved_room_id:
            room_id = resolved_room_id

        room_exists = conn.execute(
            text("""
                SELECT 1
                FROM (
                    SELECT room_id FROM rooms WHERE UPPER(room_id) = UPPER(:rid)
                    UNION ALL
                    SELECT room_id FROM room_relay_mapping WHERE UPPER(room_id) = UPPER(:rid) OR UPPER(relay_device_id) = UPPER(:rid)
                ) x
                LIMIT 1
            """),
            {"rid": room_id},
        ).fetchone()
        if not room_exists:
            raise HTTPException(status_code=404, detail=f"Room not found: {room_id}")

        rep_exists = conn.execute(
            text("SELECT 1 FROM class_representatives WHERE UPPER(email)=UPPER(:e) LIMIT 1"),
            {"e": class_rep_email},
        ).fetchone()
        if not rep_exists:
            raise HTTPException(status_code=404, detail=f"Class representative not found: {class_rep_email}")

        active_count = conn.execute(
            text("""
                SELECT COUNT(*)
                FROM class_rep_room_mapping
                WHERE UPPER(room_id) = UPPER(:rid)
                  AND is_active = TRUE
                  AND UPPER(class_rep_email) <> UPPER(:email)
            """),
            {"rid": room_id, "email": class_rep_email},
        ).scalar() or 0

        if active_count >= MAX_CLASS_REPS_PER_ROOM:
            raise HTTPException(
                status_code=400,
                detail=f"Room {room_id} already has {MAX_CLASS_REPS_PER_ROOM} active class representatives",
            )

        # Keep one active room mapping per class representative.
        conn.execute(
            text("UPDATE class_rep_room_mapping SET is_active = FALSE WHERE UPPER(class_rep_email)=UPPER(:email)"),
            {"email": class_rep_email},
        )

        conn.execute(text("""
            INSERT INTO class_rep_room_mapping (room_id, class_rep_email, is_active)
            VALUES (:rid, :email, TRUE)
            ON CONFLICT (room_id, class_rep_email)
            DO UPDATE SET is_active = TRUE, created_at = NOW()
        """), {"rid": room_id, "email": class_rep_email})

        conn.execute(
            text("UPDATE class_representatives SET assigned_room_id = :rid WHERE UPPER(email)=UPPER(:email)"),
            {"rid": room_id, "email": class_rep_email},
        )

    return {
        "status": "success",
        "room_id": room_id,
        "class_rep_email": class_rep_email,
        "message": "Class representative mapping updated",
    }


@app.get("/rooms/connected-assignable")
def get_connected_assignable_rooms(department: str = None, active_window_minutes: int = 15):
    """Return rooms that have both active relay heartbeat and recent sensor data."""
    window = max(1, min(active_window_minutes, 60))
    window_interval = f"{window} minutes"

    with engine.connect() as conn:
        where_parts = [
            "s.last_sensor_at >= NOW() - CAST(:window AS INTERVAL)",
            "rs.last_relay_at >= NOW() - CAST(:window AS INTERVAL)",
        ]
        params = {"window": window_interval}

        if department and not _is_admin_department(department):
            where_parts.append("COALESCE(NULLIF(TRIM(UPPER(r.department)), ''), CASE WHEN UPPER(split_part(m.room_id, '-', 1)) = 'CS' THEN 'CSE' ELSE UPPER(split_part(m.room_id, '-', 1)) END) = UPPER(:department)")
            params["department"] = department

        where_sql = " AND ".join(where_parts)

        rows = conn.execute(text(f"""
            WITH relay_last AS (
                SELECT m.room_id, MAX(rs.last_updated) AS last_relay_at
                FROM room_relay_mapping m
                LEFT JOIN relay_states rs
                    ON rs.device_id = m.room_id
                    OR rs.device_id = m.relay_device_id
                GROUP BY m.room_id
            ),
            rep_counts AS (
                SELECT room_id, COUNT(*) AS active_rep_count
                FROM class_rep_room_mapping
                WHERE is_active = TRUE
                GROUP BY room_id
            )
            SELECT
                m.room_id,
                COALESCE(NULLIF(TRIM(r.room_name), ''), m.room_id) AS room_name,
                COALESCE(NULLIF(TRIM(UPPER(r.department)), ''), CASE WHEN UPPER(split_part(m.room_id, '-', 1)) = 'CS' THEN 'CSE' ELSE UPPER(split_part(m.room_id, '-', 1)) END) AS department,
                m.relay_device_id,
                s.last_sensor_at,
                rs.last_relay_at,
                COALESCE(rc.active_rep_count, 0) AS active_rep_count
            FROM room_relay_mapping m
            LEFT JOIN rooms r ON UPPER(r.room_id) = UPPER(m.room_id)
            JOIN LATERAL (
                SELECT MAX(sd.ds) AS last_sensor_at
                FROM sensor_data sd
                WHERE UPPER(sd.device_id) = UPPER(m.room_id)
                   OR UPPER(sd.device_id) = UPPER(m.relay_device_id)
                   OR UPPER(sd.device_id) = UPPER('ESP32-' || m.room_id)
                   OR UPPER(sd.device_id) = UPPER(
                        CASE
                            WHEN POSITION('-' IN m.room_id) > 0 THEN
                                'ESP32-' || split_part(m.room_id, '-', 1) || '-' ||
                                LEFT(split_part(m.room_id, '-', 1), 1) || split_part(m.room_id, '-', 2)
                            ELSE ''
                        END
                   )
            ) s ON TRUE
            JOIN relay_last rs ON rs.room_id = m.room_id
            LEFT JOIN rep_counts rc ON UPPER(rc.room_id) = UPPER(m.room_id)
            WHERE {where_sql}
            ORDER BY department ASC NULLS LAST, room_name ASC
        """), params).fetchall()

    data = []
    for row in rows:
        active_rep_count = int(row[6] or 0)
        available_slots = max(0, MAX_CLASS_REPS_PER_ROOM - active_rep_count)
        data.append({
            "room_id": row[0],
            "room_name": row[1],
            "department": row[2],
            "relay_device_id": row[3],
            "last_sensor_at": row[4].isoformat() if row[4] else None,
            "last_relay_at": row[5].isoformat() if row[5] else None,
            "active_rep_count": active_rep_count,
            "max_reps": MAX_CLASS_REPS_PER_ROOM,
            "available_slots": available_slots,
            "can_assign_class_rep": available_slots > 0,
        })

    return {"status": "success", "count": len(data), "data": data}


@app.get("/rooms/class-rep-mappings")
def list_class_rep_room_mappings(active_only: bool = True, room_id: str = None):
    with engine.connect() as conn:
        where_parts = []
        params = {}
        if active_only:
            where_parts.append("m.is_active = TRUE")
        if room_id:
            where_parts.append("m.room_id = :rid")
            params["rid"] = room_id
        where_sql = f"WHERE {' AND '.join(where_parts)}" if where_parts else ""

        rows = conn.execute(text(f"""
            SELECT m.id, m.room_id, m.class_rep_email, m.is_active, m.created_at,
                   COALESCE(cr.name, cr.username) AS class_rep_name
            FROM class_rep_room_mapping m
            LEFT JOIN class_representatives cr ON UPPER(cr.email)=UPPER(m.class_rep_email)
            {where_sql}
            ORDER BY m.room_id ASC, m.created_at DESC
        """), params).fetchall()

    data = [
        {
            "id": r[0],
            "room_id": r[1],
            "class_rep_email": r[2],
            "is_active": r[3],
            "created_at": r[4].isoformat() if r[4] else None,
            "class_rep_name": r[5],
        }
        for r in rows
    ]
    return {"status": "success", "count": len(data), "data": data}


def _is_admin_department(department: str | None) -> bool:
    return bool(department and department.strip().lower() == "admin")


def _is_test_identifier(value: str | None) -> bool:
    """Return True when identifier points to test/demo/mock data."""
    token = (value or "").strip().upper()
    if not token:
        return False
    test_markers = ("TEST", "DEMO", "MOCK", "SAMPLE", "DUMMY")
    return any(marker in token for marker in test_markers)


def _build_device_candidates(room_or_device_id: str | None) -> list[str]:
    """Return likely sensor IDs, prioritizing normalized versions."""
    if not room_or_device_id:
        return []

    token = str(room_or_device_id).strip()
    out: list[str] = []

    def _push(value: str | None):
        if not value: return
        v = value.strip()
        if all(v.upper() != existing.upper() for existing in out):
            out.append(v)

    # 1. Try the exact token provided
    _push(token)
    
    # 2. Handle the "ESP32-" prefix by removing it (Normalization Alignment)
    upper_token = token.upper()
    if upper_token.startswith("ESP32-"):
        _push(token[6:]) 

    # 3. Handle the specific Class 201 -> CS-C201 logic
    # This ensures "Floor-2-Class-201" or "Class-201" maps to the new room_name
    if "201" in token:
        _push("CS-C201")
        _push("CS-201")
        _push("ESP32-CS-C201")

    return out

def _resolve_room_id_for_device(conn, room_or_device_id: str | None) -> str | None:
    """Resolve incoming device token to canonical rooms.room_id."""
    candidates = _build_device_candidates(room_or_device_id)
    if not candidates:
        return None

    for candidate in candidates:
        # Check the room_relay_mapping first
        mapped = conn.execute(
            text("""
                SELECT m.room_id 
                FROM room_relay_mapping m 
                WHERE UPPER(m.room_id) = UPPER(:id) 
                   OR UPPER(m.relay_device_id) = UPPER(:id)
                LIMIT 1
            """), {"id": candidate}
        ).fetchone()
        if mapped: return mapped[0]

        # Check the rooms table (where you updated the room_name)
        room = conn.execute(
            text("SELECT room_id FROM rooms WHERE UPPER(room_id)=UPPER(:id) OR UPPER(room_name)=UPPER(:id) LIMIT 1"),
            {"id": candidate}
        ).fetchone()
        if room: return room[0]

    return None

def _normalize_device_id_to_relay_format(conn, raw_device_id: str | None) -> str:
    """
    Normalize incoming device_id to the canonical relay_device_id format (with ESP32- prefix).
    
    Logic:
    1. Build candidates from the raw input (handles both "CS-C201" and "ESP32-CS-C201")
    2. Look up the relay_device_id from room_relay_mapping (authoritative source)
    3. Return the properly formatted device_id (e.g., "ESP32-CS-C201")
    4. Fall back to adding "ESP32-" prefix if no mapping exists
    """
    if not raw_device_id:
        return raw_device_id or "unknown"
    
    candidates = _build_device_candidates(raw_device_id)
    if not candidates:
        # No candidates generated, use raw and ensure ESP32- prefix
        token = str(raw_device_id).strip()
        if not token.upper().startswith("ESP32-"):
            return "ESP32-" + token
        return token
    
    # Look for the relay_device_id in room_relay_mapping
    for candidate in candidates:
        result = conn.execute(
            text("""
                SELECT m.relay_device_id 
                FROM room_relay_mapping m 
                WHERE UPPER(m.room_id) = UPPER(:id) 
                   OR UPPER(m.relay_device_id) = UPPER(:id)
                LIMIT 1
            """), {"id": candidate}
        ).fetchone()
        if result:
            relay_device_id = result[0]
            # Ensure ESP32- prefix
            if relay_device_id and not relay_device_id.upper().startswith("ESP32-"):
                return "ESP32-" + relay_device_id
            return relay_device_id or raw_device_id
    
    # No mapping found, apply ESP32- prefix normalization as fallback
    token = str(raw_device_id).strip()
    if not token.upper().startswith("ESP32-"):
        return "ESP32-" + token
    return token

# Pydantic models

class RegisterRequest(BaseModel):
    username: str
    password: str
    role: str = "student"
    ktu_id: str = None  # Required for student registration
    department: str = None  # Required for student registration
    year: str = None  # Required for student registration
    email: str = None  # Email address for student registration
    phone: str = None  # Phone number for user registration

class InviteUserRequest(BaseModel):
    """Payload for admin invite endpoint.
    Admin generates an OTP server-side, so no password is required.
    """
    username: str
    role: str = "student"
    name: str | None = None
    phone: str | None = None
    ktu_id: str | None = None
    department: str | None = None
    year: str | None = None
    email: str | None = None
    room_id: str | None = None
    is_proxy: bool = False
    proxy_for_email: str | None = None

class LoginRequest(BaseModel):
    username: str
    password: str
    department: str | None = None  # Required for coordinator login

class UpdateProfileRequest(BaseModel):
    ktu_id: str
    name: str
    department: str
    year: str
    phone: str | None = None

class ChangePasswordRequest(BaseModel):
    username: str  # Email or KTU ID
    current_password: str
    new_password: str


class PasswordResetRequest(BaseModel):
    username: str  # Email or KTU ID


class PasswordResetConfirmRequest(BaseModel):
    username: str
    otp: str
    new_password: str





# Use this version of the change-password endpoint
@app.post("/change-password")
async def change_password(req: ChangePasswordRequest):
    """Change password by locating the user in their role-specific table only."""
    with engine.begin() as conn:
        # Try admin by email first
        admin_row = conn.execute(
            text("SELECT id, password_hash, email, name FROM admins WHERE UPPER(email)=UPPER(:u)"),
            {"u": req.username},
        ).fetchone()

        coordinator_row = None
        if not admin_row:
            coordinator_row = conn.execute(
                text("SELECT id, password_hash, email, name FROM coordinators WHERE UPPER(email)=UPPER(:u)"),
                {"u": req.username},
            ).fetchone()

        class_rep_row = None
        if not admin_row and not coordinator_row:
            class_rep_row = conn.execute(
                text("SELECT id, password_hash, email, name FROM class_representatives WHERE UPPER(ktu_id)=UPPER(:u) OR UPPER(email)=UPPER(:u) OR UPPER(username)=UPPER(:u)"),
                {"u": req.username},
            ).fetchone()

        row = admin_row or coordinator_row or class_rep_row
        if not row or not PWD_CTX.verify(req.current_password, row[1]):
            raise HTTPException(status_code=401, detail="Current password is incorrect")

        new_hash = PWD_CTX.hash(req.new_password)
        user_email = row[2]
        user_name = row[3] or user_email

        if admin_row:
            conn.execute(text("UPDATE admins SET password_hash=:p WHERE id=:i"), {"p": new_hash, "i": row[0]})
        elif coordinator_row:
            conn.execute(text("UPDATE coordinators SET password_hash=:p WHERE id=:i"), {"p": new_hash, "i": row[0]})
        elif class_rep_row:
            conn.execute(text("UPDATE class_representatives SET password_hash=:p WHERE id=:i"), {"p": new_hash, "i": row[0]})

    # Send password change confirmation email
    try:
        message = MessageSchema(
            subject="Password Changed Successfully",
            recipients=[user_email],
            body=f"""
                            <html>
                                <body style="font-family: Arial, sans-serif; background-color: #f5f5f5; padding: 20px;">
                                    <div style="background-color: white; border-radius: 8px; padding: 30px; max-width: 600px; margin: 0 auto; box-shadow: 0 2px 4px rgba(0,0,0,0.1);">
                                        <h2 style="color: #333; margin-bottom: 20px;">Password Changed Successfully</h2>
                                        <p style="color: #666; font-size: 14px; line-height: 1.6;">
                                            Hello {user_name},
                                        </p>
                                        <p style="color: #666; font-size: 14px; line-height: 1.6;">
                                            Your password has been successfully changed. If you did not request this change, please contact the administrator immediately.
                                        </p>
                                        <div style="background-color: #e8f4f8; border-left: 4px solid #0066cc; padding: 15px; margin: 20px 0; border-radius: 4px;">
                                            <p style="color: #333; margin: 0; font-size: 14px;">
                                                <strong>For Security:</strong> Keep your password confidential and never share it with anyone. If you suspect unauthorized access, change your password immediately.
                                            </p>
                                        </div>
                                        <p style="color: #999; font-size: 12px; margin-top: 30px; padding-top: 20px; border-top: 1px solid #eee;">
                                            This is an automated message. Please do not reply to this email.
                                        </p>
                                    </div>
                                </body>
                            </html>
                            """,
            subtype="html",
        )
        fm = FastMail(conf)
        await fm.send_message(message)
    except Exception as e:
        print(f"Warning: Failed to send password change email to {user_email}: {e}")
        # Don't fail the password change if email fails

    return {"status": "Password updated successfully"}


@app.post("/request-password-reset")
async def request_password_reset(req: PasswordResetRequest):
    otp = f"{secrets.randbelow(10**OTP_LENGTH):0{OTP_LENGTH}d}"
    otp_hash = PWD_CTX.hash(otp)
    expires_at = datetime.now(timezone.utc) + timedelta(minutes=OTP_TTL_MINUTES)

    with engine.begin() as conn:
        # Look in each role-specific table; stop at first match
        admin_row = conn.execute(
            text("SELECT email FROM admins WHERE UPPER(email)=UPPER(:u)"),
            {"u": req.username},
        ).fetchone()

        coordinator_row = None
        if not admin_row:
            coordinator_row = conn.execute(
                text("SELECT email FROM coordinators WHERE UPPER(email)=UPPER(:u)"),
                {"u": req.username},
            ).fetchone()

        class_rep_row = None
        if not admin_row and not coordinator_row:
            class_rep_row = conn.execute(
                text("SELECT email FROM class_representatives WHERE UPPER(ktu_id)=UPPER(:u) OR UPPER(email)=UPPER(:u) OR UPPER(username)=UPPER(:u)"),
                {"u": req.username},
            ).fetchone()

        match_row = admin_row or coordinator_row or class_rep_row
        if not match_row:
            raise HTTPException(status_code=404, detail="User not found")

        email = match_row[0] or req.username

        conn.execute(
            text(
                """
                INSERT INTO password_resets (username, otp_hash, expires_at)
                VALUES (:u, :h, :e)
                ON CONFLICT (username)
                DO UPDATE SET otp_hash = EXCLUDED.otp_hash, expires_at = EXCLUDED.expires_at
                """
            ),
            {"u": req.username, "h": otp_hash, "e": expires_at},
        )

    try:
        await _send_reset_email(email, otp)
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(status_code=500, detail=f"Failed to send OTP email: {exc}") from exc

    return {"status": "otp_sent", "expires_in_minutes": OTP_TTL_MINUTES}


@app.post("/confirm-password-reset")
def confirm_password_reset(req: PasswordResetConfirmRequest):
    now = datetime.now(timezone.utc)
    with engine.begin() as conn:
        row = conn.execute(
            text(
                "SELECT otp_hash, expires_at FROM password_resets WHERE username = :u"
            ),
            {"u": req.username},
        ).fetchone()

        if not row:
            raise HTTPException(status_code=400, detail="No active reset request. Please request a new OTP.")

        otp_hash, expires_at = row
        # Normalize to UTC to avoid naive/aware comparison issues
        if expires_at.tzinfo is None:
            expires_at = expires_at.replace(tzinfo=timezone.utc)
        else:
            expires_at = expires_at.astimezone(timezone.utc)
        if expires_at < now:
            conn.execute(text("DELETE FROM password_resets WHERE username = :u"), {"u": req.username})
            raise HTTPException(status_code=400, detail="OTP expired. Request a new one.")

        if not PWD_CTX.verify(req.otp, otp_hash):
            raise HTTPException(status_code=401, detail="Invalid OTP")

        new_hash = PWD_CTX.hash(req.new_password)

        admin_row = conn.execute(
            text("SELECT id FROM admins WHERE UPPER(email)=UPPER(:u)"),
            {"u": req.username},
        ).fetchone()
        coordinator_row = None
        if not admin_row:
            coordinator_row = conn.execute(
                text("SELECT id FROM coordinators WHERE UPPER(email)=UPPER(:u)"),
                {"u": req.username},
            ).fetchone()
        class_rep_row = None
        if not admin_row and not coordinator_row:
            class_rep_row = conn.execute(
                text("SELECT id FROM class_representatives WHERE UPPER(ktu_id)=UPPER(:u) OR UPPER(email)=UPPER(:u) OR UPPER(username)=UPPER(:u)"),
                {"u": req.username},
            ).fetchone()

        if admin_row:
            conn.execute(text("UPDATE admins SET password_hash=:p WHERE id=:i"), {"p": new_hash, "i": admin_row[0]})
        elif coordinator_row:
            conn.execute(text("UPDATE coordinators SET password_hash=:p WHERE id=:i"), {"p": new_hash, "i": coordinator_row[0]})
        elif class_rep_row:
            conn.execute(text("UPDATE class_representatives SET password_hash=:p WHERE id=:i"), {"p": new_hash, "i": class_rep_row[0]})
        else:
            raise HTTPException(status_code=404, detail="User not found")

        conn.execute(text("DELETE FROM password_resets WHERE username = :u"), {"u": req.username})

    return {"status": "password_reset", "message": "Password updated successfully"}
@app.post("/update-profile")
def update_profile(req: UpdateProfileRequest):
    with engine.begin() as conn:
        # Update the student record based on KTU ID
        conn.execute(
            text("UPDATE class_representatives SET name = :n, department = :d, year = :y, phone = :phone WHERE ktu_id = :k"),
            {"n": req.name, "d": req.department, "y": req.year, "phone": (req.phone or "").strip() or None, "k": req.ktu_id}
        )

        # Fetch the updated record to issue a refreshed token so UI updates immediately
        res = conn.execute(
            text("SELECT id, department, ktu_id, year, username, name FROM class_representatives WHERE ktu_id = :k"),
            {"k": req.ktu_id}
        ).fetchone()
        if not res:
            raise HTTPException(status_code=404, detail="Class representative not found")

        u_id, dept, ktu, year, email, name = res

    payload = {
        "sub": str(u_id),
        "username": email,
        "name": name,
        "role": "student",
        "department": dept,
        "ktu_id": ktu,
        "year": year,
        "exp": datetime.utcnow() + timedelta(hours=12),
    }
    token = jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALG)
    return {"status": "Profile updated successfully", "access_token": token, "token_type": "bearer"}

# Build email config from environment variables via config module
_m = cfg.get_mail_settings()
conf = ConnectionConfig(
    MAIL_USERNAME=_m.username,
    MAIL_PASSWORD=_m.password,
    MAIL_FROM=_m.from_addr,
    MAIL_PORT=_m.port,
    MAIL_SERVER=_m.server,
    MAIL_STARTTLS=_m.starttls,
    MAIL_SSL_TLS=_m.ssl_tls,
    USE_CREDENTIALS=_m.use_credentials,
)


# Email templates for different user roles
def _get_invite_email_template(role: str, username: str, password: str, name: str, coordinator_id: str = None) -> tuple[str, str]:
    """Return (subject, body) email template based on user role."""
    role_lower = role.lower()
    
    if "student" in role_lower or "representative" in role_lower:
        # Class Representative email
        subject = "ENERGIA - Class Representative Access Credentials"
        body = f"""
        <html>
            <body style="font-family: Arial, sans-serif; line-height: 1.6;">
                <h2 style="color: #333;">Welcome to ENERGIA, {name}!</h2>
                <p>You have been registered as a <strong>Class Representative</strong> in the ENERGIA system.</p>
                
                <h3 style="color: #0066cc;">Your Login Credentials</h3>
                <p style="background-color: #f5f5f5; padding: 15px; border-left: 4px solid #0066cc;">
                    <strong>Username (KTU ID):</strong> {username}<br/>
                    <strong>Password:</strong> {password}
                </p>
                
                <h3 style="color: #0066cc;">Your Responsibilities</h3>
                <ul>
                    <li>Monitor and report sensor data from your classroom</li>
                    <li>Ensure timely submission of anomaly reports</li>
                    <li>Coordinate with your department coordinators</li>
                </ul>
                
                <h3 style="color: #0066cc;">Next Steps</h3>
                <ol>
                    <li>Log in to the ENERGIA application using your credentials</li>
                    <li>Update your profile with current contact information</li>
                    <li>Change your password to a secure one upon first login</li>
                </ol>
                
                <p style="color: #666; font-size: 0.9em;">
                    <strong>Security Note:</strong> Do not share your credentials with anyone. 
                    If you believe your account has been compromised, contact your administrator immediately.
                </p>
                
                <hr/>
                <p style="color: #999; font-size: 0.85em;">
                    ENERGIA System - Energy Monitoring & Anomaly Detection<br/>
                    If you have any issues accessing your account, please contact your administrator.
                </p>
            </body>
        </html>
        """
    else:
        # Coordinator email
        subject = "ENERGIA - Coordinator Access Credentials"
        body = f"""
        <html>
            <body style="font-family: Arial, sans-serif; line-height: 1.6;">
                <h2 style="color: #333;">Welcome to ENERGIA, {name}!</h2>
                <p>You have been registered as a <strong>Coordinator</strong> in the ENERGIA system.</p>
                
                <h3 style="color: #006633;">Your Login Credentials</h3>
                <p style="background-color: #f5f5f5; padding: 15px; border-left: 4px solid #006633;">
                    <strong>Coordinator ID:</strong> {coordinator_id}<br/>
                    <strong>Password:</strong> {password}
                </p>
                
                <h3 style="color: #006633;">Your Responsibilities</h3>
                <ul>
                    <li>Oversee class representative performance and submissions</li>
                    <li>Review and validate anomaly detection reports</li>
                    <li>Generate departmental analytics and insights</li>
                    <li>Manage user accounts within your department</li>
                </ul>
                
                <h3 style="color: #006633;">Access Features</h3>
                <ul>
                    <li>Department dashboard with real-time data analytics</li>
                    <li>Class-wise sensor data and anomaly reports</li>
                    <li>User management and credential administration</li>
                    <li>Export reports and insights</li>
                </ul>
                
                <h3 style="color: #006633;">Getting Started</h3>
                <ol>
                    <li>Log in to the ENERGIA application using your Coordinator ID and password</li>
                    <li>Update your profile with contact information</li>
                    <li>Change your password to a secure one upon first login</li>
                    <li>Review the coordinator dashboard and available reports</li>
                </ol>
                
                <p style="color: #666; font-size: 0.9em;">
                    <strong>Security Note:</strong> Keep your credentials confidential. 
                    As a coordinator, you have elevated access to department data.
                </p>
                
                <hr/>
                <p style="color: #999; font-size: 0.85em;">
                    ENERGIA System - Energy Monitoring & Anomaly Detection<br/>
                    If you have any issues accessing your account, please contact the system administrator.
                </p>
            </body>
        </html>
        """
    
    return subject, body


def _send_reset_email(email: str, otp: str):
        """Send a 5-minute OTP to the user's registered email."""
        message = MessageSchema(
                subject="ENERGIA - Password Reset OTP",
                recipients=[email],
                body=(
                        f"""
                        <html>
                            <body style='font-family: Arial, sans-serif;'>
                                <h3>Password Reset Request</h3>
                                <p>Your one-time password (OTP) to reset your ENERGIA account is:</p>
                                <p style='font-size: 20px; font-weight: bold;'>{otp}</p>
                                <p>This code is valid for {OTP_TTL_MINUTES} minutes.</p>
                                <p>If you did not request this, please ignore this email.</p>
                            </body>
                        </html>
                        """
                ),
                subtype="html",
        )
        fm = FastMail(conf)
        # Let exceptions propagate to caller; they will be surfaced as HTTP errors
        return fm.send_message(message)

@app.post("/admin/invite-user")
async def invite_user(req: InviteUserRequest):
    """Invite a new user (class representative or coordinator) with auto-generated OTP.
    
    Saves credentials to appropriate DB table and sends personalized welcome email
    with login credentials and role-specific instructions.
    """
    # Generate a secure temporary password (6 chars, letters+digits+symbol)
    otp = _generate_short_password(6)
    pw_hash = PWD_CTX.hash(otp)
    role_lower = req.role.lower()
    target_table = "class_representatives" if ("student" in role_lower or "representative" in role_lower) else ("coordinators" if "coordinator" in role_lower else "admins")
    is_proxy = bool(req.is_proxy)
    proxy_for_email = (req.proxy_for_email or "").strip() or None
    room_id = (req.room_id or "").strip() or None

    # Normalize email field
    target_email = req.email or req.username
    if target_table in {"coordinators", "admins"} and not target_email:
        raise HTTPException(status_code=400, detail="Email is required for admins and coordinators")
    if target_table == "coordinators" and not (req.department or "").strip():
        raise HTTPException(status_code=400, detail="Department is required for coordinators")
    if target_table == "class_representatives" and not room_id:
        raise HTTPException(status_code=400, detail="Room selection is required for class representatives")
    if is_proxy and not proxy_for_email:
        raise HTTPException(status_code=400, detail="proxy_for_email is required when is_proxy is true")

    coordinator_id = None

    with engine.begin() as conn:
        resolved_room_id = _resolve_room_id_for_device(conn, room_id) if room_id else None
        if resolved_room_id:
            room_id = resolved_room_id

        if target_table == "class_representatives":
            room_row = conn.execute(
                text("""
                    SELECT x.room_id, x.department
                    FROM (
                        SELECT room_id, department
                        FROM rooms
                        WHERE UPPER(room_id) = UPPER(:rid)

                        UNION ALL

                        SELECT m.room_id,
                               CASE
                                   WHEN UPPER(split_part(m.room_id, '-', 1)) = 'CS' THEN 'CSE'
                                   ELSE UPPER(split_part(m.room_id, '-', 1))
                               END AS department
                        FROM room_relay_mapping m
                        WHERE UPPER(m.room_id) = UPPER(:rid)
                           OR UPPER(m.relay_device_id) = UPPER(:rid)
                    ) x
                    LIMIT 1
                """),
                {"rid": room_id},
            ).fetchone()
            if not room_row:
                raise HTTPException(status_code=404, detail=f"Room not found: {room_id}")

            room_department = (room_row[1] or "").strip().upper()
            if req.department and room_department and req.department.strip().upper() != room_department:
                raise HTTPException(
                    status_code=400,
                    detail=f"Department {req.department} does not match room department {room_department}",
                )

            if is_proxy:
                base_rep = conn.execute(text("""
                    SELECT email, department, assigned_room_id
                    FROM class_representatives
                    WHERE UPPER(email)=UPPER(:email)
                    LIMIT 1
                """), {"email": proxy_for_email}).fetchone()
                if not base_rep:
                    raise HTTPException(status_code=404, detail=f"Primary class representative not found: {proxy_for_email}")

                base_dept = (base_rep[1] or "").strip().upper()
                if req.department and base_dept and req.department.strip().upper() != base_dept:
                    raise HTTPException(status_code=400, detail="Proxy class representative must match the primary representative department")

                base_room = (base_rep[2] or "").strip()
                if base_room and room_id and room_id.strip().upper() != base_room.upper():
                    raise HTTPException(status_code=400, detail="Proxy class representative must be assigned to the same room as the primary representative")

            active_rep_count = conn.execute(text("""
                SELECT COUNT(*)
                FROM class_rep_room_mapping
                WHERE UPPER(room_id) = UPPER(:rid)
                  AND is_active = TRUE
                  AND UPPER(class_rep_email) <> UPPER(:email)
            """), {"rid": room_id, "email": target_email}).scalar() or 0
            if active_rep_count >= MAX_CLASS_REPS_PER_ROOM:
                raise HTTPException(
                    status_code=400,
                    detail=f"Cannot add more than {MAX_CLASS_REPS_PER_ROOM} class representatives to room {room_id}",
                )

        if target_table == "coordinators" and is_proxy:
            base_coord = conn.execute(text("""
                SELECT email, department
                FROM coordinators
                WHERE UPPER(email)=UPPER(:email)
                LIMIT 1
            """), {"email": proxy_for_email}).fetchone()
            if not base_coord:
                raise HTTPException(status_code=404, detail=f"Primary coordinator not found: {proxy_for_email}")

            if req.department and (base_coord[1] or "").strip().upper() != req.department.strip().upper():
                raise HTTPException(status_code=400, detail="Proxy coordinator must match the primary coordinator department")

        if target_table == "coordinators":
            active_coord_count = conn.execute(text("""
                SELECT COUNT(*)
                FROM coordinators
                WHERE UPPER(department) = UPPER(:department)
                  AND UPPER(email) <> UPPER(:email)
            """), {
                "department": (req.department or "").strip(),
                "email": target_email,
            }).scalar() or 0
            if active_coord_count >= MAX_COORDINATORS_PER_DEPARTMENT:
                raise HTTPException(
                    status_code=400,
                    detail=f"Cannot add more than {MAX_COORDINATORS_PER_DEPARTMENT} coordinators to department {(req.department or '').strip().upper()}",
                )

        if target_table == "coordinators" and room_id:
            coord_room = conn.execute(
                text("""
                    SELECT x.room_id, x.department
                    FROM (
                        SELECT room_id, department
                        FROM rooms
                        WHERE UPPER(room_id) = UPPER(:rid)

                        UNION ALL

                        SELECT m.room_id,
                               CASE
                                   WHEN UPPER(split_part(m.room_id, '-', 1)) = 'CS' THEN 'CSE'
                                   ELSE UPPER(split_part(m.room_id, '-', 1))
                               END AS department
                        FROM room_relay_mapping m
                        WHERE UPPER(m.room_id) = UPPER(:rid)
                           OR UPPER(m.relay_device_id) = UPPER(:rid)
                    ) x
                    LIMIT 1
                """),
                {"rid": room_id},
            ).fetchone()
            if not coord_room:
                raise HTTPException(status_code=404, detail=f"Room not found: {room_id}")
            coord_room_dept = (coord_room[1] or "").strip().upper()
            if req.department and coord_room_dept and req.department.strip().upper() != coord_room_dept:
                raise HTTPException(
                    status_code=400,
                    detail=f"Department {req.department} does not match room department {coord_room_dept}",
                )

        # Check if user already exists in the chosen table
        existing = conn.execute(
            text(f"SELECT id FROM {target_table} WHERE { 'username' if target_table == 'class_representatives' else 'email' } = :u"),
            {"u": req.username if target_table == "class_representatives" else target_email},
        ).fetchone()

        if existing:
            if target_table == "class_representatives":
                query = text("""
                    UPDATE class_representatives
                    SET password_hash=:p, name=:n, department=:d, ktu_id=:k, year=:y,
                        email=:e, phone=:phone, is_proxy=:is_proxy, proxy_for_email=:proxy_for_email,
                        assigned_room_id=:assigned_room_id
                    WHERE id=:i
                """)
                params = {
                    "p": pw_hash,
                    "n": req.name,
                    "d": req.department,
                    "k": req.ktu_id,
                    "y": req.year,
                    "e": target_email,
                    "phone": (req.phone or "").strip() or None,
                    "is_proxy": is_proxy,
                    "proxy_for_email": proxy_for_email,
                    "assigned_room_id": room_id,
                    "i": existing[0],
                }
            elif target_table == "coordinators":
                # Fetch existing coordinator_id so email never shows None
                coordinator_id_row = conn.execute(
                    text("SELECT coordinator_id FROM coordinators WHERE id = :i"),
                    {"i": existing[0]}
                ).fetchone()
                coordinator_id = coordinator_id_row[0] if coordinator_id_row else None

                query = text("""
                    UPDATE coordinators
                    SET password_hash=:p, name=:n, department=:d, email=:e, phone=:phone,
                        is_proxy=:is_proxy, proxy_for_email=:proxy_for_email,
                        assigned_room_id=:assigned_room_id
                    WHERE id=:i
                """)
                params = {
                    "p": pw_hash,
                    "n": req.name,
                    "d": req.department,
                    "e": target_email,
                    "phone": (req.phone or "").strip() or None,
                    "is_proxy": is_proxy,
                    "proxy_for_email": proxy_for_email,
                    "assigned_room_id": room_id,
                    "i": existing[0],
                }
            else:  # admins
                query = text("UPDATE admins SET password_hash=:p, name=:n, email=:e, phone=:phone WHERE id=:i")
                params = {"p": pw_hash, "n": req.name, "e": target_email, "phone": (req.phone or "").strip() or None, "i": existing[0]}
            action = "updated"
        else:
            if target_table == "class_representatives":
                query = text(
                    "INSERT INTO class_representatives (username, password_hash, name, department, ktu_id, year, email, phone, is_proxy, proxy_for_email, assigned_room_id, created_at) "
                    "VALUES (:u, :p, :n, :d, :k, :y, :e, :phone, :is_proxy, :proxy_for_email, :assigned_room_id, :c)"
                )
                params = {
                    "u": req.username,
                    "p": pw_hash,
                    "n": req.name,
                    "d": req.department,
                    "k": req.ktu_id,
                    "y": req.year,
                    "e": target_email,
                    "phone": (req.phone or "").strip() or None,
                    "is_proxy": is_proxy,
                    "proxy_for_email": proxy_for_email,
                    "assigned_room_id": room_id,
                    "c": datetime.utcnow(),
                }
            elif target_table == "coordinators":
                # Generate unique coordinator ID by finding the next available number
                dept_prefix = f"C{req.department[:2].upper()}"
                
                # Get all existing coordinator IDs for this department
                existing_ids = conn.execute(
                    text("SELECT coordinator_id FROM coordinators WHERE coordinator_id LIKE :prefix ORDER BY coordinator_id"),
                    {"prefix": f"{dept_prefix}%"},
                ).fetchall()
                
                # Extract numbers from existing IDs and find the next available number
                existing_numbers = []
                for (cid,) in existing_ids:
                    try:
                        num = int(cid[len(dept_prefix):])
                        existing_numbers.append(num)
                    except (ValueError, IndexError):
                        continue
                
                # Find the next available number
                next_num = 1
                while next_num in existing_numbers:
                    next_num += 1
                
                coordinator_id = f"{dept_prefix}{next_num:03d}"
                
                query = text(
                    "INSERT INTO coordinators (coordinator_id, email, password_hash, name, department, phone, is_proxy, proxy_for_email, assigned_room_id, created_at) "
                    "VALUES (:cid, :e, :p, :n, :d, :phone, :is_proxy, :proxy_for_email, :assigned_room_id, :c)"
                )
                params = {
                    "cid": coordinator_id,
                    "e": target_email,
                    "p": pw_hash,
                    "n": req.name,
                    "d": req.department,
                    "phone": (req.phone or "").strip() or None,
                    "is_proxy": is_proxy,
                    "proxy_for_email": proxy_for_email,
                    "assigned_room_id": room_id,
                    "c": datetime.utcnow(),
                }
            else:  # admins
                query = text(
                    "INSERT INTO admins (email, password_hash, name, phone, created_at) "
                    "VALUES (:e, :p, :n, :phone, :c)"
                )
                params = {
                    "e": target_email,
                    "p": pw_hash,
                    "n": req.name,
                    "phone": (req.phone or "").strip() or None,
                    "c": datetime.utcnow(),
                }
            action = "created"

        try:
            conn.execute(query, params)
            if target_table == "class_representatives" and room_id:
                # Keep one active room per class representative and max 3 active reps per room.
                conn.execute(
                    text("UPDATE class_rep_room_mapping SET is_active = FALSE WHERE UPPER(class_rep_email)=UPPER(:email)"),
                    {"email": target_email},
                )
                conn.execute(text("""
                    INSERT INTO class_rep_room_mapping (room_id, class_rep_email, is_active)
                    VALUES (:rid, :email, TRUE)
                    ON CONFLICT (room_id, class_rep_email)
                    DO UPDATE SET is_active = TRUE, created_at = NOW()
                """), {"rid": room_id, "email": target_email})
        except SQLAlchemyError as e:
            # Handle database errors, especially unique constraint violations
            error_msg = str(e.orig) if hasattr(e, 'orig') else str(e)
            if "duplicate key" in error_msg.lower() or "unique constraint" in error_msg.lower():
                raise HTTPException(
                    status_code=409,
                    detail=f"User with this identifier already exists. Please try again or contact support."
                )
            else:
                raise HTTPException(
                    status_code=500,
                    detail=f"Database error: {error_msg}"
                )
    
    # Prepare role-specific email
    # For class representatives, show KTU ID as the username in the email
    display_username = req.username
    if "student" in role_lower or "representative" in role_lower:
        display_username = req.ktu_id or req.username
    elif "coordinator" in role_lower:
        display_username = target_email
    else:
        display_username = target_email
    subject, email_body = _get_invite_email_template(
        role=req.role,
        username=display_username,
        password=otp,
        name=req.name or "User",
        coordinator_id=coordinator_id
    )
    
    # Send email with credentials
    try:
        message = MessageSchema(
            subject=subject,
            recipients=[target_email],
            body=email_body,
            subtype="html"
        )
        fm = FastMail(conf)
        await asyncio.wait_for(fm.send_message(message), timeout=30.0)  # 10 second timeout
        email_status = "sent"
    except asyncio.TimeoutError:
        print(f"Warning: Email send timed out for {req.username}")
        email_status = "failed"
    except Exception as e:
        # FastMail failed; try dedicated SMTP sender before marking failed.
        print(f"Warning: Failed to send email to {req.username}: {e}")
        fallback_sent = False
        if _invite_mailer and _invite_mailer.is_configured():
            try:
                _invite_mailer.send_html_email(
                    subject=subject,
                    html_body=email_body,
                    recipients=[target_email],
                )
                fallback_sent = True
                print(f"Info: Fallback invite email sent to {target_email}")
            except Exception as fallback_err:
                print(f"Warning: Fallback invite email failed for {target_email}: {fallback_err}")

        email_status = "sent" if fallback_sent else "failed"
    
    return {
        "status": f"User {action} successfully",
        "username": req.username,
        "role": req.role,
        "room_id": room_id,
        "is_proxy": is_proxy,
        "proxy_for_email": proxy_for_email,
        "email_status": email_status,
        "message": f"Invitation {'sent' if email_status == 'sent' else 'created but email sending failed'}"
    }
@app.get("/anomalies")
def get_anomalies(limit: int = 50, department: str = None, room_id: str = None, request: Request = None):
    """Fetch active anomalies with role-based access control.
    
    - Admin/Coordinator/Sergeant: Can access anomalies in their department
    - Class Representative: Can only access anomalies for their assigned room
    - Public: Denied (must authenticate)
    """
    try:
        # Extract and verify JWT token
        auth_header = request.headers.get("Authorization") if request else None
        user_role = None
        assigned_room_id = None
        user_department = None
        
        if auth_header and auth_header.startswith("Bearer "):
            token = auth_header.split(" ")[1]
            try:
                payload = jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALG])
                user_role = payload.get("role")
                assigned_room_id = payload.get("assigned_room_id")
                user_department = payload.get("department")
            except (jwt.ExpiredSignatureError, jwt.InvalidTokenError):
                raise HTTPException(status_code=401, detail="Invalid or expired token")
        
        # Role-based access control
        if user_role == "student":
            # Prefer the assigned room, but keep dashboard requests working when
            # older tokens do not include assigned_room_id.
            if assigned_room_id and assigned_room_id.strip() != "":
                room_id = assigned_room_id
            elif user_department and not department:
                department = user_department
        elif user_role not in ["admin", "coordinator", "sergeant"]:
            # Unauthenticated or invalid role - deny access
            raise HTTPException(status_code=401, detail="Authentication required to access anomaly data")
        
        # For coordinators/sergeants, restrict to their department if not admin
        if user_role in ["coordinator", "sergeant"] and user_department and not _is_admin_department(user_department):
            department = user_department
        with engine.connect() as conn:
            where_parts = []
            params = {"limit": limit}
            if department and not _is_admin_department(department):
                where_parts.append(
                    "COALESCE(NULLIF(TRIM(UPPER(r.department)), ''), CASE WHEN UPPER(split_part(COALESCE(m.room_id, a.room_id), '-', 1)) = 'CS' THEN 'CSE' ELSE UPPER(split_part(COALESCE(m.room_id, a.room_id), '-', 1)) END) = UPPER(:department)"
                )
                params["department"] = department
            # Change the where_parts logic for room_id to:
            if room_id:
                # Get all variations (normalized and prefixed)
                room_candidates = _build_device_candidates(room_id)
                room_clauses = []
                for idx, candidate in enumerate(room_candidates):
                    key = f"room_id_{idx}"
                    params[key] = candidate
                    # Match against room_id OR the potential old device_id in tracking
                    room_clauses.append(f"(UPPER(a.room_id) = UPPER(:{key}))")
                
                if room_clauses:
                    where_parts.append("(" + " OR ".join(room_clauses) + ")")

            where_clause = ""
            if where_parts:
                where_clause = "AND " + " AND ".join(where_parts)

            rows = conn.execute(text(f"""
                SELECT
                    a.id                                 AS tracking_id,
                    a.room_id,
                    a.anomaly_log_id,
                    a.first_detected_at,
                    a.last_reminder_time,
                    a.reminder_count,
                    a.status,
                    a.anomaly_type,
                    r.department,
                    latest.id                            AS latest_log_id,
                    latest.ds                            AS latest_ds,
                    latest.power,
                    latest.occupancy,
                    latest.anomaly_score,
                    latest.energy_accumulated
                FROM anomaly_alert_tracking a
                LEFT JOIN rooms r ON r.room_id = a.room_id
                LEFT JOIN room_relay_mapping m ON UPPER(m.room_id) = UPPER(a.room_id)
                LEFT JOIN LATERAL (
                    SELECT id, ds, power, occupancy, anomaly_score, energy_accumulated
                    FROM anomaly_logs
                    WHERE UPPER(device_id) = UPPER(a.room_id)
                       OR UPPER(device_id) = UPPER(COALESCE(m.relay_device_id, ''))
                       OR UPPER(device_id) = UPPER('ESP32-' || a.room_id)
                    ORDER BY ds DESC
                    LIMIT 1
                ) latest ON TRUE
                WHERE a.status IN ('active', 'power_cut')
                                    AND UPPER(a.room_id) NOT LIKE '%TEST%'
                                    AND UPPER(a.room_id) NOT LIKE '%DEMO%'
                                    AND UPPER(a.room_id) NOT LIKE '%MOCK%'
                {where_clause}
                ORDER BY COALESCE(latest.ds, a.first_detected_at) DESC
                LIMIT :limit
            """), params).fetchall()

            result = []
            for row in rows:
                # id uses tracking row id, so frontend reminder service sees one alert thread.
                result.append({
                    "id": row[0],
                    "tracking_id": row[0],
                    "device_id": row[1],
                    "anomaly_log_id": row[9] if row[9] is not None else row[2],
                    "timestamp": row[10].isoformat() if row[10] else None,
                    "power": row[11],
                    "occupancy": row[12],
                    "score": round(row[13], 4) if row[13] is not None else 0,
                    "energy_accumulated": row[14],
                    "status": row[6],
                    "anomaly_type": row[7],
                    "department": row[8],
                    "reminder_count": row[5] or 0,
                    "last_reminder_time": row[4].isoformat() if row[4] else None,
                    "first_detected_at": row[3].isoformat() if row[3] else None,
                })
            return result
    except Exception as e:
        print(f"Error fetching anomalies: {e}")
        raise HTTPException(status_code=500, detail="Internal server error fetching alerts")

@app.delete("/anomalies/{anomaly_id}")
def resolve_anomaly(anomaly_id: int):
    """Delete/resolve an anomaly alert by ID."""
    try:
        with engine.begin() as conn:
            result = conn.execute(
                text("DELETE FROM anomaly_logs WHERE id = :id RETURNING id"),
                {"id": anomaly_id}
            ).fetchone()
            if not result:
                raise HTTPException(status_code=404, detail="Anomaly not found")
        return {"status": "success", "message": "Anomaly resolved"}
    except HTTPException:
        raise
    except Exception as e:
        print(f"Error resolving anomaly: {e}")
        raise HTTPException(status_code=500, detail="Error resolving anomaly")

@app.put("/anomalies/{anomaly_id}/resolve")
def resolve_anomaly_put(anomaly_id: int):
    """
    Soft-resolve: sets is_anomaly=0 so it disappears from active alerts list
    for ALL departments (shared resolution — both coordinator and CR see it gone).
    Also marks the anomaly_alert_tracking row as 'acknowledged'.
    """
    try:
        with engine.begin() as conn:
            # First, try resolving by tracking id (new frontend behavior).
            tr = conn.execute(text("""
                SELECT room_id, anomaly_log_id
                FROM anomaly_alert_tracking
                WHERE id = :id AND status IN ('active', 'power_cut')
                LIMIT 1
            """), {"id": anomaly_id}).fetchone()

            if tr:
                room_id = tr[0]
                conn.execute(text("""
                    UPDATE anomaly_alert_tracking
                    SET status = 'acknowledged', resolved_at = NOW()
                    WHERE id = :id
                """), {"id": anomaly_id})

                # Soft-clear recent anomaly rows for that room from active feed.
                conn.execute(text("""
                    UPDATE anomaly_logs
                    SET is_anomaly = 0
                    WHERE device_id = :room_id
                      AND is_anomaly IN (1, -1)
                """), {"room_id": room_id})

                # Mark in-app notifications as resolved/read.
                try:
                    conn.execute(text("""
                        UPDATE notifications
                        SET is_read = TRUE,
                            is_resolved = TRUE,
                            resolved_at = NOW(),
                            resolution_note = 'Resolved manually by dashboard action'
                        WHERE room_id = :room_id
                    """), {"room_id": room_id})
                except Exception:
                    pass

                return {"status": "success", "message": f"Alert thread {anomaly_id} resolved", "id": anomaly_id}

            # Backward compatibility: resolve by anomaly_log id.
            result = conn.execute(
                text("UPDATE anomaly_logs SET is_anomaly = 0 WHERE id = :id RETURNING id, device_id"),
                {"id": anomaly_id}
            ).fetchone()
            if not result:
                raise HTTPException(status_code=404, detail="Anomaly not found")

            device_id = result[1]
            conn.execute(text("""
                UPDATE anomaly_alert_tracking
                SET status = 'acknowledged', resolved_at = NOW()
                WHERE room_id = :room_id
                  AND status IN ('active', 'power_cut')
            """), {"room_id": device_id})

            try:
                conn.execute(text("""
                    UPDATE notifications
                    SET is_read = TRUE,
                        is_resolved = TRUE,
                        resolved_at = NOW(),
                        resolution_note = 'Resolved manually by dashboard action'
                    WHERE room_id = :room_id
                """), {"room_id": device_id})
            except Exception:
                pass

        return {"status": "success", "message": f"Anomaly {anomaly_id} resolved", "id": anomaly_id}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail="Error resolving anomaly")

@app.post("/register")
def register(req: RegisterRequest):
    # For student registration, verify KTU ID, Department, and Year against authorized list
    if req.role == "student":
        if not req.ktu_id or not req.department or not req.year or not req.email:
            raise HTTPException(status_code=400, detail="KTU ID, Department, Year, and Email are required for student registration")
        
        with engine.begin() as conn:
            # Check if student is authorized with matching KTU ID, department, and year
            auth_row = conn.execute(
                text("SELECT id FROM authorized_students WHERE ktu_id = :ktu_id AND department = :department AND year = :year"),
                {"ktu_id": req.ktu_id, "department": req.department, "year": req.year}
            ).fetchone()
            
            if not auth_row:
                raise HTTPException(
                    status_code=403, 
                    detail="You are not authorized to register. Please verify your KTU ID, Department, and Year match our records."
                )
            
            # Check if class representative already exists
            existing = conn.execute(
                text("SELECT id FROM class_representatives WHERE username = :u OR ktu_id = :k OR email = :e"),
                {"u": req.username, "k": req.ktu_id, "e": req.email}
            ).fetchone()
            if existing:
                raise HTTPException(status_code=400, detail="User or KTU ID already registered")
            
            # Insert into class_representatives table
            pw_hash = PWD_CTX.hash(req.password)
            conn.execute(
                text("INSERT INTO class_representatives (username, password_hash, ktu_id, email, department, year, phone, created_at) VALUES (:u, :p, :k, :e, :d, :y, :phone, :c)"),
                {"u": req.username, "p": pw_hash, "k": req.ktu_id, "e": req.email, "d": req.department, "y": req.year, "phone": (req.phone or "").strip() or None, "c": datetime.utcnow()},
            )
    else:
        # Admin or coordinator registration
        if not req.email:
            raise HTTPException(status_code=400, detail="Email is required for admin and coordinator registration")
        if req.role == "coordinator" and not req.department:
            raise HTTPException(status_code=400, detail="Department is required for coordinator registration")
        if not req.ktu_id:
            # keep compatibility; username acts as email for admins/coordinators
            req.ktu_id = None

        with engine.begin() as conn:
            if req.role == "admin":
                row = conn.execute(text("SELECT id FROM admins WHERE email=:e"), {"e": req.email}).fetchone()
                if row:
                    raise HTTPException(status_code=400, detail="Admin already exists")
                pw_hash = PWD_CTX.hash(req.password)
                conn.execute(
                    text("INSERT INTO admins (email, password_hash, name, phone, created_at) VALUES (:e, :p, :n, :phone, :c)"),
                    {"e": req.email, "p": pw_hash, "n": req.username or req.email, "phone": (req.phone or "").strip() or None, "c": datetime.utcnow()},
                )
            else:
                row = conn.execute(text("SELECT id FROM coordinators WHERE email=:e"), {"e": req.email}).fetchone()
                if row:
                    raise HTTPException(status_code=400, detail="Coordinator already exists")
                pw_hash = PWD_CTX.hash(req.password)
                conn.execute(
                    text("INSERT INTO coordinators (email, password_hash, name, department, phone, created_at) VALUES (:e, :p, :n, :d, :phone, :c)"),
                    {"e": req.email, "p": pw_hash, "n": req.username or req.email, "d": req.department, "phone": (req.phone or "").strip() or None, "c": datetime.utcnow()},
                )
    return {"status": "ok"}


@app.post("/login")
def login(req: LoginRequest, request: Request):
    try:
        client_ip = request.client.host if request.client else "0.0.0.0"
        
        with engine.begin() as conn:
            # Try admin by username or email (accept either identifier)
            admin_row = conn.execute(
                text("SELECT id, password_hash, name, email, username FROM admins WHERE UPPER(username)=UPPER(:u) OR UPPER(email)=UPPER(:u)"),
                {"u": req.username.strip()},
            ).fetchone()

            coordinator_row = None
            if not admin_row:
                # Try coordinator by coordinator_id only
                coordinator_row = conn.execute(
                    text("SELECT id, password_hash, name, department, email, coordinator_id, is_proxy, proxy_for_email, assigned_room_id FROM coordinators WHERE UPPER(coordinator_id)=UPPER(:u)"),
                    {"u": req.username.strip()},
                ).fetchone()
                
                # Verify department matches if coordinator found
                if coordinator_row and req.department:
                    stored_dept = coordinator_row[3]  # department is at index 3
                    if stored_dept and stored_dept.strip().upper() != req.department.strip().upper():
                        activity_logger.log_activity(
                            user_id=req.username,
                            action_type="login",
                            action_description="Failed login attempt - department mismatch",
                            status="failure",
                            ip_address=client_ip,
                        )
                        raise HTTPException(
                            status_code=401, 
                            detail="Department mismatch"
                        )
                elif coordinator_row and not req.department:
                    activity_logger.log_activity(
                        user_id=req.username,
                        action_type="login",
                        action_description="Failed login attempt - missing department",
                        status="failure",
                        ip_address=client_ip,
                    )
                    raise HTTPException(status_code=400, detail="Department is required")

            class_rep_row = None
            if not admin_row and not coordinator_row:
                class_rep_row = conn.execute(
                    text("SELECT id, password_hash, department, ktu_id, year, username, name, email, is_proxy, proxy_for_email, assigned_room_id FROM class_representatives WHERE UPPER(ktu_id)=UPPER(:u) OR UPPER(email)=UPPER(:u) OR UPPER(username)=UPPER(:u)"),
                    {"u": req.username.strip()},
                ).fetchone()

            if admin_row:
                u_id, pw_hash, name, email, username = admin_row
                role = "admin"
                dept, ktu, year = None, None, None
                is_proxy_user, proxy_for, assigned_room_id = False, None, None
            elif coordinator_row:
                u_id, pw_hash, name, dept, email, coordinator_id, is_proxy_user, proxy_for, assigned_room_id = coordinator_row
                role = "coordinator"
                ktu, year = None, None
            elif class_rep_row:
                u_id, pw_hash, dept, ktu, year, username_val, name, email_from_table, is_proxy_user, proxy_for, assigned_room_id = class_rep_row
                email = email_from_table or username_val
                role = "student"
            else:
                activity_logger.log_activity(
                    user_id=req.username,
                    action_type="login",
                    action_description="Failed login attempt - user not found",
                    status="failure",
                    ip_address=client_ip,
                )
                raise HTTPException(status_code=401, detail="Invalid username or password")

            if not PWD_CTX.verify(req.password, pw_hash):
                activity_logger.log_activity(
                    user_id=req.username,
                    user_name=name,
                    user_role=role,
                    action_type="login",
                    action_description="Failed login attempt - invalid password",
                    status="failure",
                    department=dept,
                    ip_address=client_ip,
                )
                raise HTTPException(status_code=401, detail="Invalid username or password")

            # Log successful login
            activity_logger.log_activity(
                user_id=str(u_id),
                user_name=name,
                user_role=role,
                action_type="login",
                action_description=f"{role.capitalize()} successfully logged in",
                status="success",
                department=dept,
                ip_address=client_ip,
            )

            payload = {
                "sub": str(u_id),
                "username": email,
                "name": name,
                "role": role,
                "department": dept,
                "ktu_id": ktu,
                "year": year,
                "is_proxy": bool(is_proxy_user),
                "proxy_for_email": proxy_for,
                "assigned_room_id": assigned_room_id,
                "exp": datetime.utcnow() + timedelta(hours=12),
            }
            return {"access_token": jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALG), "token_type": "bearer"}
    except HTTPException:
        # Re-raise HTTP exceptions (credential errors)
        raise
    except Exception as e:
        print(f"Login error: {e}")
        # For database or system errors, return generic error
        raise HTTPException(status_code=500, detail="Something went wrong")

# Alias endpoints for client compatibility
@app.post("/student/login")
def student_login(req: LoginRequest, request: Request):
    """Alias for student login - delegates to unified login endpoint."""
    return login(req, request)

@app.post("/admin/login")
def admin_login(req: LoginRequest, request: Request):
    """Alias for admin login - delegates to unified login endpoint."""
    return login(req, request)

@app.post("/coordinator/login")
def coordinator_login(req: LoginRequest, request: Request):
    """Dedicated coordinator login endpoint with department validation."""
    try:
        client_ip = request.client.host if request.client else "0.0.0.0"
        
        with engine.begin() as conn:
            # Look up coordinator by coordinator_id
            coordinator_row = conn.execute(
                text("""
                    SELECT id, password_hash, name, department, email, coordinator_id, created_at,
                           is_proxy, proxy_for_email, assigned_room_id
                    FROM coordinators 
                    WHERE UPPER(coordinator_id)=UPPER(:u)
                """),
                {"u": req.username.strip()},
            ).fetchone()
            
            if not coordinator_row:
                activity_logger.log_activity(
                    user_id=req.username,
                    action_type="login",
                    action_description="Failed coordinator login - user not found",
                    status="failure",
                    ip_address=client_ip,
                )
                raise HTTPException(status_code=401, detail="Invalid credentials")
            
            u_id, pw_hash, name, dept, email, coordinator_id, created_at, is_proxy_user, proxy_for, assigned_room_id = coordinator_row
            
            # Verify password
            if not PWD_CTX.verify(req.password, pw_hash):
                activity_logger.log_activity(
                    user_id=coordinator_id,
                    user_name=name,
                    user_role="coordinator",
                    action_type="login",
                    action_description="Failed coordinator login - invalid password",
                    status="failure",
                    department=dept,
                    ip_address=client_ip,
                )
                raise HTTPException(status_code=401, detail="Invalid credentials")
            
            # Update last_login timestamp
            conn.execute(
                text("UPDATE coordinators SET last_login = NOW() WHERE id = :id"),
                {"id": u_id}
            )
            
            # Log successful login
            activity_logger.log_activity(
                user_id=str(u_id),
                user_name=name,
                user_role="coordinator",
                action_type="login",
                action_description="Coordinator successfully logged in",
                status="success",
                department=dept,
                ip_address=client_ip,
            )
            
            # Create JWT token
            payload = {
                "sub": str(u_id),
                "username": coordinator_id,
                "email": email,
                "name": name,
                "role": "coordinator",
                "department": dept,
                "is_proxy": bool(is_proxy_user),
                "proxy_for_email": proxy_for,
                "assigned_room_id": assigned_room_id,
                "exp": datetime.now(timezone.utc) + timedelta(hours=12),
            }
            
            token = jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALG)
            
            # Return coordinator data with token
            return {
                "id": u_id,
                "coordinator_id": coordinator_id,
                "name": name,
                "email": email,
                "department": dept,
                "is_proxy": bool(is_proxy_user),
                "proxy_for_email": proxy_for,
                "assigned_room_id": assigned_room_id,
                "created_at": created_at.isoformat() if created_at else None,
                "token": token,
                "token_type": "bearer"
            }
            
    except HTTPException:
        raise
    except Exception as e:
        print(f"Coordinator login error: {e}")
        raise HTTPException(status_code=500, detail="Something went wrong")


@app.get("/user/profile")
def get_user_profile(request: Request):
    """Get current user profile from JWT token."""
    try:
        # Extract token from Authorization header
        auth_header = request.headers.get("Authorization")
        if not auth_header or not auth_header.startswith("Bearer "):
            raise HTTPException(status_code=401, detail="Missing or invalid authorization header")
        
        token = auth_header.split(" ")[1]
        
        # Decode JWT token
        try:
            payload = jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALG])
        except jwt.ExpiredSignatureError:
            raise HTTPException(status_code=401, detail="Token has expired")
        except jwt.InvalidTokenError:
            raise HTTPException(status_code=401, detail="Invalid token")
        
        # Return user data from token payload
        user_data = {
            "id": payload.get("sub"),
            "username": payload.get("username"),
            "name": payload.get("name"),
            "email": payload.get("username"),  # username is email in most cases
            "role": payload.get("role"),
            "department": payload.get("department"),
            "ktu_id": payload.get("ktu_id"),
            "year": payload.get("year"),
        }
        
        return user_data
        
    except HTTPException:
        raise
    except Exception as e:
        print(f"Get profile error: {e}")
        raise HTTPException(status_code=500, detail="Failed to retrieve profile")


@app.get("/admin/profile")
def get_admin_profile(request: Request):
    """Get admin profile from JWT token."""
    try:
        # Extract token from Authorization header
        auth_header = request.headers.get("Authorization")
        if not auth_header or not auth_header.startswith("Bearer "):
            raise HTTPException(status_code=401, detail="Missing or invalid authorization header")
        
        token = auth_header.split(" ")[1]
        
        # Decode JWT token
        try:
            payload = jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALG])
        except jwt.ExpiredSignatureError:
            raise HTTPException(status_code=401, detail="Token has expired")
        except jwt.InvalidTokenError:
            raise HTTPException(status_code=401, detail="Invalid token")
        
        # Verify admin role
        if payload.get("role") != "admin":
            raise HTTPException(status_code=403, detail="Admin access required")
        
        # Return admin data from token payload wrapped in 'data' key
        user_data = {
            "id": payload.get("sub"),
            "username": payload.get("username"),
            "name": payload.get("name"),
            "email": payload.get("username"),
            "role": payload.get("role"),
            "department": payload.get("department"),
            "ktu_id": payload.get("ktu_id"),
            "year": payload.get("year"),
        }
        
        return {"data": user_data}
        
    except HTTPException:
        raise
    except Exception as e:
        print(f"Get admin profile error: {e}")
        raise HTTPException(status_code=500, detail="Failed to retrieve admin profile")


@app.get("/users/coordinators")
def get_coordinators():
    """Fetch all coordinators from the database."""
    with engine.begin() as conn:
        result = conn.execute(
            text(
                "SELECT id, email, coordinator_id, name, department, is_proxy, proxy_for_email, assigned_room_id, created_at FROM coordinators ORDER BY name ASC"
            )
        ).fetchall()
        
        coordinators = []
        for row in result:
            coordinator_email = row[1] or row[2]
            coordinator_login_id = row[2] or row[1]
            coordinators.append({
                "id": row[0],
                "email": coordinator_email,
                "username": coordinator_email,
                "coordinator_id": coordinator_login_id,
                "name": row[3] or coordinator_email or coordinator_login_id,
                "department": row[4] or "N/A",
                "is_proxy": bool(row[5]),
                "proxy_for_email": row[6],
                "assigned_room_id": row[7],
                "created_at": row[8].isoformat() if row[8] else None,
            })
        
        return {"coordinators": coordinators, "total": len(coordinators)}


@app.get("/users/class-representatives")
def get_class_representatives():
    """Fetch all class representatives from the database."""
    with engine.begin() as conn:
        result = conn.execute(
            text("""
                SELECT id, username, name, ktu_id, department, year, email,
                       created_at, is_proxy, proxy_for_email, assigned_room_id
                FROM class_representatives 
                ORDER BY department ASC, year ASC, name ASC
            """)
        ).fetchall()
        
        class_reps = []
        for row in result:
            class_reps.append({
                "id": row[0],
                "username": row[1],
                "name": row[2] or row[1],  # fallback to username if name is null
                "ktu_id": row[3],
                "department": row[4],
                "year": row[5],
                "email": row[6],
                "is_proxy": bool(row[8]),
                "proxy_for_email": row[9],
                "assigned_room_id": row[10],
                "created_at": row[7].isoformat() if row[7] else None
            })
        
        return {"class_representatives": class_reps, "total": len(class_reps)}


@app.get("/users/counts")
def get_user_counts():
    """Fetch user counts from the database."""
    with engine.begin() as conn:
        coordinator_count = conn.execute(text("SELECT COUNT(*) FROM coordinators")).scalar()
        class_rep_count = conn.execute(text("SELECT COUNT(*) FROM class_representatives")).scalar()
        sergeant_count = conn.execute(text("SELECT COUNT(*) FROM sergeants")).scalar()
        
        # Total users (excluding admins)
        total_users = coordinator_count + class_rep_count + sergeant_count
        
        return {
            "total_users": total_users,
            "coordinators": coordinator_count,
            "class_representatives": class_rep_count,
            "sergeants": sergeant_count
        }


# Cache for dashboard overview to reduce DB load
_overview_cache = {"data": None, "timestamp": None}
_overview_cache_ttl = 30  # seconds

@app.get("/dashboard/overview")
def get_dashboard_overview(active_window_minutes: int = 5, usage_window_hours: int = 1):
    """Return campus-wide live metrics for the admin dashboard (cached for 30s).

    Formulas:
    - total_usage_kwh: time-weighted integration of incoming power samples over window
      E(Wh) = Σ(P(W) * Δt(hours)) per device, then converted to kWh
    - active_rooms / total_rooms: live reporting rooms vs room inventory
    - inactive_rooms: rooms in inventory with no report in active window
    - efficiency_percent: percentage of active rooms whose latest reading is <= room threshold
      (threshold is stored in kW; power is compared in watts)
    """

    now = datetime.now(timezone.utc)
    if _overview_cache["data"] and _overview_cache["timestamp"]:
        age = (now - _overview_cache["timestamp"]).total_seconds()
        if age < _overview_cache_ttl:
            return _overview_cache["data"]

    active_window_minutes = max(1, min(active_window_minutes, 60))
    usage_window_hours = max(1, min(usage_window_hours, 24))

    active_interval = f"{active_window_minutes} minutes"
    usage_interval = f"{usage_window_hours} hours"

    with engine.begin() as conn:
        total_usage_wh = conn.execute(
            text(
                """
                WITH ordered AS (
                    SELECT
                        sd.device_id,
                        sd.ds,
                        COALESCE(sd.power, sd.value, 0)::double precision AS power_w,
                        LEAD(sd.ds) OVER (PARTITION BY sd.device_id ORDER BY sd.ds) AS next_ds
                    FROM sensor_data sd
                    WHERE sd.ds >= NOW() - CAST(:usage_interval AS INTERVAL)
                      AND sd.ds <= NOW()
                ),
                segments AS (
                    SELECT
                        power_w,
                        LEAST(
                            GREATEST(EXTRACT(EPOCH FROM (COALESCE(next_ds, NOW()) - ds)) / 3600.0, 0),
                            0.25
                        ) AS dt_hours
                    FROM ordered
                )
                SELECT COALESCE(SUM(power_w * dt_hours), 0)
                FROM segments
                """
            ),
            {"usage_interval": usage_interval},
        ).scalar() or 0

        total_rooms = conn.execute(
            text("SELECT COUNT(*) FROM rooms")
        ).scalar() or 0

        active_rooms = conn.execute(
            text(
                """
                SELECT COUNT(DISTINCT sd.device_id)
                FROM sensor_data sd
                WHERE sd.ds >= NOW() - CAST(:active_interval AS INTERVAL)
                """
            ),
            {"active_interval": active_interval},
        ).scalar() or 0

        if total_rooms == 0:
            total_rooms = conn.execute(
                text(
                    """
                    SELECT COUNT(DISTINCT sd.device_id)
                    FROM sensor_data sd
                    WHERE sd.ds >= NOW() - INTERVAL '7 days'
                    """
                )
            ).scalar() or 0

        if total_rooms > 0:
            inactive_rows = conn.execute(
                text(
                    """
                    SELECT r.room_id
                    FROM rooms r
                    WHERE r.room_id NOT IN (
                        SELECT DISTINCT sd.device_id
                        FROM sensor_data sd
                        WHERE sd.ds >= NOW() - CAST(:active_interval AS INTERVAL)
                    )
                    ORDER BY r.room_id
                    LIMIT 100
                    """
                ),
                {"active_interval": active_interval},
            ).fetchall()
        else:
            inactive_rows = conn.execute(
                text(
                    """
                    SELECT DISTINCT d1.device_id
                    FROM (
                        SELECT DISTINCT sd.device_id
                        FROM sensor_data sd
                        WHERE sd.ds >= NOW() - INTERVAL '7 days'
                    ) d1
                    WHERE d1.device_id NOT IN (
                        SELECT DISTINCT sd2.device_id
                        FROM sensor_data sd2
                        WHERE sd2.ds >= NOW() - CAST(:active_interval AS INTERVAL)
                    )
                    ORDER BY d1.device_id
                    LIMIT 100
                    """
                ),
                {"active_interval": active_interval},
            ).fetchall()

        efficiency_percent = conn.execute(
            text(
                """
                WITH latest_active AS (
                    SELECT x.device_id, x.power_w
                    FROM (
                        SELECT
                            sd.device_id,
                            COALESCE(sd.power, sd.value, 0)::double precision AS power_w,
                            ROW_NUMBER() OVER (PARTITION BY sd.device_id ORDER BY sd.ds DESC) AS rn
                        FROM sensor_data sd
                        WHERE sd.ds >= NOW() - CAST(:active_interval AS INTERVAL)
                    ) x
                    WHERE x.rn = 1
                )
                SELECT
                    CASE
                        WHEN COUNT(*) = 0 THEN NULL
                        ELSE 100.0 * SUM(
                            CASE
                                WHEN la.power_w <= COALESCE(r.upper_threshold, r.threshold, 3.0) * 1000.0 THEN 1
                                ELSE 0
                            END
                        )::double precision / COUNT(*)
                    END AS efficiency_pct
                FROM latest_active la
                LEFT JOIN rooms r ON r.room_id = la.device_id
                """
            ),
            {"active_interval": active_interval},
        ).scalar()

    total_usage_kwh = float(total_usage_wh) / 1000.0
    if efficiency_percent is None:
        efficiency_percent = (active_rooms / total_rooms) * 100.0 if total_rooms > 0 else 0.0

    result = {
        "total_usage_kwh": round(total_usage_kwh, 3),
        "active_rooms": active_rooms,
        "total_rooms": total_rooms,
        "inactive_rooms": [row[0] for row in inactive_rows],
        "efficiency_percent": round(float(efficiency_percent), 1),
        "active_window_minutes": active_window_minutes,
        "usage_window_hours": usage_window_hours,
    }

    _overview_cache["data"] = result
    _overview_cache["timestamp"] = now

    return result


@app.delete("/users/{username}")
def delete_user(username: str):
    """Delete a user (coordinator or class representative) by username."""
    with engine.begin() as conn:
        rep_emails = conn.execute(
            text("""
                SELECT email
                FROM class_representatives
                WHERE UPPER(username)=UPPER(:u) OR UPPER(ktu_id)=UPPER(:u) OR UPPER(email)=UPPER(:u)
            """),
            {"u": username},
        ).fetchall()

        result_admin = conn.execute(
            text("DELETE FROM admins WHERE UPPER(email)=UPPER(:u)"),
            {"u": username},
        )

        result_coord = conn.execute(
            text("DELETE FROM coordinators WHERE UPPER(email)=UPPER(:u)"),
            {"u": username},
        )

        result_reps = conn.execute(
            text("DELETE FROM class_representatives WHERE UPPER(username)=UPPER(:u) OR UPPER(ktu_id)=UPPER(:u) OR UPPER(email)=UPPER(:u)"),
            {"u": username},
        )

        for row in rep_emails:
            rep_email = (row[0] or "").strip()
            if rep_email:
                conn.execute(
                    text("DELETE FROM class_rep_room_mapping WHERE UPPER(class_rep_email)=UPPER(:e)"),
                    {"e": rep_email},
                )
                conn.execute(
                    text("UPDATE class_representatives SET proxy_for_email = NULL WHERE UPPER(proxy_for_email)=UPPER(:e)"),
                    {"e": rep_email},
                )
                conn.execute(
                    text("UPDATE coordinators SET proxy_for_email = NULL WHERE UPPER(proxy_for_email)=UPPER(:e)"),
                    {"e": rep_email},
                )

        conn.execute(
            text("UPDATE class_representatives SET proxy_for_email = NULL WHERE UPPER(proxy_for_email)=UPPER(:u)"),
            {"u": username},
        )
        conn.execute(
            text("UPDATE coordinators SET proxy_for_email = NULL WHERE UPPER(proxy_for_email)=UPPER(:u)"),
            {"u": username},
        )

        deleted_count = result_admin.rowcount + result_coord.rowcount + result_reps.rowcount

        if deleted_count == 0:
            raise HTTPException(status_code=404, detail=f"User '{username}' not found or cannot be deleted")
        
        return {"status": "success", "message": f"User '{username}' deleted successfully", "deleted_count": deleted_count}

@app.post("/sensor-data")
async def receive_sensor_data(request: Request):
    global model, model_features
    try:
        payload = await request.json()
        raw_device_id = payload.get("device_id", "unknown")
        timestamp = datetime.now(timezone.utc)
        timestamp_raw = payload.get("timestamp") or payload.get("ts")
        if timestamp_raw:
            try:
                parsed_timestamp = datetime.fromisoformat(str(timestamp_raw).replace("Z", "+00:00"))
                timestamp = parsed_timestamp if parsed_timestamp.tzinfo else parsed_timestamp.replace(tzinfo=timezone.utc)
                timestamp = timestamp.astimezone(timezone.utc)
            except Exception:
                pass

        # Verbose ingest log: show exactly what JSON values arrived at backend.
        # Keep JSON encoded in one line so it is easy to grep in server logs.
        try:
            print(
                f"[INGEST][RAW] ts={timestamp.isoformat()} device_id={raw_device_id} "
                f"keys={sorted(list(payload.keys()))}"
            )
            print(f"[INGEST][JSON] {json.dumps(payload, ensure_ascii=True, default=str)}")
        except Exception as _log_exc:
            print(f"[INGEST][WARN] Failed to print payload: {_log_exc}")

        # 1. Identify what data we just received
        has_power = "power" in payload and payload.get("power") is not None
        has_frequency = "frequency" in payload and payload.get("frequency") is not None
        has_occ = "human_present" in payload and payload.get("human_present") is not None
        has_relay_state = "relay_state" in payload and payload.get("relay_state") is not None
        relay_state = str(payload.get("relay_state", "")).strip().upper()
        is_demo_payload = bool(payload.get("demo_mode") or str(payload.get("source", "")).strip().lower() == "demo")

        with engine.begin() as conn:
            # Normalize device_id to canonical relay_device_id format (ESP32-prefixed)
            device_id = _normalize_device_id_to_relay_format(conn, raw_device_id)
            resolved_room_id = _resolve_room_id_for_device(conn, raw_device_id)

            # Keep relay heartbeat fresh whenever ESP32 includes relay state in sensor payload.
            if has_relay_state and relay_state in {"ON", "OFF", "UNKNOWN"}:
                conn.execute(
                    text(
                        """
                        INSERT INTO relay_states (device_id, state, last_updated)
                        VALUES (:device_id, :state, NOW())
                        ON CONFLICT (device_id)
                        DO UPDATE SET state = :state, last_updated = NOW()
                        """
                    ),
                    {"device_id": device_id, "state": relay_state},
                )

            if resolved_room_id and resolved_room_id != raw_device_id:
                print(f"[INGEST][MAP] raw_device_id={raw_device_id} -> device_id={device_id} -> room_id={resolved_room_id}")

            # 2. LOOKUP: Check for a row from this device created in the last 7 minutes.
            # Window is 7 min (not 5) because the ESP32 sends on an exact ~300s timer.
            # With a 5-min window, the previous row lands at "now - 300.06s" and misses
            # the "ds > now - 300.00s" check by milliseconds, causing spurious new rows.
            existing = None if is_demo_payload else conn.execute(
                text("""SELECT id, occupancy, power, current, voltage, energy, power_factor, frequency 
                        FROM sensor_data 
                        WHERE device_id = :id 
                        AND ds > :window 
                        ORDER BY ds DESC LIMIT 1"""),
                {"id": device_id, "window": timestamp - timedelta(minutes=7)}
            ).fetchone()

            if existing:
                row_id = existing[0]
                # 3. UPDATE: Fill the gaps in the existing row
                if has_occ:
                    occupancy = payload.get("human_present")
                    conn.execute(
                        text("UPDATE sensor_data SET occupancy = :occ, ds = :ds WHERE id = :rid"),
                        {"occ": occupancy, "ds": timestamp, "rid": row_id}
                    )
                    # Use existing electrical data for AI processing (FIXED indices)
                    # SELECT: id[0], occupancy[1], power[2], current[3], voltage[4], energy[5], power_factor[6], frequency[7]
                    p, c, v, e, pf, f = existing[2], existing[3], existing[4], existing[5], existing[6], existing[7]
                    # Use 0 if values are None
                    p = p if p is not None else 0.0
                    c = c if c is not None else 0.0
                    v = v if v is not None else 0.0
                    e = e if e is not None else 0.0
                    pf = pf if pf is not None else 0.0
                    f = f if f is not None else 0.0
                
                if has_power:
                    p = float(payload.get("power", 0))
                    c = float(payload.get("current", 0))
                    pf = float(payload.get("power_factor", 0))
                    v = float(payload.get("voltage", 0))
                    e = float(payload.get("energy", 0))
                    f = float(payload.get("frequency", 0))
                    
                    conn.execute(
                        text("""UPDATE sensor_data SET 
                                power=:p, current=:c, voltage=:v, energy=:e, power_factor=:pf, frequency=:f, ds = :ds 
                                WHERE id = :rid"""),
                        {"p": p, "c": c, "v": v, "e": e, "pf": pf, "f": f, "ds": timestamp, "rid": row_id}
                    )
                    # Use existing occupancy context for AI processing
                    occupancy = existing[1] if existing[1] is not None else 0
                elif has_frequency:
                    f = float(payload.get("frequency", 0))
                    conn.execute(
                        text("UPDATE sensor_data SET frequency = :f, ds = :ds WHERE id = :rid"),
                        {"f": f, "ds": timestamp, "rid": row_id}
                    )
                    p, c, v, e, pf = existing[2], existing[3], existing[4], existing[5], existing[6]
                    p = p if p is not None else 0.0
                    c = c if c is not None else 0.0
                    v = v if v is not None else 0.0
                    e = e if e is not None else 0.0
                    pf = pf if pf is not None else 0.0
                    occupancy = existing[1] if existing[1] is not None else 0
            else:
                # 4. INSERT: Create a fresh row if no recent entry exists
                if has_power:
                    # Power sensor data - insert with actual values
                    p = float(payload.get("power", 0))
                    c = float(payload.get("current", 0))
                    pf = float(payload.get("power_factor", 0))
                    v = float(payload.get("voltage", 0))
                    e = float(payload.get("energy", 0))
                    f = float(payload.get("frequency", 0))
                    occupancy = payload.get("human_present") if has_occ else 0
                    
                    # If no occupancy in payload, lookup most recent
                    if not has_occ:
                        occ_q = conn.execute(
                            text("SELECT occupancy FROM sensor_data WHERE device_id = :id AND occupancy IS NOT NULL ORDER BY ds DESC LIMIT 1"),
                            {"id": device_id}
                        ).fetchone()
                        occupancy = occ_q[0] if occ_q else 0
                    
                    conn.execute(
                        text("""INSERT INTO sensor_data (ds, device_id, power, current, voltage, energy, frequency, power_factor, occupancy) 
                                VALUES (:ds, :id, :p, :c, :v, :e, :f, :pf, :occ)"""),
                        {"ds": timestamp, "id": device_id, "p": p, "c": c, "v": v, "e": e, "f": f, "pf": pf, "occ": occupancy}
                    )
                    print(f"[DEBUG] INSERT sensor_data with power: device_id={device_id}, power={p}, occupancy={occupancy}")
                elif has_occ:
                    # Camera-only data - insert with NULL power values (not 0) to distinguish from actual zero readings
                    occupancy = payload.get("human_present")
                    f = float(payload.get("frequency", 0)) if has_frequency else None
                    conn.execute(
                        text("""INSERT INTO sensor_data (ds, device_id, occupancy, frequency) 
                                VALUES (:ds, :id, :occ, :f)"""),
                        {"ds": timestamp, "id": device_id, "occ": occupancy, "f": f}
                    )
                    print(f"[DEBUG] INSERT sensor_data with occupancy only: device_id={device_id}, occupancy={occupancy}")
                    # Use NULL power values for AI processing (will be handled as 0 in calculations)
                    p, c, v, e, pf = 0.0, 0.0, 0.0, 0.0, 0.0
                else:
                    # No valid data
                    return {"status": "error", "message": "No valid sensor data in payload"}

            # 5. Fetch history for rolling AI features
            hist_res = conn.execute(
                text("SELECT power FROM sensor_data WHERE device_id = :id AND power IS NOT NULL ORDER BY ds DESC LIMIT 5"),
                {"id": device_id}
            ).fetchall()
            history = [r[0] for r in hist_res] if hist_res else [p]

        # --- AI Processing Section (Remains the same using merged values) ---
        rolling_avg = sum(history) / len(history)
        rolling_std = np.std(history) if len(history) > 1 else 0
        p_change = p - history[0] if len(history) > 0 else 0
        is_holiday = 1 if timestamp.weekday() >= 5 else 0

        input_data = {
            'power': p, 'current': c, 'power_factor': pf, 'occupancy': occupancy,
            'power_change_rate': p_change, 'rolling_avg_power': rolling_avg,
            'rolling_std_power': rolling_std, 'is_holiday': is_holiday
        }
        
        # ── Anomaly Detection ─────────────────────────────────────────────────────────
        # Two scenarios trigger anomaly alerts:
        #   Scenario 1: occupancy == 1 AND power > 100W (high usage while occupied)
        #   Scenario 2: occupancy == 0 AND power >= 20W (equipment left on without occupancy)
        
        occ_active = str(occupancy).strip().lower() in {"1", "true", "yes", "on"}
        occ_absent = str(occupancy).strip().lower() in {"0", "false", "no", "off"}
        
        # Check both scenarios
        scenario1_high_occupancy = occ_active and p > 100.0  # occupied with very high power
        scenario2_no_occupancy_usage = occ_absent and p >= 20.0  # not occupied but equipment running
        
        meets_required_conditions = scenario1_high_occupancy or scenario2_no_occupancy_usage

        # Fetch room threshold range from DB (stored in kW, compare in W)
        room_lower_threshold_w = 4000.0  # safe default 4 kW
        room_upper_threshold_w = 5000.0  # safe default 5 kW
        try:
            with engine.connect() as _tc:
                _tr = _tc.execute(
                    text("""
                        SELECT lower_threshold, upper_threshold, threshold
                        FROM rooms
                        WHERE UPPER(room_id) = UPPER(:rid)
                    """),
                    {"rid": device_id}
                ).fetchone()
                if _tr:
                    lower_kw = _tr[0] if _tr[0] is not None else (_tr[2] * 0.8 if _tr[2] is not None else 4.0)
                    upper_kw = _tr[1] if _tr[1] is not None else (_tr[2] if _tr[2] is not None else 5.0)
                    room_lower_threshold_w = max(0.1, float(lower_kw)) * 1000.0
                    room_upper_threshold_w = max(float(upper_kw), float(lower_kw) + 0.1) * 1000.0
        except Exception:
            pass

        if not meets_required_conditions:
            raw_prediction = 1
            score = 0.0
        elif model is not None and model_features is not None:
            input_df = pd.DataFrame([input_data])[model_features]
            raw_prediction = int(model.predict(input_df)[0])
            score = float(model.decision_function(input_df)[0])
        else:
            # Relative spike: >2.5x rolling avg (avoids the "avg is already high" problem)
            relative_threshold = rolling_avg * 2.5 if rolling_avg > 50 else float("inf")

            is_medium_threshold_alert = room_lower_threshold_w <= p <= room_upper_threshold_w
            is_high_threshold_alert = p > room_upper_threshold_w
            is_spike = p > relative_threshold and (p - rolling_avg) > 500

            raw_prediction = -1 if (is_medium_threshold_alert or is_high_threshold_alert or is_spike) else 1
            score = round((p - rolling_avg) / max(rolling_avg, 1.0), 4)

        is_anomaly_flag = 1 if raw_prediction == -1 else 0
        threshold_alert_level = "normal"
        if p > room_upper_threshold_w:
            threshold_alert_level = "high"
        elif room_lower_threshold_w <= p <= room_upper_threshold_w:
            threshold_alert_level = "medium"

        threshold_alert_message = None
        if threshold_alert_level in {"medium", "high"}:
            threshold_alert_message = (
                f"{threshold_alert_level.upper()} threshold alert for {device_id}: "
                f"current={p/1000.0:.2f} kW, "
                f"lower={room_lower_threshold_w/1000.0:.2f} kW, "
                f"upper={room_upper_threshold_w/1000.0:.2f} kW"
            )

        # Log to anomaly_logs using the normalised flag
        with engine.begin() as conn:
            conn.execute(
                text("""INSERT INTO anomaly_logs
                            (ds, device_id, power, occupancy, is_anomaly, anomaly_score, energy_accumulated)
                        VALUES (:ds, :id, :p, :o, :ia, :sc, :e)"""),
                {"ds": timestamp, "id": device_id, "p": p, "o": occupancy,
                 "ia": is_anomaly_flag, "sc": score, "e": e}
            )

        # Invalidate overview cache so admin widgets update immediately on new sensor data
        _overview_cache["data"] = None
        _overview_cache["timestamp"] = None

        # ── Trigger in-app notification to coordinator & class rep ────────────────────
        # Ignore synthetic/test identifiers so fake alerts never enter active flow.
        if is_anomaly_flag == 1 and _alert_svc and not _is_test_identifier(device_id):
            try:
                alert_room_id = resolved_room_id or device_id
                with engine.connect() as _conn:
                    _log_row = _conn.execute(
                        text("SELECT id FROM anomaly_logs WHERE device_id = :d ORDER BY ds DESC LIMIT 1"),
                        {"d": device_id}
                    ).fetchone()
                    _log_id = _log_row[0] if _log_row else None
                import asyncio
                try:
                    loop = asyncio.get_running_loop()
                    loop.create_task(
                        _alert_svc.anomaly_alert_service.create_anomaly_alert(alert_room_id, _log_id)
                    )
                except RuntimeError:
                    asyncio.run(
                        _alert_svc.anomaly_alert_service.create_anomaly_alert(alert_room_id, _log_id)
                    )
            except Exception as _ae:
                print(f"[auth_api] Alert notification error: {_ae}")

        return {
            "status": "success",
            "is_anomaly": is_anomaly_flag,
            "score": round(score, 4),
            "threshold_alert_level": threshold_alert_level,
            "threshold_alert_message": threshold_alert_message,
            "lower_threshold_kw": round(room_lower_threshold_w / 1000.0, 3),
            "upper_threshold_kw": round(room_upper_threshold_w / 1000.0, 3),
        }

    except Exception as err:
        return {"status": "error", "message": str(err)}


@app.get("/sensor-data")
def get_sensor_data(request: Request, limit: int = 60, device_id: str = None, department: str = None):
    """Get sensor data with role-based access control."""
    try:
        auth_header = request.headers.get("Authorization")
        if not auth_header or not auth_header.startswith("Bearer "):
            raise HTTPException(status_code=401, detail="Authentication required to access sensor data")

        token = auth_header.split(" ", 1)[1]
        try:
            payload = jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALG])
        except (jwt.ExpiredSignatureError, jwt.InvalidTokenError):
            raise HTTPException(status_code=401, detail="Invalid or expired token")

        user_role = payload.get("role")
        assigned_room_id = payload.get("assigned_room_id")
        user_department = payload.get("department")

        if user_role == "student":
            if assigned_room_id and str(assigned_room_id).strip():
                device_id = assigned_room_id
                department = None
            elif user_department and not department:
                department = user_department
        elif user_role in ["coordinator", "sergeant"]:
            if user_department and not department:
                department = user_department
        elif user_role != "admin":
            raise HTTPException(status_code=401, detail="Authentication required to access sensor data")

        with engine.connect() as conn:
            params = {"limit": limit}
            where_parts = []

            if device_id:
                candidates = _build_device_candidates(device_id)
                candidate_clauses = []
                for idx, candidate in enumerate(candidates):
                    key = f"did_{idx}"
                    params[key] = candidate
                    candidate_clauses.append(f"UPPER(sd.device_id) = UPPER(:{key})")
                if candidate_clauses:
                    where_parts.append("(" + " OR ".join(candidate_clauses) + ")")

            if department and not _is_admin_department(department):
                params["department"] = department
                where_parts.append(
                    "COALESCE(NULLIF(TRIM(UPPER(r.department)), ''), "
                    "CASE WHEN UPPER(split_part(m.room_id, '-', 1)) = 'CS' THEN 'CSE' ELSE UPPER(split_part(m.room_id, '-', 1)) END) = UPPER(:department)"
                )

            where_sql = ""
            if where_parts:
                where_sql = "WHERE " + " AND ".join(where_parts)

            result = conn.execute(
                text(f"""
                    SELECT sd.id, sd.ds, sd.device_id, sd.value, sd.voltage, sd.current, sd.power, sd.energy, sd.frequency, sd.power_factor
                    FROM sensor_data sd
                    LEFT JOIN room_relay_mapping m
                        ON UPPER(sd.device_id) = UPPER(m.room_id)
                        OR UPPER(sd.device_id) = UPPER(m.relay_device_id)
                    LEFT JOIN rooms r
                        ON UPPER(r.room_id) = UPPER(sd.device_id)
                        OR UPPER(r.room_id) = UPPER(m.room_id)
                    {where_sql}
                    ORDER BY sd.ds DESC
                    LIMIT :limit
                """),
                params,
            )

            rows = result.fetchall()
            data = [
                {
                    "id": row[0],
                    "timestamp": row[1].isoformat() if row[1] else None,
                    "device_id": row[2],
                    "value": row[3],
                    "voltage": row[4],
                    "current": row[5],
                    "power": row[6],
                    "energy": row[7],
                    "frequency": row[8],
                    "power_factor": row[9],
                }
                for row in rows
            ]
            return {"status": "success", "data": data}

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Error retrieving sensor data: {str(e)}")


@app.get("/rooms")
def get_all_rooms(department: str = None):
    """Get all rooms with their floor and threshold information.
    Optional: filter by department if provided."""
    try:
        with engine.begin() as conn:
            if department and not _is_admin_department(department):
                rows = conn.execute(
                    text("""
                        SELECT room_id, room_name, floor_number,
                               COALESCE(lower_threshold, GREATEST(COALESCE(threshold, 3.0) * 0.8, 0.1)) AS lower_threshold,
                               COALESCE(upper_threshold, COALESCE(threshold, 3.0)) AS upper_threshold
                        FROM rooms 
                        WHERE department = :department
                        ORDER BY floor_number, room_name
                    """),
                    {"department": department}
                ).fetchall()
            else:
                rows = conn.execute(
                    text("""
                        SELECT room_id, room_name, floor_number,
                               COALESCE(lower_threshold, GREATEST(COALESCE(threshold, 3.0) * 0.8, 0.1)) AS lower_threshold,
                               COALESCE(upper_threshold, COALESCE(threshold, 3.0)) AS upper_threshold
                        FROM rooms
                        ORDER BY floor_number, room_name
                    """)
                ).fetchall()

            data = [
                {
                    "room_id": row[0],
                    "room_name": row[1],
                    "floor_number": row[2],
                    "lower_threshold": float(row[3]) if row[3] is not None else None,
                    "upper_threshold": float(row[4]) if row[4] is not None else None,
                }
                for row in rows
            ]

            return {
                "status": "success",
                "count": len(data),
                "data": data,
            }

    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Error retrieving rooms: {str(e)}")


@app.get("/rooms/floors")
def get_all_floors():
    """Get all unique floors."""
    try:
        with engine.begin() as conn:
            rows = conn.execute(
                text("""
                    SELECT DISTINCT floor_number 
                    FROM rooms 
                    ORDER BY floor_number
                """)
            ).fetchall()
            
            data = [{"floor_number": row[0]} for row in rows]
            
            return {
                "status": "success",
                "count": len(data),
                "data": data
            }
    
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Error retrieving floors: {str(e)}")


@app.put("/rooms/{room_id}/threshold")
def update_room_threshold(
    room_id: str,
    lower_bound: float = None,
    upper_bound: float = None,
    threshold: float = None,
):
    """Update threshold range for a specific room.

    Backward compatibility:
    - If only `threshold` is provided, it is treated as the upper bound and
      lower bound is inferred as 80% of upper.
    """
    try:
        if lower_bound is None and upper_bound is None:
            if threshold is None:
                raise HTTPException(status_code=400, detail="lower_bound and upper_bound are required")
            upper_bound = threshold
            lower_bound = max(0.1, threshold * 0.8)

        if lower_bound is None or upper_bound is None:
            raise HTTPException(status_code=400, detail="Both lower_bound and upper_bound are required")

        if lower_bound <= 0 or upper_bound <= 0:
            raise HTTPException(status_code=400, detail="Threshold bounds must be greater than 0")

        if upper_bound <= lower_bound:
            raise HTTPException(status_code=400, detail="upper_bound must be greater than lower_bound")
        
        with engine.begin() as conn:
            # Check if room exists first
            check_row = conn.execute(
                text("""
                    SELECT id FROM rooms WHERE room_id = :room_id
                """),
                {"room_id": room_id}
            ).fetchone()
            
            if not check_row:
                raise HTTPException(status_code=404, detail=f"Room with ID '{room_id}' not found")
            
            result = conn.execute(
                text("""
                    UPDATE rooms 
                    SET lower_threshold = :lower_bound,
                        upper_threshold = :upper_bound,
                        threshold = :upper_bound,
                        updated_at = NOW() 
                    WHERE room_id = :room_id
                """),
                {
                    "lower_bound": lower_bound,
                    "upper_bound": upper_bound,
                    "room_id": room_id,
                }
            )
            
            if result.rowcount == 0:
                raise HTTPException(status_code=404, detail="Failed to update room")
            
            # Retrieve updated room data
            row = conn.execute(
                text("""
                    SELECT room_id, room_name, floor_number,
                           lower_threshold, upper_threshold
                    FROM rooms 
                    WHERE room_id = :room_id
                """),
                {"room_id": room_id}
            ).fetchone()
            
            return {
                "status": "success",
                "message": "Threshold range updated successfully",
                "data": {
                    "room_id": row[0],
                    "room_name": row[1],
                    "floor_number": row[2],
                    "lower_threshold": float(row[3]),
                    "upper_threshold": float(row[4]),
                    "threshold": float(row[4]),
                }
            }
    
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Error updating threshold range: {str(e)}")


@app.put("/rooms/assign-departments")
def assign_room_departments(assignments: dict):
    """
    Bulk-assign departments to rooms.
    Body: {"ROOM_302": "CS", "ROOM_101": "CS", "ROOM_405": "EC", ...}
    Also call with {} to auto-assign based on floor if departments are all null.
    """
    try:
        with engine.begin() as conn:
            updated = 0
            for room_id, dept in assignments.items():
                conn.execute(
                    text("UPDATE rooms SET department = :dept WHERE room_id = :rid"),
                    {"dept": dept, "rid": room_id}
                )
                updated += 1

            # If no explicit assignments given, auto-fill nulls by floor convention
            if not assignments:
                conn.execute(text("""
                    UPDATE rooms SET department = 'CS'
                    WHERE department IS NULL OR department = ''
                """))
                updated = -1  # signal: auto-filled

        return {"status": "success", "updated": updated,
                "message": "Departments assigned. Re-run GET /rooms to verify."}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/rooms/departments")
def get_room_departments():
    """Show each room's current department value — for debugging."""
    try:
        with engine.connect() as conn:
            rows = conn.execute(text(
                "SELECT room_id, room_name, department FROM rooms ORDER BY room_id"
            )).fetchall()
        return [{"room_id": r[0], "room_name": r[1], "department": r[2]} for r in rows]
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# ── FCM Token Registration ────────────────────────────────────────────────────
class FCMTokenRequest(BaseModel):
    user_email: str
    user_role:  str          # 'coordinator', 'student', 'admin'
    department: str = None
    fcm_token:  str
    device_info: str = ""

@app.post("/fcm/register-token")
def register_fcm_token(req: FCMTokenRequest):
    """
    Called by Flutter immediately after login to register the device FCM token.
    Stores token in fcm_tokens table so the backend can push alerts.
    """
    try:
        import importlib.util as _ilu
        _here = os.path.dirname(os.path.abspath(__file__))
        _spec = _ilu.spec_from_file_location("fcm_service",
                    os.path.join(_here, "fcm_service.py"))
        _fcm  = _ilu.module_from_spec(_spec)
        _spec.loader.exec_module(_fcm)
        ok = _fcm.register_token(
            user_email  = req.user_email,
            user_role   = req.user_role,
            department  = req.department,
            fcm_token   = req.fcm_token,
            device_info = req.device_info,
        )
        return {"status": "ok" if ok else "error"}
    except Exception as e:
        print(f"[FCM register] {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.delete("/fcm/remove-token")
def remove_fcm_token(fcm_token: str):
    """Called on logout to deregister the device token."""
    try:
        from sqlalchemy import text as _text
        with engine.begin() as conn:
            conn.execute(_text("DELETE FROM fcm_tokens WHERE fcm_token = :t"),
                         {"t": fcm_token})
        return {"status": "removed"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))



@app.get("/health")
def health():
    return {"status": "ok"}

def _generate_short_password(length: int = 6) -> str:
    """Generate a 6-char password with letters, digits, and a symbol (unique chars)."""
    if length < 3:
        raise ValueError("Password length must be at least 3")

    letters = string.ascii_letters
    digits = string.digits
    symbols = "!@#$%*"

    # Ensure at least one of each
    password_chars = [
        secrets.choice(letters),
        secrets.choice(digits),
        secrets.choice(symbols),
    ]

    # Fill the rest with unique characters
    pool = list(set(letters + digits + symbols) - set(password_chars))
    secrets.SystemRandom().shuffle(pool)
    password_chars.extend(pool[: length - 3])

    # Shuffle final password
    secrets.SystemRandom().shuffle(password_chars)
    return "".join(password_chars)
