"""
Minimal authentication API for users.
- /auth/register  POST {"username","password","role"}
- /auth/login     POST {"username","password"} -> returns JWT

This uses SQLAlchemy to talk to Postgres (DB_URL env var) and PyJWT for tokens.
"""

import os
import sys
import importlib
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

# Pydantic models

class RegisterRequest(BaseModel):
    username: str
    password: str
    role: str = "student"
    ktu_id: str = None  # Required for student registration
    department: str = None  # Required for student registration
    year: str = None  # Required for student registration
    email: str = None  # Email address for student registration

class InviteUserRequest(BaseModel):
    """Payload for admin invite endpoint.
    Admin generates an OTP server-side, so no password is required.
    """
    username: str
    role: str = "student"
    name: str | None = None
    ktu_id: str | None = None
    department: str | None = None
    year: str | None = None
    email: str | None = None

class LoginRequest(BaseModel):
    username: str
    password: str
    department: str | None = None  # Required for coordinator login

class UpdateProfileRequest(BaseModel):
    ktu_id: str
    name: str
    department: str
    year: str

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
            text("UPDATE class_representatives SET name = :n, department = :d, year = :y WHERE ktu_id = :k"),
            {"n": req.name, "d": req.department, "y": req.year, "k": req.ktu_id}
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

    # Normalize email field
    target_email = req.email or req.username
    if target_table in {"coordinators", "admins"} and not target_email:
        raise HTTPException(status_code=400, detail="Email is required for admins and coordinators")

    coordinator_id = None

    with engine.begin() as conn:
        # Check if user already exists in the chosen table
        existing = conn.execute(
            text(f"SELECT id FROM {target_table} WHERE { 'username' if target_table == 'class_representatives' else 'email' } = :u"),
            {"u": req.username if target_table == "class_representatives" else target_email},
        ).fetchone()

        if existing:
            if target_table == "class_representatives":
                query = text("UPDATE class_representatives SET password_hash=:p, name=:n, department=:d, ktu_id=:k, year=:y, email=:e WHERE id=:i")
                params = {
                    "p": pw_hash,
                    "n": req.name,
                    "d": req.department,
                    "k": req.ktu_id,
                    "y": req.year,
                    "e": target_email,
                    "i": existing[0],
                }
            elif target_table == "coordinators":
                # Fetch existing coordinator_id so email never shows None
                coordinator_id_row = conn.execute(
                    text("SELECT coordinator_id FROM coordinators WHERE id = :i"),
                    {"i": existing[0]}
                ).fetchone()
                coordinator_id = coordinator_id_row[0] if coordinator_id_row else None

                query = text("UPDATE coordinators SET password_hash=:p, name=:n, department=:d, email=:e WHERE id=:i")
                params = {"p": pw_hash, "n": req.name, "d": req.department, "e": target_email, "i": existing[0]}
            else:  # admins
                query = text("UPDATE admins SET password_hash=:p, name=:n, email=:e WHERE id=:i")
                params = {"p": pw_hash, "n": req.name, "e": target_email, "i": existing[0]}
            action = "updated"
        else:
            if target_table == "class_representatives":
                query = text(
                    "INSERT INTO class_representatives (username, password_hash, name, department, ktu_id, year, email, created_at) "
                    "VALUES (:u, :p, :n, :d, :k, :y, :e, :c)"
                )
                params = {
                    "u": req.username,
                    "p": pw_hash,
                    "n": req.name,
                    "d": req.department,
                    "k": req.ktu_id,
                    "y": req.year,
                    "e": target_email,
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
                    "INSERT INTO coordinators (coordinator_id, email, password_hash, name, department, created_at) "
                    "VALUES (:cid, :e, :p, :n, :d, :c)"
                )
                params = {
                    "cid": coordinator_id,
                    "e": target_email,
                    "p": pw_hash,
                    "n": req.name,
                    "d": req.department,
                    "c": datetime.utcnow(),
                }
            else:  # admins
                query = text(
                    "INSERT INTO admins (email, password_hash, name, created_at) "
                    "VALUES (:e, :p, :n, :c)"
                )
                params = {
                    "e": target_email,
                    "p": pw_hash,
                    "n": req.name,
                    "c": datetime.utcnow(),
                }
            action = "created"

        try:
            conn.execute(query, params)
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
        await fm.send_message(message)
        email_status = "sent"
    except Exception as e:
        # Log error but don't fail the invite if email fails
        print(f"Warning: Failed to send email to {req.username}: {e}")
        email_status = "failed"
    
    return {
        "status": f"User {action} successfully",
        "username": req.username,
        "role": req.role,
        "email_status": email_status,
        "message": f"Invitation {'sent' if email_status == 'sent' else 'created but email sending failed'}"
    }
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
                text("INSERT INTO class_representatives (username, password_hash, ktu_id, email, department, year, created_at) VALUES (:u, :p, :k, :e, :d, :y, :c)"),
                {"u": req.username, "p": pw_hash, "k": req.ktu_id, "e": req.email, "d": req.department, "y": req.year, "c": datetime.utcnow()},
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
                    text("INSERT INTO admins (email, password_hash, name, created_at) VALUES (:e, :p, :n, :c)"),
                    {"e": req.email, "p": pw_hash, "n": req.username or req.email, "c": datetime.utcnow()},
                )
            else:
                row = conn.execute(text("SELECT id FROM coordinators WHERE email=:e"), {"e": req.email}).fetchone()
                if row:
                    raise HTTPException(status_code=400, detail="Coordinator already exists")
                pw_hash = PWD_CTX.hash(req.password)
                conn.execute(
                    text("INSERT INTO coordinators (email, password_hash, name, department, created_at) VALUES (:e, :p, :n, :d, :c)"),
                    {"e": req.email, "p": pw_hash, "n": req.username or req.email, "d": req.department, "c": datetime.utcnow()},
                )
    return {"status": "ok"}


