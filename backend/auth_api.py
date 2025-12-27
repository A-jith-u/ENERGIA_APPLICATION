"""
Minimal authentication API for users.
- /auth/register  POST {"username","password","role"}
- /auth/login     POST {"username","password"} -> returns JWT

This uses SQLAlchemy to talk to Postgres (DB_URL env var) and PyJWT for tokens.
"""

import os
from fastapi import FastAPI, HTTPException, Depends
from pydantic import BaseModel
from sqlalchemy import create_engine, text
from . import config as cfg
from passlib.context import CryptContext
import jwt
from datetime import datetime, timedelta, timezone
import secrets
from fastapi_mail import FastMail, MessageSchema, ConnectionConfig
from sqlalchemy.exc import SQLAlchemyError

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
def change_password(req: ChangePasswordRequest):
    with engine.begin() as conn:
        # 1. Fetch current hash to verify the user
        res = conn.execute(
            text("SELECT password_hash FROM class_representatives WHERE ktu_id = :u OR username = :u"),
            {"u": req.username}
        ).fetchone()
        
        if not res:
            res = conn.execute(
                text("SELECT password_hash FROM users WHERE username = :u"),
                {"u": req.username}
            ).fetchone()

        # 2. Verify current password before allowing change
        if not res or not PWD_CTX.verify(req.current_password, res[0]):
            raise HTTPException(status_code=401, detail="Current password is incorrect")

        # 3. Update to new hash
        new_hash = PWD_CTX.hash(req.new_password)
        conn.execute(
            text("UPDATE class_representatives SET password_hash = :p WHERE ktu_id = :u OR username = :u"),
            {"p": new_hash, "u": req.username}
        )
        conn.execute(
            text("UPDATE users SET password_hash = :p WHERE username = :u"),
            {"p": new_hash, "u": req.username}
        )
        
    return {"status": "Password updated successfully"}


@app.post("/request-password-reset")
async def request_password_reset(req: PasswordResetRequest):
    otp = f"{secrets.randbelow(10**OTP_LENGTH):0{OTP_LENGTH}d}"
    otp_hash = PWD_CTX.hash(otp)
    expires_at = datetime.now(timezone.utc) + timedelta(minutes=OTP_TTL_MINUTES)

    # Locate user email and table
    with engine.begin() as conn:
        res = conn.execute(
            text(
                "SELECT email FROM class_representatives WHERE UPPER(ktu_id)=UPPER(:u) OR UPPER(username)=UPPER(:u)"
            ),
            {"u": req.username},
        ).fetchone()

        if res:
            email = res[0] or req.username
        else:
            res_user = conn.execute(
                text("SELECT username FROM users WHERE UPPER(username)=UPPER(:u)"),
                {"u": req.username},
            ).fetchone()
            if not res_user:
                raise HTTPException(status_code=404, detail="User not found")
            email = res_user[0]

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

        # Update both tables where applicable
        conn.execute(
            text(
                "UPDATE class_representatives SET password_hash = :p WHERE UPPER(ktu_id)=UPPER(:u) OR UPPER(username)=UPPER(:u)"
            ),
            {"p": new_hash, "u": req.username},
        )
        conn.execute(
            text("UPDATE users SET password_hash = :p WHERE UPPER(username)=UPPER(:u)"),
            {"p": new_hash, "u": req.username},
        )

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

