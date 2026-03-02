"""Set admin password to a known value for debugging/testing."""
from passlib.context import CryptContext
from sqlalchemy import create_engine, text
import config

NEW_PW = 'TempAdmin@123'
PWD_CTX = CryptContext(schemes=["pbkdf2_sha256"], deprecated="auto")
DB_URL = config.get_db_url()
engine = create_engine(DB_URL)
new_hash = PWD_CTX.hash(NEW_PW)
with engine.begin() as conn:
    res = conn.execute(text("SELECT id, username, email FROM admins WHERE username='admin' OR email='admin@energia.test' LIMIT 1")).fetchone()
    if not res:
        print('Admin row not found')
    else:
        print('Updating admin id=', res[0], 'username=', res[1], 'email=', res[2])
        conn.execute(text("UPDATE admins SET password_hash = :p WHERE id = :i"), {"p": new_hash, "i": res[0]})
        print('Password updated to', NEW_PW)

print('Done')
