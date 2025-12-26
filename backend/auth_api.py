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

app = FastAPI(title="Auth Service")

# Default to a local PostgreSQL instance (mapped from Docker or native install).
# Override with DB_URL when running inside Docker (e.g., host `db`).
DB_URL = os.environ.get("DB_URL", "postgresql://postgres:ajith%40@localhost:5432/energia")
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
    email: str | None = None  # Required for student registration

class LoginRequest(BaseModel):
    username: str
    password: str


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


@app.post("/login")
def login(req: LoginRequest):
    with engine.begin() as conn:
        # Check in users table first (for coordinators and admins)
        row = conn.execute(text("SELECT id, password_hash, role, department FROM users WHERE username = :u"), {"u": req.username}).fetchone()
        
        # If not found in users, check class_representatives table (for students)
        if not row:
            row = conn.execute(
                text("SELECT id, password_hash, 'student' as role, department FROM class_representatives WHERE username = :u"),
                {"u": req.username}
            ).fetchone()
        
        if not row:
            raise HTTPException(status_code=401, detail="Invalid credentials")
        
        user_id, pw_hash, role, department = row
        if not PWD_CTX.verify(req.password, pw_hash):
            raise HTTPException(status_code=401, detail="Invalid credentials")
        
        # Create JWT
        payload = {
            "sub": str(user_id),
            "username": req.username,
            "role": role,
            "department": department,
            "exp": datetime.utcnow() + timedelta(hours=12)
        }
        token = jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALG)
        return {"access_token": token, "token_type": "bearer"}


@app.get("/health")
def health():
    return {"status": "ok"}
