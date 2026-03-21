# QUICK REFERENCE: TEST THE COMPLETE ALERT SYSTEM

## 🚀 INSTANT START

### 1. Backend Already Running?
```powershell
# Check if backend is running
netstat -ano | findstr :5000

# If yes, continue to step 2
# If no, start it:
cd e:\Flutter\flutter_application_1
python backend/start_server.py
```

### 2. Monitor Alerts in Real-Time
```powershell
# In a separate terminal:
cd e:\Flutter\flutter_application_1
python monitor_alerts.py

# This will show:
# - Active alerts
# - Escalation progress (elapsed time)
# - Auto-cutoff events
# - Relay history
```

### 3. Trigger a Test Anomaly
```bash
# Send: power=150W, occupancy=0 (equipment running, nobody present)
curl -X POST http://localhost:5000/api/sensor-data \
  -H "Content-Type: application/json" \
  -d '{
    "device_id": "ESP32-CS-C201",
    "power": 150,
    "human_present": 0
  }'

# Expected response:
# {"status": "success", "is_anomaly": 1, "score": ...}
```

### 4. Watch the Escalation
```
Timeline (watch monitor output):

✅ CREATED: Alert created immediately
   → Initial notification sent

⏱️  WAITING (0-3 min): Background loop processing

⏱️  3-MIN MARK: First reminder sent
   → "Reminder #1: Usage detected without occupancy"

⏱️  5-MIN MARK: Second reminder sent  
   → "Reminder #2: Still no occupancy detected"

🔴 7-MIN MARK: AUTO-CUTOFF TRIGGERED!
   → Relay OFF command sent to ESP32
   → Power cut from room
   → Final warning notification

📡 WAITING FOR OCCUPANCY: System monitoring...
   → Waiting for occupancy = 1
```

### 5. Trigger Auto-Restore
```bash
# Send: power=5W, occupancy=1 (janitor enters room)
curl -X POST http://localhost:5000/api/sensor-data \
  -H "Content-Type: application/json" \
  -d '{
    "device_id": "ESP32-CS-C201", 
    "power": 5,
    "human_present": 1
  }'

# Within 30 seconds:
# ✅ AUTO-RESTORE TRIGGERED
#    → Relay ON command sent to ESP32
#    → Power restored
#    → Notification: "Power restored automatically"
```

---

## 🔍 VERIFICATION QUERIES

### Check Active Alerts
```sql
SELECT id, room_id, anomaly_type, status, alert_count, current_interval_minutes, 
       EXTRACT(EPOCH FROM (NOW() - first_detected_at))/60 as elapsed_minutes
FROM anomaly_alert_tracking
WHERE status IN ('active', 'power_cut')
ORDER BY first_detected_at DESC;
```

### See Escalation Progress
```sql
SELECT room_id, status, 
       EXTRACT(EPOCH FROM (NOW() - first_detected_at))/60 as elapsed_min,
       alert_count, current_interval_minutes
FROM anomaly_alert_tracking
WHERE status = 'active'
ORDER BY first_detected_at DESC;
```

### Check Auto-Cutoff History
```sql
SELECT id, room_id, power_cut_at, power_restored_at, status
FROM anomaly_alert_tracking
WHERE power_cut_at IS NOT NULL
ORDER BY power_cut_at DESC
LIMIT 10;
```

### View Recent Relay Commands
```sql
SELECT room_id, action, trigger_type, reason, timestamp
FROM relay_control_logs
ORDER BY timestamp DESC
LIMIT 20;
```

### Check Notifications Sent
```sql
SELECT recipient_email, recipient_type, title, created_at, is_read
FROM notifications
WHERE recipient_type IN ('coordinator', 'class_rep')
ORDER BY created_at DESC
LIMIT 20;
```

---

## 📊 REAL-TIME MONITORING

