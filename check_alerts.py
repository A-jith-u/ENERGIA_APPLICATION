from backend.auth_api import engine
from sqlalchemy import text
import json

conn = engine.connect()
conn.rollback()

print('=== ANOMALY ALERT SERVICE COMPREHENSIVE CHECK ===\n')

# 1. Check all alerts with full details
print('1. ALL ALERTS WITH FULL DETAILS:')
result = conn.execute(text('''
    SELECT 
        id, room_id, alert_count, status, 
        first_detected_at, last_alert_sent_at, resolved_at,
        power_cut_at, power_restored_at, anomaly_type,
        current_interval_minutes, reminder_count
    FROM anomaly_alert_tracking 
    ORDER BY first_detected_at DESC
''')).fetchall()
print('Total alerts: ' + str(len(result)))
for row in result:
    print('  Alert ID=' + str(row[0]) + 
          ' | Room=' + str(row[1]) + 
          ' | Count=' + str(row[2]) +
          ' | Status=' + str(row[3]) +
          ' | Detected=' + str(row[4]) +
          ' | PowerCut=' + str(row[7]) +
          ' | Type=' + str(row[9]))

# 2. Check status distribution  
print('\n2. ALERT STATUS DISTRIBUTION:')
conn.rollback()
result = conn.execute(text('''
    SELECT status, COUNT(*) as cnt
    FROM anomaly_alert_tracking
    GROUP BY status
    ORDER BY cnt DESC
''')).fetchall()
for status, cnt in result:
    print('  ' + status + ': ' + str(cnt))

# 3. Check unresolved alerts
print('\n3. UNRESOLVED ALERTS (Status != acknowledged AND resolved_at IS NULL):')
conn.rollback()
result = conn.execute(text('''
    SELECT id, room_id, status, first_detected_at, alert_count
    FROM anomaly_alert_tracking
    WHERE status != 'acknowledged' OR resolved_at IS NULL
    ORDER BY first_detected_at DESC
''')).fetchall()
print('Unresolved count: ' + str(len(result)))
for row in result:
    print('  ID=' + str(row[0]) + ' | Room=' + str(row[1]) + ' | Status=' + str(row[2]))

# 4. Check alerts with auto-cutoff (power_cut_at IS NOT NULL)
print('\n4. ALERTS WITH AUTO-CUTOFF TRIGGERED:')
conn.rollback()
result = conn.execute(text('''
    SELECT id, room_id, status, power_cut_at, power_restored_at
    FROM anomaly_alert_tracking
    WHERE power_cut_at IS NOT NULL
    ORDER BY power_cut_at DESC
''')).fetchall()
print('Auto-cutoff alerts: ' + str(len(result)))
for row in result:
    print('  ID=' + str(row[0]) + ' | Room=' + str(row[1]) + ' | CutAt=' + str(row[3]) + ' | RestoredAt=' + str(row[4]))

# 5. Check anomaly_log for current anomalies
print('\n5. CURRENT ANOMALIES IN ANOMALY_LOG:')
conn.rollback()
try:
    result = conn.execute(text('''
        SELECT id, room_id, anomaly_type, severity, detection_time, resolution_time
        FROM anomaly_log
        WHERE resolution_time IS NULL
        ORDER BY detection_time DESC
        LIMIT 10
    ''')).fetchall()
    print('Active anomalies: ' + str(len(result)))
    for row in result:
        print('  ID=' + str(row[0]) + ' | Room=' + str(row[1]) + ' | Type=' + str(row[2]) + ' | Severity=' + str(row[3]))
except Exception as e:
    print('Error querying anomaly_log: ' + str(e))

# 6. Check notification_log to see if alerts were sent
print('\n6. RECENT NOTIFICATIONS SENT:')
conn.rollback()
try:
    result = conn.execute(text('''
        SELECT id, room_id, notification_type, recipient, sent_at, status
        FROM notification_log
        ORDER BY sent_at DESC
        LIMIT 10
    ''')).fetchall()
    print('Recent notifications: ' + str(len(result)))
    for row in result:
        print('  ID=' + str(row[0]) + ' | Room=' + str(row[1]) + ' | Type=' + str(row[2]) + ' | Recipient=' + str(row[3]) + ' | Status=' + str(row[5]))
except Exception as e:
    print('Error querying notification_log: ' + str(e))

conn.close()
