"""
Sergeant User Management API - Handles sergeant user creation,authentication, and profile management.
Implements 2-sergeant limit and email invitation system.
"""
from datetime import datetime
from typing import Optional
import secrets
import string
import re
from fastapi import FastAPI, HTTPException, Header
from pydantic import BaseModel, EmailStr, validator
from sqlalchemy import create_engine, text, func, select
import jwt
import os
from dotenv import load_dotenv
from passlib.context import CryptContext
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

load_dotenv()

import config

DB_URL = config.get_db_url()
engine = create_engine(DB_URL, pool_pre_ping=True)

app = FastAPI(title="Sergeant Management API")

pwd_context = CryptContext(schemes=["pbkdf2_sha256"], deprecated="auto")
JWT_SECRET = os.getenv("JWT_SECRET", "your-secret-key")
ALGORITHM = "HS256"

# Email configuration
SMTP_SERVER = os.getenv("MAIL_SERVER") or os.getenv("SMTP_SERVER", "smtp.gmail.com")
SMTP_PORT = int(os.getenv("MAIL_PORT") or os.getenv("SMTP_PORT", "587"))
SMTP_USERNAME = os.getenv("MAIL_USERNAME") or os.getenv("SMTP_USERNAME") or os.getenv("SMTP_USER", "")
SMTP_PASSWORD = os.getenv("MAIL_PASSWORD") or os.getenv("SMTP_PASSWORD", "")
FROM_EMAIL = os.getenv("MAIL_FROM") or os.getenv("FROM_EMAIL") or os.getenv("SMTP_FROM", "noreply@energia.edu")
MAIL_STARTTLS = (os.getenv("MAIL_STARTTLS", "true").lower() in {"1", "true", "yes"})
MAIL_SSL_TLS = (os.getenv("MAIL_SSL_TLS", "false").lower() in {"1", "true", "yes"})


class SergeantCreate(BaseModel):
    """Model for creating a new sergeant."""
    email: EmailStr
    name: str
    phone: str

    @validator('name')
    def validate_name(cls, v):
        if len(v.strip()) < 3:
            raise ValueError('Name must be at least 3 characters long')
        if not re.match(r'^[a-zA-Z\s]+$', v):
            raise ValueError('Name can only contain letters and spaces')
        return v.strip()

    @validator('phone')
    def validate_phone(cls, v):
        # Remove spaces, dashes, parentheses
        cleaned = re.sub(r'[\s\-\(\)]', '', v)
        if not re.match(r'^\+?[0-9]{10,15}$', cleaned):
            raise ValueError('Phone number must be 10-15 digits, optionally starting with +')
        return cleaned


class SergeantLogin(BaseModel):
    """Model for sergeant login."""
    sergeant_id: str
    password: str


class SergeantProfile(BaseModel):
    """Model for sergeant profile update."""
    name: Optional[str] = None
    phone: Optional[str] = None
    password: Optional[str] = None


def generate_password(length: int = 6) -> str:
    """Generate a random 6-character alphanumeric password."""
    characters = string.ascii_letters + string.digits
    return ''.join(secrets.choice(characters) for _ in range(length))


def generate_sergeant_id() -> str:
    """Generate next sequential sergeant ID (SGT001, SGT002, etc.)."""
    with engine.connect() as conn:
        result = conn.execute(text("""
            SELECT COUNT(*) FROM sergeants WHERE sergeant_id LIKE 'SGT%'
        """))
        count = result.scalar() or 0
        return f"SGT{count + 1:03d}"


def send_welcome_email(email: str, name: str, sergeant_id: str, password: str) -> tuple[bool, str]:
    """Send welcome email with login credentials."""
    try:
        msg = MIMEMultipart('alternative')
        msg['Subject'] = f"Welcome to ENERGIA - Your Sergeant Account"
        msg['From'] = FROM_EMAIL
        msg['To'] = email

        html_content = f"""
        <html>
          <body>
            <h2>Welcome to ENERGIA, {name}!</h2>
            <p>Your sergeant account has been created successfully.</p>
            
            <h3>Login Credentials:</h3>
            <ul>
              <li><strong>Sergeant ID:</strong> {sergeant_id}</li>
              <li><strong>Password:</strong> {password}</li>
            </ul>
            
            <p>Please login to your dashboard and update your profile.</p>
            <p><strong>Important:</strong> Please change your password after first login for security.</p>
            
            <br>
            <p>Best regards,<br>ENERGIA Team</p>
          </body>
        </html>
        """
        
        msg.attach(MIMEText(html_content, 'html'))

        if not SMTP_USERNAME or not SMTP_PASSWORD:
            print("[EMAIL ERROR] Missing MAIL/SMTP credentials. Configure MAIL_USERNAME and MAIL_PASSWORD.")
            print(f"[EMAIL DEBUG] Intended recipient: {email}, Sergeant ID: {sergeant_id}")
            return False, "Missing MAIL/SMTP credentials"

        if MAIL_SSL_TLS or SMTP_PORT == 465:
            with smtplib.SMTP_SSL(SMTP_SERVER, SMTP_PORT) as server:
                server.login(SMTP_USERNAME, SMTP_PASSWORD)
                server.send_message(msg)
        else:
            with smtplib.SMTP(SMTP_SERVER, SMTP_PORT) as server:
                if MAIL_STARTTLS:
                    server.starttls()
                server.login(SMTP_USERNAME, SMTP_PASSWORD)
                server.send_message(msg)
        return True, "Email sent"
    except Exception as e:
        print(f"Error sending email: {e}")
        return False, str(e)


