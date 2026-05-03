import os, sys
sys.path.insert(0, os.path.dirname(__file__))
import config
from sqlalchemy import create_engine, text
engine = create_engine(config.get_db_url())
with engine.connect() as conn:
    rows = conn.execute(text("SELECT id, coordinator_id, email, name, department FROM coordinators ORDER BY created_at DESC")).fetchall()
    missing = [r for r in rows if not (r[2] and '@' in str(r[2]))]
    print('TOTAL_COORDINATORS=', len(rows))
    print('MISSING_EMAIL_COUNT=', len(missing))
    for r in missing:
        print(r)
