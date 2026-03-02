"""Debug helper: print user rows and verify seeded passwords."""
from passlib.context import CryptContext
from sqlalchemy import create_engine, text
import config

PWD_CTX = CryptContext(schemes=["pbkdf2_sha256"], deprecated="auto")
DB_URL = config.get_db_url()
engine = create_engine(DB_URL)

with engine.begin() as conn:
    print('\n--- Admins ---')
    admins = conn.execute(text('SELECT id, username, email, name, password_hash FROM admins ORDER BY id')).fetchall()
    for row in admins:
        id_, username, email, name, ph = row
        print(f'id={id_} username={username} email={email} name={name} hash_len={len(ph) if ph else 0}')
        # check seeded password
        try:
            ok = PWD_CTX.verify('admin123', ph)
        except Exception as e:
            ok = f'verify_error:{e}'
        print('  verify(admin123)=', ok)

    print('\n--- Coordinators ---')
    coords = conn.execute(text('SELECT id, coordinator_id, email, name, department, password_hash FROM coordinators ORDER BY id')).fetchall()
    for row in coords:
        id_, cid, email, name, dept, ph = row
        print(f'id={id_} coordinator_id={cid} email={email} name={name} dept={dept} hash_len={len(ph) if ph else 0}')

    print('\n--- Class Representatives ---')
    reps = conn.execute(text('SELECT id, username, ktu_id, email, name, department, year, password_hash FROM class_representatives ORDER BY id')).fetchall()
    for row in reps:
        id_, username, ktu, email, name, dept, year, ph = row
        print(f'id={id_} username={username} ktu_id={ktu} email={email} name={name} dept={dept} year={year} hash_len={len(ph) if ph else 0}')

print('\nDone')