@app.post("/create")
async def create_sergeant(sergeant: SergeantCreate, authorization: Optional[str] = Header(None)):
    """
    Create a new sergeant user. Only admins can create sergeants.
    Maximum 2 sergeants allowed per college.
    """
    try:
        # Verify admin authentication
        if not authorization:
            raise HTTPException(status_code=401, detail="Authentication required")
        
        token = authorization.replace("Bearer ", "")
        try:
            payload = jwt.decode(token, JWT_SECRET, algorithms=[ALGORITHM])
            role = payload.get("role")
            if role != "admin":
                raise HTTPException(status_code=403, detail="Only admins can create sergeants")
        except Exception:
            raise HTTPException(status_code=401, detail="Invalid token")

        with engine.begin() as conn:
            # Check sergeant limit (max 2)
            count_result = conn.execute(text("SELECT COUNT(*) FROM sergeants WHERE is_active = 1"))
            active_count = count_result.scalar() or 0
            
            if active_count >= 2:
                raise HTTPException(
                    status_code=400,
                    detail="Cannot add new sergeant. Maximum limit of 2 sergeants already reached."
                )

            # Check if email already exists
            email_check = conn.execute(
                text("SELECT id FROM sergeants WHERE email = :email"),
                {"email": sergeant.email}
            ).fetchone()
            
            if email_check:
                raise HTTPException(status_code=400, detail="Email already registered")

            # Generate credentials
            sergeant_id = generate_sergeant_id()
            password = generate_password()
            password_hash = pwd_context.hash(password)

            # Insert sergeant
            conn.execute(text("""
                INSERT INTO sergeants 
                (sergeant_id, email, name, phone, password_hash, is_active, created_at, updated_at)
                VALUES 
                (:sergeant_id, :email, :name, :phone, :password_hash, 1, NOW(), NOW())
            """), {
                "sergeant_id": sergeant_id,
                "email": sergeant.email,
                "name": sergeant.name,
                "phone": sergeant.phone,
                "password_hash": password_hash,
            })

        # Send welcome email
        email_sent, email_message = send_welcome_email(sergeant.email, sergeant.name, sergeant_id, password)

        return {
            "status": "success",
            "message": "Sergeant created successfully" if email_sent else "Sergeant created but email sending failed",
            "data": {
                "sergeant_id": sergeant_id,
                "email": sergeant.email,
                "name": sergeant.name,
                "email_sent": email_sent,
                "email_message": email_message,
            },
            "credentials": {
                "sergeant_id": sergeant_id,
                "password": password,  # Return in response for admin to communicate if email fails
            }
        }

    except HTTPException:
        raise
    except Exception as e:
        print(f"Error creating sergeant: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/login")
async def login_sergeant(credentials: SergeantLogin):
    """Authenticate sergeant user and return JWT token."""
    try:
        with engine.connect() as conn:
            result = conn.execute(text("""
                SELECT id, sergeant_id, email, name, password_hash, is_active
                FROM sergeants
                WHERE sergeant_id = :sergeant_id
            """), {"sergeant_id": credentials.sergeant_id}).fetchone()

            if not result:
                raise HTTPException(status_code=401, detail="Invalid credentials")

            sergeant_id_db, sergeant_id, email, name, password_hash, is_active = result

            if not is_active:
                raise HTTPException(status_code=403, detail="Account is inactive")

            if not pwd_context.verify(credentials.password, password_hash):
                raise HTTPException(status_code=401, detail="Invalid credentials")

            # Update last login
            with engine.begin() as update_conn:
                update_conn.execute(text("""
                    UPDATE sergeants SET last_login = NOW() WHERE id = :id
                """), {"id": sergeant_id_db})

            # Generate JWT token
            token_payload = {
                "sub": sergeant_id,
                "sergeant_id": sergeant_id,
                "email": email,
                "name": name,
                "role": "sergeant",
            }
            token = jwt.encode(token_payload, JWT_SECRET, algorithm=ALGORITHM)

            return {
                "status": "success",
                "access_token": token,
                "token_type": "bearer",
                "user": {
                    "sergeant_id": sergeant_id,
                    "email": email,
                    "name": name,
                    "role": "sergeant",
                }
            }

    except HTTPException:
        raise
    except Exception as e:
        print(f"Login error: {e}")
        raise HTTPException(status_code=500, detail="Login failed")


