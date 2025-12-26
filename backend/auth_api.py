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
from passlib.context import CryptContext
import jwt
from datetime import datetime, timedelta
import secrets
from fastapi_mail import FastMail, MessageSchema, ConnectionConfig
app = FastAPI(title="Auth Service")

# Default to a local PostgreSQL instance (mapped from Docker or native install).
# Override with DB_URL when running inside Docker (e.g., host `db`).
DB_URL = os.environ.get("DB_URL", "postgresql://postgres:aswathy2004@localhost:5432/energia")
JWT_SECRET = os.environ.get("JWT_SECRET", "change-me-in-prod")
JWT_ALG = "HS256"
# Use PBKDF2-SHA256 for hashing to avoid bcrypt binary issues in some environments
PWD_CTX = CryptContext(schemes=["pbkdf2_sha256"], deprecated="auto")

engine = create_engine(DB_URL)

# Pydantic models

class RegisterRequest(BaseModel):
    username: str
    password: str
    role: str = "student"
    ktu_id: str = None  # Required for student registration
    department: str = None  # Required for student registration
    year: str = None  # Required for student registration

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

# Use this version of the change-password endpoint
@app.post("/auth/change-password")
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
@app.post("/auth/update-profile")
def update_profile(req: UpdateProfileRequest):
    with engine.begin() as conn:
        # Update the student record based on KTU ID
        conn.execute(
            text("UPDATE class_representatives SET name = :n, department = :d, year = :y WHERE ktu_id = :k"),
            {"n": req.name, "d": req.department, "y": req.year, "k": req.ktu_id}
        )
    return {"status": "Profile updated successfully"}

@app.post("/auth/change-password")
def change_password(ktu_id: str, new_password: str):
    pw_hash = PWD_CTX.hash(new_password)
    with engine.begin() as conn:
        conn.execute(
            text("UPDATE class_representatives SET password_hash = :p WHERE ktu_id = :k"),
            {"p": pw_hash, "k": ktu_id}
        )
    return {"status": "Password changed successfully"}

conf = ConnectionConfig(
    MAIL_USERNAME = "idukki508@gmail.com",
    MAIL_PASSWORD = "gntjhskjyfmdujqr",
    MAIL_FROM = "idukki508@gmail.com",
    MAIL_PORT = 587,
    MAIL_SERVER = "smtp.gmail.com",
    MAIL_STARTTLS = True,
    MAIL_SSL_TLS = False,
    USE_CREDENTIALS = True
)

@app.post("/auth/admin/invite-user")
async def invite_user(req: RegisterRequest):
    otp = secrets.token_urlsafe(8)
    pw_hash = PWD_CTX.hash(otp)
    role_lower = req.role.lower()
    
    with engine.begin() as conn:
        table = "class_representatives" if ("student" in role_lower or "representative" in role_lower) else "users"
        
        # Check if user exists
        existing = conn.execute(text(f"SELECT id FROM {table} WHERE username = :u"), {"u": req.username}).fetchone()

        if existing:
            # Update name and OTP
            query = text(f"UPDATE {table} SET password_hash = :p, name = :n WHERE username = :u")
            params = {"u": req.username, "p": pw_hash, "n": req.name}
        else:
            if table == "class_representatives":
                query = text(f"INSERT INTO {table} (username, password_hash, name, department, ktu_id, year, created_at) "
                             "VALUES (:u, :p, :n, :d, :k, :y, now())")
                params = {"u": req.username, "p": pw_hash, "n": req.name, "d": req.department, "k": req.ktu_id, "y": req.year}
            else:
                query = text(f"INSERT INTO {table} (username, password_hash, role, name, created_at) "
                             "VALUES (:u, :p, :r, :n, now())")
                params = {"u": req.username, "p": pw_hash, "r": req.role, "n": req.name}
        
        conn.execute(query, params)
    
    # Send Email logic...
    # ... (Email sending logic) ...
    
    # Send Email (This will now send the NEW OTP that matches the DB)
    message = MessageSchema(
        subject="Welcome to ENERGIA - Your Access Code",
        recipients=[req.username],
        body=f"Your access code is: <b>{otp}</b>",
        subtype="html"
    )
    fm = FastMail(conf)
    await fm.send_message(message)
    return {"status": "Invite sent/updated successfully"}
@app.post("/auth/register")
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
                text("INSERT INTO class_representatives (username, password_hash, ktu_id, email, department, year, created_at) VALUES (:u, :p, :k, :e, :d, :y, now())"),
                {"u": req.username, "p": pw_hash, "k": req.ktu_id, "e": req.email, "d": req.department, "y": req.year},
            )
    else:
        # Non-student registration (admin/coordinator) - no KTU verification
        with engine.begin() as conn:
            row = conn.execute(text("SELECT id FROM users WHERE username = :u"), {"u": req.username}).fetchone()
            if row:
                raise HTTPException(status_code=400, detail="User already exists")
            pw_hash = PWD_CTX.hash(req.password)
            conn.execute(
                text("INSERT INTO users (username, password_hash, role, created_at) VALUES (:u, :p, :r, now())"),
                {"u": req.username, "p": pw_hash, "r": req.role},
            )
    return {"status": "ok"}


@app.post("/auth/login")
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

@app.get("/health")
def health():
    return {"status": "ok"}
