"""Simple DB initializer for Energia DB.
Run from repo root (`python -m backend.db_init`) or from backend folder (`python db_init.py`).
Targets PostgreSQL by default; override DB_URL via env or .env.
"""
import os
import sys
import importlib
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
    text,
)

def _load_cfg():
    if __package__:
        return importlib.import_module(".config", __package__)
    # Allow running as a script from backend directory
    sys.path.append(os.path.dirname(__file__))
    import config as cfg  # type: ignore
    return cfg


def _index_exists(conn, table_name: str, index_name: str) -> bool:
    """Check if an index exists."""
    result = conn.execute(
        text("SELECT EXISTS(SELECT 1 FROM pg_indexes WHERE tablename = :table AND indexname = :index)"),
        {"table": table_name, "index": index_name}
    ).scalar()
    return bool(result)


cfg = _load_cfg()

# Load configuration from environment/.env and enforce PostgreSQL
DB_URL = cfg.get_db_url()
engine = create_engine(DB_URL)

# Password hashing context
pwd_context = CryptContext(schemes=["pbkdf2_sha256"], deprecated="auto")

metadata = MetaData()

# Admins table - standalone store for admin accounts
admins_table = Table(
    "admins",
    metadata,
    Column("id", Integer, primary_key=True),
    Column("username", String, unique=True, nullable=False),
    Column("email", String, unique=True, nullable=False),
    Column("password_hash", String, nullable=False),
    Column("name", String, nullable=False),
    Column("created_at", DateTime, server_default=func.now()),
)

# Coordinators table - standalone store for coordinators
coordinators_table = Table(
    "coordinators",
    metadata,
    Column("id", Integer, primary_key=True),
    Column("coordinator_id", String, unique=True, nullable=False),
    Column("email", String, unique=True, nullable=False),
    Column("password_hash", String, nullable=False),
    Column("name", String, nullable=False),
    Column("department", String, nullable=False),
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
    Column("name", String, nullable=True),
    Column("department", String, nullable=False),
    Column("year", String, nullable=False),
    Column("created_at", DateTime, server_default=func.now()),
)

# Activity Logs table - tracks all user actions in the system
activity_logs_table = Table(
    "activity_logs",
    metadata,
    Column("id", BigInteger, primary_key=True),
    Column("user_id", String, nullable=True),  # username or ID of the user performing action
    Column("user_name", String, nullable=True),  # Full name for display
    Column("user_role", String, nullable=True),  # admin, coordinator, student
    Column("action_type", String, nullable=False),  # login, logout, data_submission, report_generation, etc.
    Column("action_description", String, nullable=False),  # detailed description of the action
    Column("resource_type", String, nullable=True),  # what type of resource was affected (sensor, report, etc)
    Column("resource_id", String, nullable=True),  # ID of the affected resource
    Column("department", String, nullable=True),  # department involved
    Column("ip_address", String, nullable=True),  # IP address of the request
    Column("status", String, nullable=False, default="success"),  # success, failure, warning
    Column("created_at", DateTime, server_default=func.now()),
    Column("timestamp", DateTime, nullable=False, server_default=func.now()),
)

metadata.create_all(engine)

insp = inspect(engine)

# Create indexes for activity_logs table to improve query performance
with engine.begin() as conn:
    # Index on timestamp for range queries and sorting
    if not _index_exists(conn, 'activity_logs', 'idx_activity_logs_timestamp'):
        conn.execute(text("CREATE INDEX IF NOT EXISTS idx_activity_logs_timestamp ON activity_logs(timestamp DESC)"))
    
    # Index on timestamp and status for filtering queries
    if not _index_exists(conn, 'activity_logs', 'idx_activity_logs_timestamp_status'):
        conn.execute(text("CREATE INDEX IF NOT EXISTS idx_activity_logs_timestamp_status ON activity_logs(timestamp DESC, status)"))
    
    # Index on user_id for user-specific queries
    if not _index_exists(conn, 'activity_logs', 'idx_activity_logs_user_id'):
        conn.execute(text("CREATE INDEX IF NOT EXISTS idx_activity_logs_user_id ON activity_logs(user_id, timestamp DESC)"))
    
    # Index on action_type for action filtering
    if not _index_exists(conn, 'activity_logs', 'idx_activity_logs_action_type'):
        conn.execute(text("CREATE INDEX IF NOT EXISTS idx_activity_logs_action_type ON activity_logs(action_type, timestamp DESC)"))

