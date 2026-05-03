
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
    Boolean,
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

# Admins table - standalone store for admin accounts with department assignment
admins_table = Table(
    "admins",
    metadata,
    Column("id", Integer, primary_key=True),
    Column("username", String, unique=True, nullable=False),
    Column("email", String, unique=True, nullable=False),
    Column("password_hash", String, nullable=False),
    Column("name", String, nullable=False),
    Column("department", String, nullable=False),  # Department this admin manages (or 'admin' for system-wide)
    Column("role_level", String, nullable=False, default="department_admin"),  # "superadmin" or "department_admin"
    Column("is_active", Integer, default=1),  # 0=inactive, 1=active
    Column("last_login", DateTime, nullable=True),
    Column("created_at", DateTime, server_default=func.now()),
    Column("updated_at", DateTime, server_default=func.now()),
)

# Coordinators table - standalone store for coordinators with department assignment
coordinators_table = Table(
    "coordinators",
    metadata,
    Column("id", Integer, primary_key=True),
    Column("coordinator_id", String, unique=True, nullable=False),
    Column("email", String, unique=True, nullable=False),
    Column("password_hash", String, nullable=False),
    Column("name", String, nullable=False),
    Column("department", String, nullable=False),  # Department this coordinator manages
    Column("assigned_rooms", String, nullable=True),  # JSON list of assigned room IDs
    Column("is_active", Integer, default=1),  # 0=inactive, 1=active
    Column("last_login", DateTime, nullable=True),
    Column("created_at", DateTime, server_default=func.now()),
    Column("updated_at", DateTime, server_default=func.now()),
)

# Updated sensor_data table - matches current production schema
sensor_table = Table(
    "sensor_data",
    metadata,
    Column("id", BigInteger, primary_key=True),
    Column("ds", DateTime, nullable=False),
    Column("device_id", String),
    Column("power", Float, nullable=True),
    Column("current", Float, nullable=True),
    Column("power_factor", Float, nullable=True),
    Column("occupancy", Integer, nullable=True),
    Column("voltage", Float, nullable=True),
    Column("energy", Float, nullable=True),
    Column("frequency", Float, nullable=True),
)