@app.get("/list")
async def list_sergeants(authorization: Optional[str] = Header(None)):
    """List all sergeants. Requires admin authentication."""
    try:
        # Verify admin authentication
        if not authorization:
            raise HTTPException(status_code=401, detail="Authentication required")

        token = authorization.replace("Bearer ", "")
        try:
            payload = jwt.decode(token, JWT_SECRET, algorithms=[ALGORITHM])
            role = payload.get("role")
            if role != "admin":
                raise HTTPException(status_code=403, detail="Admin access required")
        except Exception:
            raise HTTPException(status_code=401, detail="Invalid token")

        with engine.connect() as conn:
            result = conn.execute(text("""
                SELECT sergeant_id, email, name, phone, is_active, last_login, created_at
                FROM sergeants
                ORDER BY created_at DESC
            """))
            
            sergeants = []
            for row in result:
                sergeants.append({
                    "sergeant_id": row[0],
                    "email": row[1],
                    "name": row[2],
                    "phone": row[3],
                    "is_active": bool(row[4]),
                    "last_login": row[5].isoformat() if row[5] else None,
                    "created_at": row[6].isoformat() if row[6] else None,
                })

            return {
                "status": "success",
                "data": sergeants,
                "total": len(sergeants),
                "active_count": sum(1 for s in sergeants if s["is_active"]),
            }

    except HTTPException:
        raise
    except Exception as e:
        print(f"Error listing sergeants: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/profile")
async def get_sergeant_profile(authorization: Optional[str] = Header(None)):
    """Get sergeant profile."""
    try:
        if not authorization:
            raise HTTPException(status_code=401, detail="Authentication required")

        token = authorization.replace("Bearer ", "")
        payload = jwt.decode(token, JWT_SECRET, algorithms=[ALGORITHM])
        sergeant_id = payload.get("sergeant_id")

        with engine.connect() as conn:
            result = conn.execute(text("""
                SELECT sergeant_id, email, name, phone, last_login, created_at
                FROM sergeants
                WHERE sergeant_id = :sergeant_id AND is_active = 1
            """), {"sergeant_id": sergeant_id}).fetchone()

            if not result:
                raise HTTPException(status_code=404, detail="Sergeant not found")

            return {
                "status": "success",
                "data": {
                    "sergeant_id": result[0],
                    "email": result[1],
                    "name": result[2],
                    "phone": result[3],
                    "last_login": result[4].isoformat() if result[4] else None,
                    "created_at": result[5].isoformat() if result[5] else None,
                }
            }

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.put("/profile")
async def update_sergeant_profile(profile: SergeantProfile, authorization: Optional[str] = Header(None)):
    """Update sergeant profile."""
    try:
        if not authorization:
            raise HTTPException(status_code=401, detail="Authentication required")

        token = authorization.replace("Bearer ", "")
        payload = jwt.decode(token, JWT_SECRET, algorithms=[ALGORITHM])
        sergeant_id = payload.get("sergeant_id")

        updates = []
        params = {"sergeant_id": sergeant_id}

        if profile.name:
            if len(profile.name.strip()) < 3:
                raise HTTPException(status_code=400, detail="Name must be at least 3 characters")
            updates.append("name = :name")
            params["name"] = profile.name.strip()

        if profile.phone:
            cleaned_phone = re.sub(r'[\s\-\(\)]', '', profile.phone)
            if not re.match(r'^\+?[0-9]{10,15}$', cleaned_phone):
                raise HTTPException(status_code=400, detail="Invalid phone number format")
            updates.append("phone = :phone")
            params["phone"] = cleaned_phone

        if profile.password:
            if len(profile.password) < 6:
                raise HTTPException(status_code=400, detail="Password must be at least 6 characters")
            updates.append("password_hash = :password_hash")
            params["password_hash"] = pwd_context.hash(profile.password)

        if not updates:
            raise HTTPException(status_code=400, detail="No fields to update")

        updates.append("updated_at = NOW()")

        with engine.begin() as conn:
            conn.execute(text(f"""
                UPDATE sergeants 
                SET {', '.join(updates)}
                WHERE sergeant_id = :sergeant_id
            """), params)

        return {
            "status": "success",
            "message": "Profile updated successfully"
        }

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.delete("/{sergeant_id}")
async def deactivate_sergeant(sergeant_id: str, authorization: Optional[str] = Header(None)):
    """Deactivate a sergeant user. Only admins can deactivate."""
    try:
        if not authorization:
            raise HTTPException(status_code=401, detail="Authentication required")

        token = authorization.replace("Bearer ", "")
        payload = jwt.decode(token, JWT_SECRET, algorithms=[ALGORITHM])
        role = payload.get("role")
        
        if role != "admin":
            raise HTTPException(status_code=403, detail="Only admins can deactivate sergeants")

        with engine.begin() as conn:
            result = conn.execute(text("""
                UPDATE sergeants 
                SET is_active = 0, updated_at = NOW()
                WHERE sergeant_id = :sergeant_id
            """), {"sergeant_id": sergeant_id})

            if result.rowcount == 0:
                raise HTTPException(status_code=404, detail="Sergeant not found")

        return {
            "status": "success",
            "message": f"Sergeant {sergeant_id} deactivated successfully"
        }

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