# Ensure columns exist for existing deployments (idempotent upgrades)
class_rep_columns = [col["name"] for col in insp.get_columns("class_representatives")]
if "email" not in class_rep_columns:
    with engine.begin() as conn:
        conn.execute(text("ALTER TABLE class_representatives ADD COLUMN email VARCHAR"))
if "name" not in class_rep_columns:
    with engine.begin() as conn:
        conn.execute(text("ALTER TABLE class_representatives ADD COLUMN name VARCHAR"))

admin_columns = [col["name"] for col in insp.get_columns("admins")]
if "name" not in admin_columns:
    with engine.begin() as conn:
        conn.execute(text("ALTER TABLE admins ADD COLUMN name VARCHAR NOT NULL DEFAULT 'Admin'"))
if "email" not in admin_columns:
    with engine.begin() as conn:
        conn.execute(text("ALTER TABLE admins ADD COLUMN email VARCHAR UNIQUE"))
if "username" not in admin_columns:
    with engine.begin() as conn:
        conn.execute(text("ALTER TABLE admins ADD COLUMN username VARCHAR UNIQUE"))

coordinator_columns = [col["name"] for col in insp.get_columns("coordinators")]
if "department" not in coordinator_columns:
    with engine.begin() as conn:
        conn.execute(text("ALTER TABLE coordinators ADD COLUMN department VARCHAR"))
if "name" not in coordinator_columns:
    with engine.begin() as conn:
        conn.execute(text("ALTER TABLE coordinators ADD COLUMN name VARCHAR"))
if "email" not in coordinator_columns:
    with engine.begin() as conn:
        conn.execute(text("ALTER TABLE coordinators ADD COLUMN email VARCHAR UNIQUE"))
if "coordinator_id" not in coordinator_columns:
    with engine.begin() as conn:
        conn.execute(text("ALTER TABLE coordinators ADD COLUMN coordinator_id VARCHAR UNIQUE"))

# Seed convenience accounts into the new separated tables (idempotent)
admin_seeds = [
    # (username, email, name, password)
    ("admin", "admin@energia.test", "System Administrator", "admin123"),
]

coordinator_seeds = [
    # (email, name, department, password)
    ("cse.coord@energia.test", "CSE Coordinator", "CSE", "Coord@123"),
    ("ece.coord@energia.test", "ECE Coordinator", "ECE", "Coord@123"),
    ("mech.coord@energia.test", "ME Coordinator", "ME", "Coord@123"),
]


def _generate_coordinator_id(department: str, sequence: int) -> str:
    """Generate a unique 6-char coordinator ID: C + dept_prefix + 3-digit sequence."""
    dept_prefix = department[:2].upper() if len(department) >= 2 else department.upper()
    return f"C{dept_prefix}{sequence:03d}"


student_seeds = [
    # (username, password, ktu_id, dept, year, email)
    ("Ajith", "ajith04", "TVE21CS999", "CSE", "3", "ajith@example.com"),
]

with engine.begin() as conn:
    for username, email, name, pwd in admin_seeds:
        res = conn.execute(select(admins_table.c.id).where(admins_table.c.username == username)).fetchone()
        if not res:
            conn.execute(admins_table.insert().values(username=username, email=email, name=name, password_hash=pwd_context.hash(pwd)))

    for email, name, dept, pwd in coordinator_seeds:
        res = conn.execute(select(coordinators_table.c.id).where(coordinators_table.c.email == email)).fetchone()
        if not res:
            # Generate unique coordinator ID - check for existing coordinators
            seq_res = conn.execute(
                text("SELECT COUNT(*) FROM coordinators WHERE department=:d"),
                {"d": dept}
            ).scalar() or 0
            coordinator_id = _generate_coordinator_id(dept, seq_res + 1)
            
            # Double-check the coordinator_id doesn't already exist
            id_check = conn.execute(
                select(coordinators_table.c.id).where(coordinators_table.c.coordinator_id == coordinator_id)
            ).fetchone()
            
            if not id_check:
                conn.execute(coordinators_table.insert().values(
                    coordinator_id=coordinator_id,
                    email=email,
                    name=name,
                    department=dept,
                    password_hash=pwd_context.hash(pwd),
                ))

    for uname, pwd, ktu_id, dept, year, email in student_seeds:
        res = conn.execute(select(class_representatives_table.c.id).where(class_representatives_table.c.username == uname)).fetchone()
        if not res:
            conn.execute(class_representatives_table.insert().values(
                username=uname,
                password_hash=pwd_context.hash(pwd),
                ktu_id=ktu_id,
                email=email,
                department=dept,
                year=year,
            ))

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