@app.post("/login")
def login(req: LoginRequest, request: Request):
    try:
        client_ip = request.client.host if request.client else "0.0.0.0"
        
        with engine.begin() as conn:
            # Try admin by username first
            admin_row = conn.execute(
                text("SELECT id, password_hash, name, email, username FROM admins WHERE UPPER(username)=UPPER(:u)"),
                {"u": req.username.strip()},
            ).fetchone()

            coordinator_row = None
            if not admin_row:
                # Try coordinator by coordinator_id only
                coordinator_row = conn.execute(
                    text("SELECT id, password_hash, name, department, email, coordinator_id FROM coordinators WHERE UPPER(coordinator_id)=UPPER(:u)"),
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
                    text("SELECT id, password_hash, department, ktu_id, year, username, name, email FROM class_representatives WHERE UPPER(ktu_id)=UPPER(:u) OR UPPER(email)=UPPER(:u) OR UPPER(username)=UPPER(:u)"),
                    {"u": req.username.strip()},
                ).fetchone()

            if admin_row:
                u_id, pw_hash, name, email, username = admin_row
                role = "admin"
                dept, ktu, year = None, None, None
            elif coordinator_row:
                u_id, pw_hash, name, dept, email, coordinator_id = coordinator_row
                role = "coordinator"
                ktu, year = None, None
            elif class_rep_row:
                u_id, pw_hash, dept, ktu, year, username_val, name, email_from_table = class_rep_row
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

@app.get("/users/coordinators")
def get_coordinators():
    """Fetch all coordinators from the database."""
    with engine.begin() as conn:
        result = conn.execute(
            text(
                "SELECT id, email, name, department, created_at FROM coordinators ORDER BY name ASC"
            )
        ).fetchall()
        
        coordinators = []
        for row in result:
            coordinators.append({
                "id": row[0],
                "username": row[1],
                "name": row[2] or row[1],
                "department": row[3] or "N/A",
                "created_at": row[4].isoformat() if row[4] else None,
            })
        
        return {"coordinators": coordinators, "total": len(coordinators)}


