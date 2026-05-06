import requests
import sys

BASE = 'http://127.0.0.1:5000'
try:
    r = requests.post(f'{BASE}/login', json={'username':'admin','password':'admin123'}, timeout=10)
    print('LOGIN', r.status_code)
    try:
        print(r.json())
    except Exception:
        print(r.text)
    token = None
    try:
        token = r.json().get('access_token')
    except Exception:
        pass
    headers = {'Authorization': f'Bearer {token}'} if token else {}
    ra = requests.get(f'{BASE}/anomalies?department=CSE', headers=headers, timeout=10)
    print('\nANOMALIES', ra.status_code)
    try:
        print(ra.json())
    except Exception:
        print(ra.text)
    rs = requests.get(f"{BASE}/sensor-data?limit=1&device_id=CS-201", headers=headers, timeout=10)
    print('\nSENSOR', rs.status_code)
    try:
        print(rs.json())
    except Exception:
        print(rs.text)
except Exception as e:
    print('ERROR', e)
    sys.exit(2)