# New anomaly_logs table for AI detection results
anomaly_logs_table = Table(
    "anomaly_logs",
    metadata,
    Column("id", Integer, primary_key=True),
    Column("ds", DateTime(timezone=True), nullable=False),
    Column("device_id", Text),
    Column("power", Float),
    Column("occupancy", Integer),
    Column("is_anomaly", Integer),
    Column("anomaly_score", Float),
    Column("energy_accumulated", Float),
)
# ESP32 Raw Data table - stores raw JSON payloads from ESP32 devices
esp32_raw_data_table = Table(
    "esp32_raw_data",
    metadata,
    Column("id", BigInteger, primary_key=True),
    Column("device_id", String, nullable=False),
    Column("raw_payload", Text, nullable=False),  # Store complete JSON payload
    Column("voltage", Float, nullable=True),
    Column("current", Float, nullable=True),
    Column("power", Float, nullable=True),
    Column("energy", Float, nullable=True),
    Column("frequency", Float, nullable=True),
    Column("power_factor", Float, nullable=True),
    Column("timestamp", DateTime, nullable=False, server_default=func.now()),
    Column("processed", Integer, default=0),  # 0=unprocessed, 1=processed
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

# Class Representatives table - stores registered student representatives with department
class_representatives_table = Table(
    "class_representatives",
    metadata,
    Column("id", Integer, primary_key=True),
    Column("username", String, unique=True, nullable=False),
    Column("password_hash", String, nullable=False),
    Column("ktu_id", String, unique=True, nullable=False),
    Column("email", String, unique=True, nullable=False),
    Column("name", String, nullable=True),
    Column("department", String, nullable=False),  # Department class belongs to
    Column("year", String, nullable=False),
    Column("section", String, nullable=True),  # Class section (A, B, C, etc.)
    Column("assigned_rooms", String, nullable=True),  # JSON list of assigned classroom IDs
    Column("is_active", Integer, default=1),  # 0=inactive, 1=active
    Column("last_login", DateTime, nullable=True),
    Column("created_at", DateTime, server_default=func.now()),
    Column("updated_at", DateTime, server_default=func.now()),
)

# Rooms table - stores all room names with floor and threshold information
rooms_table = Table(
    "rooms",
    metadata,
    Column("id", Integer, primary_key=True),
    Column("room_id", String, unique=True, nullable=False),
    Column("room_name", String, nullable=False),
    Column("floor_number", Integer, nullable=False),  # 0 = Ground floor, 1 = First floor, etc.
    Column("department", String, nullable=True),  # Department this room belongs to
    # Legacy single threshold kept for backward compatibility.
    # New logic should use lower_threshold/upper_threshold range.
    Column("threshold", Float, nullable=False, default=3.0),
    Column("lower_threshold", Float, nullable=False, default=2.0),
    Column("upper_threshold", Float, nullable=False, default=3.0),
    Column("created_at", DateTime, server_default=func.now()),
    Column("updated_at", DateTime, server_default=func.now()),
)

# Department Customization table - stores UI and feature customization per department
department_customization_table = Table(
    "department_customization",
    metadata,
    Column("id", Integer, primary_key=True),
    Column("department", String, unique=True, nullable=False),
    Column("display_name", String, nullable=False),
    Column("color_hex", String, nullable=False),  # Hex color for department theme
    Column("icon_name", String, nullable=False),  # Material Design icon name
    Column("enabled_features", String, nullable=True),  # JSON array of enabled features
    Column("dashboard_layout", String, nullable=True),  # JSON dashboard configuration
    Column("metrics_to_display", String, nullable=True),  # JSON array of metrics to show
    Column("custom_rooms", String, nullable=True),  # JSON array of department-specific rooms
    Column("created_at", DateTime, server_default=func.now()),
    Column("updated_at", DateTime, server_default=func.now()),
)

# Activity Logs table - tracks all user actions in the system
activity_logs_table = Table(
    "activity_logs",
    metadata,
    Column("id", BigInteger, primary_key=True),
    Column("user_id", String, nullable=True),  # username or ID of the user performing action
    Column("user_name", String, nullable=True),  # Full name for display
    Column("user_role", String, nullable=True),  # admin, coordinator, student, sergeant
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

# Sergeants table - standalone store for sergeant users (campus security/maintenance)
sergeants_table = Table(
    "sergeants",
    metadata,
    Column("id", Integer, primary_key=True),
    Column("sergeant_id", String, unique=True, nullable=False),  # Auto-generated SGT001, SGT002
    Column("email", String, unique=True, nullable=False),
    Column("password_hash", String, nullable=False),
    Column("name", String, nullable=False),
    Column("phone", String, nullable=False),  # Contact phone number
    Column("is_active", Integer, default=1),  # 0=inactive, 1=active
    Column("last_login", DateTime, nullable=True),
    Column("created_at", DateTime, server_default=func.now()),
    Column("updated_at", DateTime, server_default=func.now()),
)

# Relay Control Logs table - tracks all power relay actions
relay_control_logs_table = Table(
    "relay_control_logs",
    metadata,
    Column("id", BigInteger, primary_key=True),
    Column("room_id", String, nullable=False),  # Room whose power was controlled
    Column("relay_channel", Integer, nullable=False),  # 1 or 2 for two-channel relay
    Column("action", String, nullable=False),  # 'ON' or 'OFF'
    Column("trigger_type", String, nullable=False),  # 'manual' (sergeant), 'auto' (anomaly system)
    Column("triggered_by_user_id", String, nullable=True),  # User who triggered (if manual)
    Column("triggered_by_user_name", String, nullable=True),
    Column("reason", String, nullable=True),  # Reason for action (e.g., "No occupancy detected")
    Column("timestamp", DateTime, nullable=False, server_default=func.now()),
)

# Anomaly Alert Tracking table - tracks anomaly alert progression
anomaly_alert_tracking_table = Table(
    "anomaly_alert_tracking",
    metadata,
    Column("id", BigInteger, primary_key=True),
    Column("room_id", String, nullable=False),
    Column("anomaly_log_id", Integer, nullable=True),  # Reference to anomaly_logs table
    Column("first_detected_at", DateTime, nullable=False),
    Column("last_alert_sent_at", DateTime, nullable=True),
    Column("alert_count", Integer, default=0),  # Number of alerts sent
    Column("current_interval_minutes", Integer, default=0),  # Current alert interval (0, 3, 5, 7)
    Column("status", String, default="active"),  # 'active', 'acknowledged', 'auto_resolved', 'power_cut'
    Column("resolved_at", DateTime, nullable=True),
    Column("resolved_by_user_id", String, nullable=True),
    Column("power_cut_at", DateTime, nullable=True),  # When automatic power cut occurred
)

# Room Relay Mapping table - maps rooms to relay channels and device IDs
room_relay_mapping_table = Table(
    "room_relay_mapping",
    metadata,
    Column("id", Integer, primary_key=True),
    Column("room_id", String, unique=True, nullable=False),  # Unique room identifier
    Column("relay_device_id", String, nullable=False),  # ESP32/Relay device ID
    Column("relay_channel", Integer, nullable=False),  # 1 or 2 for two-channel relay
    Column("relay_pin", Integer, nullable=True),  # GPIO pin number on ESP32
    Column("created_at", DateTime, server_default=func.now()),
    Column("updated_at", DateTime, server_default=func.now()),
)

# Legacy users table - kept for compatibility with existing auth flows
users_table = Table(
    "users",
    metadata,
    Column("id", Integer, primary_key=True),
    Column("username", String, unique=True, nullable=False),
    Column("password_hash", String, nullable=False),
    Column("role", String, nullable=False),
    Column("created_at", DateTime, server_default=func.now()),
    Column("name", String, nullable=True),
    Column("department", String, nullable=True),
)

# In-app notifications table (used by anomaly alert service)
notifications_table = Table(
    "notifications",
    metadata,
    Column("id", Integer, primary_key=True),
    Column("recipient_email", Text, nullable=False),
    Column("recipient_type", Text, nullable=False),
    Column("department", Text, nullable=True),
    Column("room_id", Text, nullable=True),
    Column("room_name", Text, nullable=True),
    Column("title", Text, nullable=False),
    Column("message", Text, nullable=False),
    Column("anomaly_log_id", Integer, nullable=True),
    Column("power", Float, nullable=True),
    Column("anomaly_score", Float, nullable=True),
    Column("is_read", Boolean, nullable=False, default=False),
    Column("created_at", DateTime(timezone=True), nullable=False, server_default=func.now()),
)

# Password reset OTP store
password_resets_table = Table(
    "password_resets",
    metadata,
    Column("username", Text, primary_key=True),
    Column("otp_hash", Text, nullable=False),
    Column("expires_at", DateTime(timezone=True), nullable=False),
)

# Forecast output tables used by Prophet services
prophet_predictions_table = Table(
    "prophet_predictions",
    metadata,
    Column("ds", DateTime, nullable=True),
    Column("yhat", Float, nullable=True),
    Column("yhat_lower", Float, nullable=True),
    Column("yhat_upper", Float, nullable=True),
    Column("generated_at", DateTime(timezone=True), nullable=True),
)

prophet_preprocessed_table = Table(
    "prophet_preprocessed",
    metadata,
    Column("ds", DateTime, nullable=True),
    Column("y", Float, nullable=True),
)

# Relay command queue and current relay state cache
relay_commands_table = Table(
    "relay_commands",
    metadata,
    Column("id", Integer, primary_key=True),
    Column("device_id", String, nullable=False),
    Column("command", String, nullable=False),
    Column("sergeant_id", String, nullable=True),
    Column("reason", Text, nullable=True),
    Column("status", String, nullable=True),
    Column("created_at", DateTime, nullable=True, server_default=func.now()),
    Column("executed_at", DateTime, nullable=True),
)

relay_states_table = Table(
    "relay_states",
    metadata,
    Column("device_id", String, primary_key=True),
    Column("state", String, nullable=False),
    Column("last_updated", DateTime, nullable=True, server_default=func.now()),
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
    
    # Create indexes for esp32_raw_data table
    if not _index_exists(conn, 'esp32_raw_data', 'idx_esp32_raw_device_timestamp'):
        conn.execute(text("CREATE INDEX IF NOT EXISTS idx_esp32_raw_device_timestamp ON esp32_raw_data(device_id, timestamp DESC)"))
    
    if not _index_exists(conn, 'esp32_raw_data', 'idx_esp32_raw_processed'):
        conn.execute(text("CREATE INDEX IF NOT EXISTS idx_esp32_raw_processed ON esp32_raw_data(processed, timestamp DESC)"))
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
if "section" not in class_rep_columns:
    with engine.begin() as conn:
        conn.execute(text("ALTER TABLE class_representatives ADD COLUMN section VARCHAR"))
if "assigned_rooms" not in class_rep_columns:
    with engine.begin() as conn:
        conn.execute(text("ALTER TABLE class_representatives ADD COLUMN assigned_rooms VARCHAR"))
if "is_active" not in class_rep_columns:
    with engine.begin() as conn:
        conn.execute(text("ALTER TABLE class_representatives ADD COLUMN is_active INTEGER DEFAULT 1"))
if "last_login" not in class_rep_columns:
    with engine.begin() as conn:
        conn.execute(text("ALTER TABLE class_representatives ADD COLUMN last_login TIMESTAMP"))
if "created_at" not in class_rep_columns:
    with engine.begin() as conn:
        conn.execute(text("ALTER TABLE class_representatives ADD COLUMN created_at TIMESTAMP DEFAULT NOW()"))
if "updated_at" not in class_rep_columns:
    with engine.begin() as conn:
        conn.execute(text("ALTER TABLE class_representatives ADD COLUMN updated_at TIMESTAMP DEFAULT NOW()"))

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

# Ensure sensor_data has all required metric columns (idempotent)
sensor_columns = [col["name"] for col in insp.get_columns("sensor_data")]
with engine.begin() as conn:
    if "voltage" not in sensor_columns:
        conn.execute(text("ALTER TABLE sensor_data ADD COLUMN voltage DOUBLE PRECISION"))
    if "current" not in sensor_columns:
        conn.execute(text("ALTER TABLE sensor_data ADD COLUMN current DOUBLE PRECISION"))
    if "power" not in sensor_columns:
        conn.execute(text("ALTER TABLE sensor_data ADD COLUMN power DOUBLE PRECISION"))
    if "energy" not in sensor_columns:
        conn.execute(text("ALTER TABLE sensor_data ADD COLUMN energy DOUBLE PRECISION"))
    if "frequency" not in sensor_columns:
        conn.execute(text("ALTER TABLE sensor_data ADD COLUMN frequency DOUBLE PRECISION"))
    if "power_factor" not in sensor_columns:
        conn.execute(text("ALTER TABLE sensor_data ADD COLUMN power_factor DOUBLE PRECISION"))

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
if "assigned_rooms" not in coordinator_columns:
    with engine.begin() as conn:
        conn.execute(text("ALTER TABLE coordinators ADD COLUMN assigned_rooms VARCHAR"))
if "is_active" not in coordinator_columns:
    with engine.begin() as conn:
        conn.execute(text("ALTER TABLE coordinators ADD COLUMN is_active INTEGER DEFAULT 1"))
if "last_login" not in coordinator_columns:
    with engine.begin() as conn:
        conn.execute(text("ALTER TABLE coordinators ADD COLUMN last_login TIMESTAMP"))
if "created_at" not in coordinator_columns:
    with engine.begin() as conn:
        conn.execute(text("ALTER TABLE coordinators ADD COLUMN created_at TIMESTAMP DEFAULT NOW()"))
if "updated_at" not in coordinator_columns:
    with engine.begin() as conn:
        conn.execute(text("ALTER TABLE coordinators ADD COLUMN updated_at TIMESTAMP DEFAULT NOW()"))

room_columns = [col["name"] for col in insp.get_columns("rooms")]
with engine.begin() as conn:
    if "threshold" not in room_columns:
        conn.execute(text("ALTER TABLE rooms ADD COLUMN threshold DOUBLE PRECISION DEFAULT 3.0"))
    if "lower_threshold" not in room_columns:
        conn.execute(text("ALTER TABLE rooms ADD COLUMN lower_threshold DOUBLE PRECISION"))
    if "upper_threshold" not in room_columns:
        conn.execute(text("ALTER TABLE rooms ADD COLUMN upper_threshold DOUBLE PRECISION"))

    # Keep legacy threshold synchronized to upper bound for compatibility with older clients.
    conn.execute(text("""
        UPDATE rooms
        SET lower_threshold = COALESCE(
                lower_threshold,
                CASE
                    WHEN threshold IS NOT NULL THEN GREATEST(0.1, threshold * 0.8)
                    WHEN room_name ILIKE '%Lab%' THEN 3.5
                    WHEN room_name ILIKE '%Staff%' THEN 1.4
                    ELSE 1.8
                END
            ),
            upper_threshold = COALESCE(
                upper_threshold,
                CASE
                    WHEN threshold IS NOT NULL THEN GREATEST(0.2, threshold)
                    WHEN room_name ILIKE '%Lab%' THEN 5.5
                    WHEN room_name ILIKE '%Staff%' THEN 2.6
                    ELSE 3.2
                END
            )
    """))

    conn.execute(text("""
        UPDATE rooms
        SET upper_threshold = GREATEST(upper_threshold, lower_threshold + 0.1)
        WHERE lower_threshold IS NOT NULL AND upper_threshold IS NOT NULL
    """))

    conn.execute(text("""
        UPDATE rooms
        SET threshold = upper_threshold
        WHERE upper_threshold IS NOT NULL
    """))

    conn.execute(text("ALTER TABLE rooms ALTER COLUMN lower_threshold SET NOT NULL"))
    conn.execute(text("ALTER TABLE rooms ALTER COLUMN upper_threshold SET NOT NULL"))

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
        # Look up by username OR email so seed is idempotent across identifier changes
        res = conn.execute(
            select(admins_table.c.id, admins_table.c.password_hash).where(
                (admins_table.c.username == username) | (admins_table.c.email == email)
            )
        ).fetchone()
        if not res:
            conn.execute(admins_table.insert().values(username=username, email=email, name=name, password_hash=pwd_context.hash(pwd)))
        else:
            # If an account exists, verify the current hash matches the seeded password; if not, update it.
            existing_id, existing_hash = res
            try:
                matches = pwd_context.verify(pwd, existing_hash)
            except Exception:
                matches = False
            if not matches:
                # Overwrite with seeded password hash to ensure predictable dev credentials
                conn.execute(
                    text("UPDATE admins SET password_hash = :p WHERE id = :i"),
                    {"p": pwd_context.hash(pwd), "i": existing_id},
                )

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

# Room seed data (room_id, room_name, floor_number, lower_threshold, upper_threshold)
room_seeds = [
    # Ground Floor (0) - Classrooms
    ("Floor-0-Class-G01", "Class G01", 0, 1.8, 3.2),
    ("Floor-0-Class-G02", "Class G02", 0, 1.8, 3.2),
    ("Floor-0-Class-G03", "Class G03", 0, 1.8, 3.2),
    ("Floor-0-Lab-G1", "Computer Lab G1", 0, 3.6, 5.8),
    ("Floor-0-Lab-G2", "Computer Lab G2", 0, 3.6, 5.8),
    ("Floor-0-StaffRoom-G", "Staff Room Ground Floor", 0, 1.3, 2.5),
    
    # Floor 1 - Classrooms
    ("Floor-1-Class-101", "Class 101", 1, 1.9, 3.3),
    ("Floor-1-Class-102", "Class 102", 1, 1.9, 3.3),
    ("Floor-1-Class-103", "Class 103", 1, 1.9, 3.3),
    ("Floor-1-Lab-1", "Computer Lab 1", 1, 3.7, 5.9),
    ("Floor-1-Lab-2", "Computer Lab 2", 1, 3.7, 5.9),
    ("Floor-1-StaffRoom", "Staff Room Floor 1", 1, 1.4, 2.6),
    
    # Floor 2 - Classrooms
    ("Floor-2-Class-201", "Class 201", 2, 2.0, 3.4),
    ("Floor-2-Class-202", "Class 202", 2, 2.0, 3.4),
    ("Floor-2-Class-203", "Class 203", 2, 2.0, 3.4),
    ("Floor-2-Lab-3", "Computer Lab 3", 2, 3.8, 6.0),
    ("Floor-2-Lab-4", "Computer Lab 4", 2, 3.8, 6.0),
    ("Floor-2-StaffRoom", "Staff Room Floor 2", 2, 1.4, 2.7),
    
    # Floor 3 - Classrooms
    ("Floor-3-Class-301", "Class 301", 3, 2.0, 3.5),
    ("Floor-3-Class-302", "Class 302", 3, 2.0, 3.5),
    ("Floor-3-Lab-5", "Electronics Lab", 3, 3.9, 6.2),
    ("Floor-3-StaffRoom", "Staff Room Floor 3", 3, 1.5, 2.8),
]

with engine.begin() as conn:
    for ktu_id, department, year in authorized_students:
        res = conn.execute(select(authorized_students_table.c.id).where(authorized_students_table.c.ktu_id == ktu_id)).fetchone()
        if not res:
            conn.execute(authorized_students_table.insert().values(ktu_id=ktu_id, department=department, year=year))
    
    # Seed rooms data
    for room_id, room_name, floor_number, lower_threshold, upper_threshold in room_seeds:
        res = conn.execute(select(rooms_table.c.id).where(rooms_table.c.room_id == room_id)).fetchone()
        if not res:
            conn.execute(rooms_table.insert().values(
                room_id=room_id,
                room_name=room_name,
                floor_number=floor_number,
                threshold=upper_threshold,
                lower_threshold=lower_threshold,
                upper_threshold=upper_threshold,
            ))
        else:
            conn.execute(text("""
                UPDATE rooms
                SET lower_threshold = :lower_threshold,
                    upper_threshold = :upper_threshold,
                    threshold = :upper_threshold,
                    updated_at = NOW()
                WHERE room_id = :room_id
            """), {
                "lower_threshold": lower_threshold,
                "upper_threshold": upper_threshold,
                "room_id": room_id,
            })
    
    # Create indexes for rooms table
    if not _index_exists(conn, 'rooms', 'idx_rooms_floor_number'):
        conn.execute(text("CREATE INDEX IF NOT EXISTS idx_rooms_floor_number ON rooms(floor_number)"))
    
    if not _index_exists(conn, 'rooms', 'idx_rooms_room_id'):
        conn.execute(text("CREATE INDEX IF NOT EXISTS idx_rooms_room_id ON rooms(room_id)"))

print("DB initialized and test users ensured")
