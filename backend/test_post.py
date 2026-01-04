import json
from urllib import request

url = "http://127.0.0.1:5000/api/sensor-data"
payload = {
    "device_id": "esp32-test",
    "voltage": 230,
    "current": 1.2,
    "power": 276,
    "energy": 123.4,
    "frequency": 50.0,
    "power_factor": 0.98,
}

data = json.dumps(payload).encode('utf-8')
req = request.Request(url, data=data, headers={"Content-Type": "application/json"})
try:
    with request.urlopen(req, timeout=5) as resp:
        print(resp.status)
        print(resp.read().decode())
except Exception as e:
    print('ERROR', e)
