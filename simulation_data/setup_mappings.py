import requests, json, sys
BASE='http://127.0.0.1:5000'
try:
    # Login
    r = requests.post(f'{BASE}/login', json={'username':'admin','password':'admin123'}, timeout=10)
    print('LOGIN', r.status_code)
    token = r.json().get('access_token') if r.ok else None
    headers = {'Authorization': f'Bearer {token}'} if token else {}

    # Assign department for CS-C201
    pa = {"CS-C201":"CSE"}
    ra = requests.put(f'{BASE}/rooms/assign-departments', json=pa, headers=headers, timeout=10)
    print('\nASSIGN DEPARTMENTS', ra.status_code)
    try:
        print(ra.json())
    except:
        print(ra.text)

    # Map class rep Ajith (ajith@example.com) to room
    cm = {"room_id":"CS-C201","class_rep_email":"ajith@example.com"}
    rc = requests.post(f'{BASE}/rooms/assign-class-rep', json=cm, headers=headers, timeout=10)
    print('\nASSIGN CLASS REP', rc.status_code)
    try:
        print(rc.json())
    except:
        print(rc.text)

    # Call prediction for CS-201
    pj = {'horizon_minutes':15,'room_name':'CS-201'}
    rp = requests.post(f'{BASE}/model/predict_15min', json=pj, timeout=20)
    print('\nPREDICT 15min', rp.status_code)
    try:
        print(rp.json())
    except:
        print(rp.text)

except Exception as e:
    print('ERROR', e)
    sys.exit(2)
