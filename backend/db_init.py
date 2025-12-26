"""Simple DB initializer to create `users` and `sensor_data` tables and insert test users.
Targets PostgreSQL by default; override DB_URL to point at your Postgres instance.
"""
import os
from passlib.context import CryptContext
from sqlalchemy import (
    create_engine,
    MetaData,
    Table,
    Column,
    Integer,
    BigInteger,
    String,
    Text,
    DateTime,
    Float,
    func,
    select,
    inspect,
)

# Default to a local PostgreSQL instance (mapped from Docker or native install).
# Override with DB_URL when running inside Docker (e.g., host `db`).
DB_URL = os.environ.get("DB_URL", "postgresql://postgres:aswathy2004@localhost:5432/energia")
engine = create_engine(DB_URL)

# Password hashing context
pwd_context = CryptContext(schemes=["pbkdf2_sha256"], deprecated="auto")

metadata = MetaData()

users_table = Table(
    "users",
    metadata,
    Column("id", Integer, primary_key=True),
    Column("username", String, unique=True, nullable=False),
    Column("password_hash", String, nullable=False),
    Column("role", String, nullable=False, server_default="student"),
    Column("department", String),
    Column("created_at", DateTime, server_default=func.now()),
)

sensor_table = Table(
    "sensor_data",
    metadata,
    Column("id", BigInteger, primary_key=True),
    Column("ds", DateTime, nullable=False),
    Column("device_id", String),
    Column("value", Float),
)

# Authorized student representatives table for registration verification
authorized_students_table = Table(
    "authorized_students",
    metadata,
    Column("id", Integer, primary_key=True),
    Column("ktu_id", String, unique=True, nullable=False),
    Column("department", String, nullable=False),
    Column("year", String, nullable=False),
    Column("created_at", DateTime, server_default=func.now()),
)

# Class Representatives table - stores registered student representatives
class_representatives_table = Table(
    "class_representatives",
    metadata,
    Column("id", Integer, primary_key=True),
    Column("username", String, unique=True, nullable=False),
    Column("password_hash", String, nullable=False),
    Column("ktu_id", String, unique=True, nullable=False),
    Column("email", String, unique=True, nullable=False),
    Column("department", String, nullable=False),
    Column("year", String, nullable=False),
    Column("created_at", DateTime, server_default=func.now()),
)

metadata.create_all(engine)

# Ensure email column exists for existing deployments (idempotent)
insp = inspect(engine)
columns = [col["name"] for col in insp.get_columns("class_representatives")]
if "email" not in columns:
    with engine.begin() as conn:
        conn.execute(text("ALTER TABLE class_representatives ADD COLUMN email VARCHAR"))

# Add convenience test users if they don't exist (for local testing)
users_to_ensure = [
    # Students (username, password, role, department)
    ("Ajith", "ajith04", "student", "CSE"),
    
    # Coordinators (username, password, role, department)
    ("coordinator1", "password123", "coordinator", "CSE"),
    ("coordinator2", "password123", "coordinator", "ECE"),
    # Admins (username, password, role, department)
    ("admin", "admin123", "admin", None),
    ("admin2", "admin123", "admin", None),
]

with engine.begin() as conn:
    for uname, pwd, role, dept in users_to_ensure:
        res = conn.execute(select(users_table.c.id).where(users_table.c.username == uname)).fetchone()
        if not res:
            hashed = pwd_context.hash(pwd)
            conn.execute(users_table.insert().values(username=uname, password_hash=hashed, role=role, department=dept))

# Add authorized student representatives (KTU ID, Department, Year)
authorized_students = [
    ("TVE21CS001", "CSE", "3"),
    ("IDK22CS017", "CSE", "3"),
    ("TVE21CS045", "CSE", "3"),
    ("TVE21CS046", "CSE", "3"),
]

with engine.begin() as conn:
    for ktu_id, department, year in authorized_students:
        res = conn.execute(select(authorized_students_table.c.id).where(authorized_students_table.c.ktu_id == ktu_id)).fetchone()
        if not res:
            conn.execute(authorized_students_table.insert().values(ktu_id=ktu_id, department=department, year=year))

print("DB initialized and test users ensured")
