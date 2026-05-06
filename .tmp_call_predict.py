import requests, json
url='http://127.0.0.1:5000/model/predict_15min'
try:
    r = requests.post(url, json={"horizon_minutes":15,"room_name":"CS-201"}, timeout=30)
    print('STATUS', r.status_code)
    try:
        print(json.dumps(r.json(), indent=2))
    except Exception:
        print(r.text)
except Exception as e:
    print('ERROR', e)