@app.get("/users/class-representatives")
def get_class_representatives():
    """Fetch all class representatives from the database."""
    with engine.begin() as conn:
        result = conn.execute(
            text("""
                SELECT id, username, name, ktu_id, department, year, email, created_at 
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
                "created_at": row[7].isoformat() if row[7] else None
            })
        
        return {"class_representatives": class_reps, "total": len(class_reps)}


@app.get("/users/counts")
def get_user_counts():
    """Fetch user counts from the database."""
    with engine.begin() as conn:
        coordinator_count = conn.execute(text("SELECT COUNT(*) FROM coordinators")).scalar()
        class_rep_count = conn.execute(text("SELECT COUNT(*) FROM class_representatives")).scalar()
        
        # Total users (excluding admins)
        total_users = coordinator_count + class_rep_count
        
        return {
            "total_users": total_users,
            "coordinators": coordinator_count,
            "class_representatives": class_rep_count
        }


# Cache for dashboard overview to reduce DB load
_overview_cache = {"data": None, "timestamp": None}
_overview_cache_ttl = 30  # seconds

@app.get("/dashboard/overview")
def get_dashboard_overview(active_window_minutes: int = 5, usage_window_hours: int = 1):
    """Return campus-wide live metrics for the admin dashboard (cached for 30s).

    - total_usage_kwh: Sum of power over time in the last hour (kWh estimate)
    - active_rooms / total_rooms: Distinct device_ids sending data within `active_window_minutes`
    - inactive_rooms: List of device_ids that have NOT reported within the active window
    - efficiency_percent: Simple availability metric = active_rooms / total_rooms * 100
    """
    
    # Check cache first
    now = datetime.now(timezone.utc)
    if _overview_cache["data"] and _overview_cache["timestamp"]:
        age = (now - _overview_cache["timestamp"]).total_seconds()
        if age < _overview_cache_ttl:
            return _overview_cache["data"]

    # Sanitize windows - use shorter defaults for speed
    active_window_minutes = max(1, min(active_window_minutes, 60))
    usage_window_hours = max(1, min(usage_window_hours, 24))

    active_interval = f"{active_window_minutes} minutes"
    usage_interval = f"{usage_window_hours} hours"

    with engine.begin() as conn:
        # Optimized: Sum power (watts) over time and convert to kWh
        # If power readings are per minute, divide by 60 to get kWh
        total_usage_wh = conn.execute(
            text(
                """
                SELECT COALESCE(SUM(COALESCE(power, value, 0)), 0) / 60.0
                FROM (
                    SELECT power, value FROM sensor_data
                    WHERE ds >= NOW() - CAST(:usage_interval AS INTERVAL)
                    ORDER BY ds DESC
                    LIMIT 10000
                ) subq
                """
            ),
            {"usage_interval": usage_interval},
        ).scalar() or 0

        # Fast total rooms count from recent data only
        total_rooms = conn.execute(
            text(
                """
                SELECT COUNT(DISTINCT device_id) 
                FROM sensor_data 
                WHERE ds >= NOW() - INTERVAL '7 days'
                """
            )
        ).scalar() or 0

        # Active rooms in last N minutes
        active_rooms = conn.execute(
            text(
                """
                SELECT COUNT(DISTINCT device_id)
                FROM sensor_data
                WHERE ds >= NOW() - CAST(:active_interval AS INTERVAL)
                """
            ),
            {"active_interval": active_interval},
        ).scalar() or 0

        # Inactive rooms - simplified query
        inactive_rows = conn.execute(
            text(
                """
                SELECT DISTINCT d1.device_id
                FROM (
                    SELECT DISTINCT device_id FROM sensor_data
                    WHERE ds >= NOW() - INTERVAL '7 days'
                    LIMIT 100
                ) d1
                WHERE d1.device_id NOT IN (
                    SELECT DISTINCT device_id
                    FROM sensor_data
                    WHERE ds >= NOW() - CAST(:active_interval AS INTERVAL)
                )
                ORDER BY d1.device_id
                LIMIT 100
                """
            ),
            {"active_interval": active_interval},
        ).fetchall()

    total_usage_kwh = float(total_usage_wh) / 1000.0
    efficiency_percent = 0.0
    if total_rooms > 0:
        efficiency_percent = (active_rooms / total_rooms) * 100.0

    result = {
        "total_usage_kwh": round(total_usage_kwh, 3),
        "active_rooms": active_rooms,
        "total_rooms": total_rooms,
        "inactive_rooms": [row[0] for row in inactive_rows],
        "efficiency_percent": round(efficiency_percent, 1),
        "active_window_minutes": active_window_minutes,
        "usage_window_hours": usage_window_hours,
    }
    
    # Cache the result
    _overview_cache["data"] = result
    _overview_cache["timestamp"] = now
    
    return result


@app.delete("/users/{username}")
def delete_user(username: str):
    """Delete a user (coordinator or class representative) by username."""
    with engine.begin() as conn:
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

        deleted_count = result_admin.rowcount + result_coord.rowcount + result_reps.rowcount

        if deleted_count == 0:
            raise HTTPException(status_code=404, detail=f"User '{username}' not found or cannot be deleted")
        
        return {"status": "success", "message": f"User '{username}' deleted successfully", "deleted_count": deleted_count}


@app.post("/sensor-data")
async def receive_sensor_data(request: Request):
    """
    Receive sensor data from ESP32 and store it in the database.
    
    Expected JSON payload:
    {
        "device_id": "ESP32-LAB-001",
        "voltage": 230.5,
        "current": 2.3,
        "power": 529.15,
        "energy": 1.5,
        "frequency": 50.0,
        "power_factor": 0.95
    }
    """
    try:
        payload = await request.json()
        
        # Store raw JSON payload for debugging and data recovery
        import json
        raw_json = json.dumps(payload)

        device_id = payload.get("device_id", "unknown")

        # Extract metrics, cast to float where present
        def _to_float(key, default=None):
            v = payload.get(key, default)
            if v is None:
                return None
            try:
                return float(v)
            except Exception:
                raise HTTPException(status_code=400, detail=f"Invalid numeric value for '{key}': {v}")

        voltage = _to_float("voltage")
        current = _to_float("current")
        power = _to_float("power")
        energy = _to_float("energy")
        frequency = _to_float("frequency")
        power_factor = _to_float("power_factor")

        # Maintain legacy 'value' field (use power if provided)
        value = power if power is not None else _to_float("value", 0)

        timestamp = datetime.now(timezone.utc)

        with engine.begin() as conn:
            # Store in sensor_data table (processed)
            conn.execute(
                text(
                    "INSERT INTO sensor_data(ds, device_id, value, voltage, current, power, energy, frequency, power_factor) "
                    "VALUES (:ds, :device_id, :value, :voltage, :current, :power, :energy, :frequency, :power_factor)"
                ),
                {
                    "ds": timestamp,
                    "device_id": device_id,
                    "value": float(value) if value is not None else None,
                    "voltage": voltage,
                    "current": current,
                    "power": power,
                    "energy": energy,
                    "frequency": frequency,
                    "power_factor": power_factor,
                },
            )
            
            # Store in esp32_raw_data table (raw payload)
            conn.execute(
                text(
                    "INSERT INTO esp32_raw_data(device_id, raw_payload, voltage, current, power, energy, frequency, power_factor, timestamp, processed) "
                    "VALUES (:device_id, :raw_payload, :voltage, :current, :power, :energy, :frequency, :power_factor, :timestamp, :processed)"
                ),
                {
                    "device_id": device_id,
                    "raw_payload": raw_json,
                    "voltage": voltage,
                    "current": current,
                    "power": power,
                    "energy": energy,
                    "frequency": frequency,
                    "power_factor": power_factor,
                    "timestamp": timestamp,
                    "processed": 1,  # Mark as processed since we're storing it
                },
            )

            # Log this activity
            activity_logger.log_activity(
                user_id=device_id,
                action_type="data_submission",
                resource_type="sensor",
                resource_id=device_id,
                action_description=f"Sensor reading inserted: power={power}W",
            )

        return {
            "status": "success",
            "message": f"Sensor data from {device_id} received and stored",
            "device_id": device_id,
            "value": value,
            "voltage": voltage,
            "current": current,
            "power": power,
            "energy": energy,
            "frequency": frequency,
            "power_factor": power_factor,
            "timestamp": timestamp.isoformat(),
        }

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Error processing sensor data: {str(e)}")


@app.get("/sensor-data")
def get_sensor_data(device_id: str = None, limit: int = 100):
    """
    Retrieve sensor data from the database.
    
    Query parameters:
    - device_id: Filter by specific device (optional)
    - limit: Maximum number of records to return (default: 100)
    """
    try:
        with engine.begin() as conn:
            if device_id:
                result = conn.execute(
                    text("""
                        SELECT id, ds, device_id, value, voltage, current, power, energy, frequency, power_factor 
                        FROM sensor_data 
                        WHERE device_id = :device_id
                        ORDER BY ds DESC 
                        LIMIT :limit
                    """),
                    {"device_id": device_id, "limit": limit}
                )
            else:
                result = conn.execute(
                    text("""
                        SELECT id, ds, device_id, value, voltage, current, power, energy, frequency, power_factor 
                        FROM sensor_data 
                        ORDER BY ds DESC 
                        LIMIT :limit
                    """),
                    {"limit": limit}
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
                    "power_factor": row[9]
                }
                for row in rows
            ]
            
            return {
                "status": "success",
                "count": len(data),
                "data": data
            }
    
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Error retrieving sensor data: {str(e)}")


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