### Watch Background Loop Processing
```bash
# In backend terminal, look for these logs every 30 seconds:
[Anomaly Alert Service] Error processing anomalies: (means loop is running but no anomalies)
or
[Reminder #1] Room ESP32-CS-C201 at X.X min (logged when reminder sent)
or  
[Auto-Cutoff] Triggering power cutoff for room ESP32-CS-C201 (logged at 7 min)
```

### Alert Status Throughout Lifecycle
```
Status Transitions:
active → (at 3min: send reminder) → (at 5min: send reminder) → 
(at 7min: auto-cutoff) → power_cut → (when occupancy returns) → 
auto_restored → acknowledged
```

---

## 🐛 TROUBLESHOOTING

### Alert not creating?
```bash
# Check if anomaly detection is working:
# 1. Verify power is >= 20W AND occupancy is 0
curl http://localhost:5000/api/sensor-data?limit=10

# 2. Check anomaly detection logs for:
# "[DEBUG] INSERT sensor_data with power"
# "is_anomaly=1" (if yes, alert should create)
```

### Auto-cutoff not triggering?
```bash
# Check if we reached 7 minutes:
# Run: python monitor_alerts.py
# Look for: "Elapsed: X.Xmin"
# If > 7.0, should have triggered already

# Check alert status:
SELECT status, power_cut_at FROM anomaly_alert_tracking 
WHERE id = <alert_id>;
# Status should be 'power_cut' and power_cut_at should have timestamp
```

### Auto-restore not working?
```bash
# 1. Verify power_cut alert exists:
SELECT * FROM anomaly_alert_tracking 
WHERE status = 'power_cut' LIMIT 1;

# 2. Send occupancy data:
curl -X POST http://localhost:5000/api/sensor-data \
  -H "Content-Type: application/json" \
  -d '{"device_id":"ESP32-CS-C201","human_present":1,"power":5}'

# 3. Wait 30 seconds for background loop
# 4. Check relay logs:
SELECT * FROM relay_control_logs WHERE action='ON' 
ORDER BY timestamp DESC LIMIT 1;
```

---

## 📋 COMPLETE TEST CHECKLIST

- [ ] Backend started with `[app_main] Anomaly alert background service STARTED [OK]`
- [ ] Sent test data: power=150W, occupancy=0
- [ ] Alert created in anomaly_alert_tracking table
- [ ] Waited 3+ minutes and saw "Reminder #1" in logs
- [ ] Waited 5+ minutes and saw "Reminder #2" in logs  
- [ ] Waited 7+ minutes and saw "Auto-Cutoff Triggered" in logs
- [ ] Alert status changed to 'power_cut'
- [ ] Sent occupancy data: occupancy=1
- [ ] Waited 30 seconds for background loop
- [ ] Auto-restore triggered: "Auto Restore" message in logs
- [ ] Alert status changed to 'auto_restored'
- [ ] Power ON relay command was sent
- [ ] Coordinator/class rep notifications appeared

**If all checked, system is working perfectly! ✅**

---

## 💡 KEY CONCEPTS

**Why 30-second loop?** 
- Balances real-time responsiveness with database load
- Fast enough for 3/5/7 min escalation
- Slow enough to avoid high CPU usage

**Why 7 minutes?**
- Gives 3 minutes of escalating warnings
- Last chance before auto-cutoff
- 7min = industry standard for unresolved equipment alerts

**Why check occupancy every 30 seconds?**
- Restores power quickly when people return
- Still efficient for background processing
- Matches anomaly detection loop frequency

**What if occupancy sensor is wrong?**
- Manual override: Use `/relay/control` endpoint
- Create support ticket system
- Or adjust occupancy thresholds in config

---

## 🎯 SUCCESS CRITERIA

✅ **System is working if**:
1. Alert created within 5 sec of anomaly data
2. Escalation messages appear at 3, 5, 7 minute marks
3. Auto-cutoff relay command sent at 7 minutes
4. Auto-restore relay command sent when occupancy returns
5. All status transitions logged correctly

❌ **If any fails**:
- Check backend logs for errors
- Verify database connectivity
- Ensure relay_mapping exists for test room
- Confirm ESP32 is sending sensor data

