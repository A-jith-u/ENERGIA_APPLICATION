import requests
import json

print("=" * 80)
print("RESOLVE BUTTON - LIVE API TEST")
print("=" * 80)

# Test the anomalies endpoint
print("\n1. Testing GET /anomalies?department=CSE")
print("-" * 80)
response = requests.get("http://localhost:5000/anomalies?department=CSE")
if response.status_code == 200:
    anomalies = response.json()
    print(f"✓ API returned {len(anomalies)} anomalies for CSE department\n")
    
    for i, anomaly in enumerate(anomalies, 1):
        print(f"Anomaly #{i}:")
        print(f"  ID: {anomaly['id']}")
        print(f"  Device: {anomaly['device_id']}")
        print(f"  Power: {anomaly['power']}W")
        print(f"  Occupancy: {anomaly['occupancy']}")
        print(f"  Anomaly Score: {anomaly['anomaly_score']}")
        print(f"  Timestamp: {anomaly['ds']}")
        print(f"  → Resolve button will appear with ID={anomaly['id']}\n")
    
    if anomalies:
        # Test DELETE on first anomaly
        test_id = anomalies[0]['id']
        print("\n2. Testing DELETE /anomalies/{id}")
        print("-" * 80)
        print(f"Note: This will actually delete the anomaly from the database!")
        print(f"Sending: DELETE /anomalies/{test_id}")
        
        response = requests.delete(f"http://localhost:5000/anomalies/{test_id}")
        if response.status_code == 200:
            result = response.json()
            print(f"✓ Anomaly deleted successfully")
            print(f"  Deleted ID: {result.get('id')}")
            print(f"  Message: {result.get('message')}")
            print(f"\nThe card for this anomaly will now disappear from the coordinator's UI!")
        else:
            print(f"✗ Error: {response.status_code}")
            print(response.json())
else:
    print(f"✗ Error: {response.status_code}")
    print(response.json())

print("\n" + "=" * 80)
print("COORDINATOR WILL SEE:")
print("=" * 80)
print("""
┌─────────────────────────────────────────────────────────┐
│ ALERTS TAB                                              │
├─────────────────────────────────────────────────────────┤
│ [!] Floor-0-Lab-G1: Power 3800 W, Occupancy: 0  [⚠ High]
│     2026-03-08 17:44:09                                 │
│                              [✔ Resolve] ← GREEN BUTTON │
│                                                          │
│ [!] Floor-1-Class-101: Power 2500 W, Occupancy: 15      │
│     2026-03-08 17:33:09                                 │
│                              [✔ Resolve] ← GREEN BUTTON │
│                                                          │
│ [!] Floor-1-Class-103: Power 1800 W, Occupancy: 8       │
│     2026-03-08 17:22:28                                 │
│                              [✔ Resolve] ← GREEN BUTTON │
│                                                          │
│ [!] Floor-3-Class-302: Power 2200 W, Occupancy: 12      │
│     2026-03-08 17:11:47                                 │
│                              [✔ Resolve] ← GREEN BUTTON │
│                                                          │
├─────────────────────────────────────────────────────────┤
│ When coordinator clicks [✔ Resolve]:                     │
│  1. Green button is clicked                             │
│  2. DELETE /anomalies/{id} sent to backend              │
│  3. Anomaly removed from database                       │
│  4. Card disappears from UI instantly                   │
│  5. "Alert resolved" notification shows                 │
└─────────────────────────────────────────────────────────┘
""")
print("=" * 80)