@app.post("/change-password")
def change_password(ktu_id: str, new_password: str):
    pw_hash = PWD_CTX.hash(new_password)
    with engine.begin() as conn:
        conn.execute(
            text("UPDATE class_representatives SET password_hash = :p WHERE ktu_id = :k"),
            {"p": pw_hash, "k": ktu_id}
        )
    return {"status": "Password changed successfully"}

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
def _get_invite_email_template(role: str, username: str, password: str, name: str) -> tuple[str, str]:
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
                    <strong>Username/Email:</strong> {username}<br/>
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
                    <li>Log in to the ENERGIA application using your credentials</li>
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
    # Generate a secure temporary password
    otp = secrets.token_urlsafe(12)  # 12-char base64-encoded string
    pw_hash = PWD_CTX.hash(otp)
    role_lower = req.role.lower()
    
    # Determine target table based on role
    table = "class_representatives" if ("student" in role_lower or "representative" in role_lower) else "users"
    
    with engine.begin() as conn:
        # Check if user already exists
        existing = conn.execute(
            text(f"SELECT id FROM {table} WHERE username = :u"),
            {"u": req.username}
        ).fetchone()

        if existing:
            # Update existing user with new password and name
            query = text(f"UPDATE {table} SET password_hash = :p, name = :n WHERE username = :u")
            params = {"u": req.username, "p": pw_hash, "n": req.name}
            action = "updated"
        else:
            # Insert new user into appropriate table
            if table == "class_representatives":
                query = text(
                    f"INSERT INTO {table} (username, password_hash, name, department, ktu_id, year, email, created_at) "
                    "VALUES (:u, :p, :n, :d, :k, :y, :e, :c)"
                )
                params = {
                    "u": req.username,
                    "p": pw_hash,
                    "n": req.name,
                    "d": req.department,
                    "k": req.ktu_id,
                    "y": req.year,
                    "e": req.username,  # email = username for class reps
                    "c": datetime.utcnow(),
                }
            else:
                # Coordinator or admin user
                query = text(
                    f"INSERT INTO {table} (username, password_hash, role, name, created_at) "
                    "VALUES (:u, :p, :r, :n, :c)"
                )
                params = {
                    "u": req.username,
                    "p": pw_hash,
                    "r": req.role,
                    "n": req.name,
                    "c": datetime.utcnow(),
                }
            action = "created"
        
        conn.execute(query, params)
    
    # Prepare role-specific email
    # For class representatives, show KTU ID as the username in the email
    display_username = req.username
    if "student" in role_lower or "representative" in role_lower:
        display_username = req.ktu_id or req.username
    subject, email_body = _get_invite_email_template(
        role=req.role,
        username=display_username,
        password=otp,
        name=req.name or "User"
    )
    
    # Send email with credentials
    try:
        message = MessageSchema(
            subject=subject,
            recipients=[req.username],
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
        # Non-student registration (admin/coordinator) - no KTU verification
        with engine.begin() as conn:
            row = conn.execute(text("SELECT id FROM users WHERE username = :u"), {"u": req.username}).fetchone()
            if row:
                raise HTTPException(status_code=400, detail="User already exists")
            pw_hash = PWD_CTX.hash(req.password)
            conn.execute(
                text("INSERT INTO users (username, password_hash, role, created_at) VALUES (:u, :p, :r, :c)"),
                {"u": req.username, "p": pw_hash, "r": req.role, "c": datetime.utcnow()},
            )
    return {"status": "ok"}


@app.post("/login")
def login(req: LoginRequest):
    with engine.begin() as conn:
        # Fetch 'name' in the SELECT query
        res = conn.execute(
            text("SELECT id, password_hash, department, ktu_id, year, username, name "
                 "FROM class_representatives WHERE UPPER(ktu_id) = UPPER(:u)"),
            {"u": req.username.strip()}
        ).fetchone()

        if res:
            u_id, pw_hash, dept, ktu, year, email, name = res # Unpack name
            role = 'student'
        else:
            res = conn.execute(
                text("SELECT id, password_hash, role, department, name FROM users WHERE UPPER(username) = UPPER(:u)"), 
                {"u": req.username.strip()}
            ).fetchone()
            if not res: raise HTTPException(status_code=401, detail="User not found")
            u_id, pw_hash, role, dept, name = res
            ktu, year, email = None, None, req.username.strip()

        if not PWD_CTX.verify(req.password, pw_hash):
            raise HTTPException(status_code=401, detail="Invalid credentials")

        payload = {
            "sub": str(u_id),
            "username": email,
            "name": name, # No more NameError
            "role": role,
            "department": dept,
            "ktu_id": ktu,
            "year": year,
            "exp": datetime.utcnow() + timedelta(hours=12)
        }
        return {"access_token": jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALG), "token_type": "bearer"}

@app.get("/users/coordinators")
def get_coordinators():
    """Fetch all coordinators from the database."""
    with engine.begin() as conn:
        result = conn.execute(
            text("""
                SELECT id, username, name, department, created_at 
                FROM users 
                WHERE role = 'coordinator'
                ORDER BY name ASC
            """)
        ).fetchall()
        
        coordinators = []
        for row in result:
            coordinators.append({
                "id": row[0],
                "username": row[1],
                "name": row[2] or row[1],  # fallback to username if name is null
                "department": row[3] or "N/A",
                "created_at": row[4].isoformat() if row[4] else None
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
        # Count coordinators
        coordinator_count = conn.execute(
            text("SELECT COUNT(*) FROM users WHERE role = 'coordinator'")
        ).scalar()
        
        # Count class representatives
        class_rep_count = conn.execute(
            text("SELECT COUNT(*) FROM class_representatives")
        ).scalar()
        
        # Count admins
        admin_count = conn.execute(
            text("SELECT COUNT(*) FROM users WHERE role = 'admin'")
        ).scalar()
        
        # Total users
        total_users = coordinator_count + class_rep_count + admin_count
        
        return {
            "total_users": total_users,
            "coordinators": coordinator_count,
            "class_representatives": class_rep_count,
            "admins": admin_count
        }


@app.delete("/users/{username}")
def delete_user(username: str):
    """Delete a user (coordinator or class representative) by username."""
    with engine.begin() as conn:
        # Try to delete from users table (coordinators)
        result_users = conn.execute(
            text("DELETE FROM users WHERE username = :u AND role IN ('coordinator', 'class_representative')"),
            {"u": username}
        )
        
        # Try to delete from class_representatives table
        result_reps = conn.execute(
            text("DELETE FROM class_representatives WHERE username = :u OR ktu_id = :u"),
            {"u": username}
        )
        
        deleted_count = result_users.rowcount + result_reps.rowcount
        
        if deleted_count == 0:
            raise HTTPException(status_code=404, detail=f"User '{username}' not found or cannot be deleted")
        
        return {"status": "success", "message": f"User '{username}' deleted successfully", "deleted_count": deleted_count}


@app.get("/health")
def health():
    return {"status": "ok"}
