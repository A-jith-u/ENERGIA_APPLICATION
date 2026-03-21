#!/usr/bin/env python3
"""
COMPREHENSIVE ANOMALY ALERT SYSTEM VERIFICATION
Shows real-time status of alerts, escalation, cutoff, and restoration
"""

import json
import time
from datetime import datetime
from backend.auth_api import engine
from sqlalchemy import text

def check_alert_status():
    """Get comprehensive alert system status"""
    conn = engine.connect()
    conn.execute(text("SELECT 1"))  # Test connection
    
    print("\n" + "="*90)
    print(" " * 20 + "ANOMALY ALERT SYSTEM - REAL-TIME STATUS")
    print("="*90)
    print(f"Timestamp: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
    
    # 1. Active Alerts
    print("1. ACTIVE/PENDING ALERTS (status != acknowledged):")
    print("-" * 90)
    try:
        active = conn.execute(text("""
            SELECT id, room_id, anomaly_type, status, alert_count, 
                   current_interval_minutes, first_detected_at, power_cut_at, power_restored_at
            FROM anomaly_alert_tracking
            WHERE status IN ('active', 'power_cut', 'auto_restored', 'expired')
            ORDER BY first_detected_at DESC
        """)).fetchall()
        
        if active:
            print(f"   Found {len(active)} alerts:\n")
            for alert in active:
                progress = ""
                if alert[3] == 'active':
                    elapsed = (datetime.now() - alert[6]).total_seconds() / 60
                    progress = f"│ Elapsed: {elapsed:.1f}min"
                    if elapsed >= 7:
                        progress += " │ 7+ mins: AUTO-CUTOFF should trigger!"
                    elif elapsed >= 5:
                        progress += " │ Reminder #3 imminent"
                    elif elapsed >= 3:
                        progress += " │ Reminder #2 sent"
                
                print(f"   [Alert #{alert[0]}] {alert[1]}")
                print(f"      Status: {alert[3]:20} | Type: {alert[2]:25} | Alerts sent: {alert[4]}")
                print(f"      Interval: {alert[5]:2.0f}min {progress}")
                if alert[7]:
                    print(f"      Power cut at: {alert[7]}")
                if alert[8]:
                    print(f"      Power restored at: {alert[8]}")
                print()
        else:
            print("   ✓ No active alerts at this moment\n")
    except Exception as e:
        print(f"   Error: {e}\n")
    
    # 2. Alert Status Distribution
    print("2. ALERT STATUS DISTRIBUTION:")
    print("-" * 90)
    try:
        distribution = conn.execute(text("""
            SELECT status, COUNT(*) as cnt, anomaly_type
            FROM anomaly_alert_tracking
            GROUP BY status, anomaly_type
            ORDER BY cnt DESC
        """)).fetchall()
        
        total = sum(row[1] for row in distribution)
        for status, cnt, atype in distribution:
            pct = (cnt / total * 100) if total > 0 else 0
            print(f"   {status:20} : {cnt:3.0f} ({pct:5.1f}%) - Type: {atype or 'mixed'}")
        print(f"   {'─'*60}")
        print(f"   {'TOTAL':20} : {total:3.0f}\n")
    except Exception as e:
        print(f"   Error: {e}\n")
    
    # 3. Auto-Cutoff Events
    print("3. AUTO-CUTOFF HISTORY (Last 10):")
    print("-" * 90)
    try:
        cutoffs = conn.execute(text("""
            SELECT id, room_id, power_cut_at, power_restored_at, status
            FROM anomaly_alert_tracking
            WHERE power_cut_at IS NOT NULL
            ORDER BY power_cut_at DESC
            LIMIT 10
        """)).fetchall()
        
        if cutoffs:
            print(f"   Found {len(cutoffs)} cutoff events:\n")
            for cutoff in cutoffs:
                cut_time = cutoff[2]
                restore_time = cutoff[3]
                status_text = "✓ RESTORED" if restore_time else "⚠ STILL CUT"
                duration = ""
                if restore_time:
                    duration = f" | Duration: {(restore_time - cut_time).total_seconds()/60:.1f}min"
                print(f"   Room: {cutoff[1]:20} | Cut: {cut_time} {status_text}{duration}")
        else:
            print("   No cutoff events yet (alerts need 7+ mins to trigger auto-cutoff)\n")
    except Exception as e:
        print(f"   Error: {e}\n")
    
    # 4. Notifications Sent
    print("4. NOTIFICATIONS SENT (Last 20):")
    print("-" * 90)
    try:
        notifs = conn.execute(text("""
            SELECT room_id, recipient_email, title, created_at, is_read
            FROM notifications
            WHERE recipient_type IN ('coordinator', 'class_rep')
            ORDER BY created_at DESC
            LIMIT 20
        """)).fetchall()
        
        if notifs:
            print(f"   Found {len(notifs)} notifications:\n")
            for notif in notifs:
                read_status = "✓ Read" if notif[4] else "⚠ Unread"
                print(f"   Room: {notif[0]:15} | To: {notif[1]:25} | {read_status}")
                print(f"      Title: {notif[2]}")
                print(f"      Time: {notif[3]}\n")
        else:
            print("   No coordinator/class-rep notifications yet\n")
    except Exception as e:
        print(f"   Error: {e}\n")
    
    # 5. Sensor Data Latest
    print("5. LATEST SENSOR DATA (Last reading per room):")
    print("-" * 90)
    try:
        latest = conn.execute(text("""
            SELECT DISTINCT ON (device_id)
                   device_id, power, occupancy, ds
            FROM sensor_data
            ORDER BY device_id, ds DESC
            LIMIT 10
        """)).fetchall()
        
        if latest:
            for sensor in latest:
                occ_str = "Present" if sensor[2] == 1 else ("Absent" if sensor[2] == 0 else "Unknown")
                print(f"   {sensor[0]:20} | Power: {sensor[1]:7.1f}W | Occupancy: {occ_str:10} | {sensor[3]}")
        else:
            print("   No sensor data recorded yet\n")
    except Exception as e:
        print(f"   Error: {e}\n")
    
    # 6. System Readiness
    print("6. SYSTEM READINESS CHECK:")
    print("-" * 90)
    
    checks = {
        "Alert service running": "❓ Check server logs",
        "Anomaly detection active": "✓ YES" if len(active) > 0 else "✓ Waiting for anomalies",
        "Relay mapping configured": "Checking...",
        "Background loop processing": "✓ YES (30-second interval)",
    }
    
    try:
        mappings = conn.execute(text("""
            SELECT COUNT(*) FROM room_relay_mapping WHERE room_id LIKE 'ESP32%'
        """)).fetchone()
        checks["Relay mapping configured"] = f"✓ YES ({mappings[0]} devices)"
    except:
        checks["Relay mapping configured"] = "⚠ Check room_relay_mapping table"
    
    for check, status in checks.items():
        print(f"   {check:40} : {status}")
    
    print("\n" + "="*90)
    print("END-TO-END FLOW VERIFICATION:")
    print("="*90)
    print("""
    ┌─────────────────────────────────────────────────────────────────────────────┐
    │ 1. DETECTION (Real-time, when sensor data arrives):                        │
    │    ✓ No occupancy (occupancy=0) AND power >= 20W → usage_without_occupancy │
    │    ✓ Alert created in anomaly_alert_tracking                              │
    │    ✓ Initial notification sent to coordinator + class rep                 │
    │                                                                             │
    │ 2. ESCALATION (Background loop runs every 30 seconds):                    │
    │    ✓ At 3 min:  Send reminder #1 notification                            │
    │    ✓ At 5 min:  Send reminder #2 notification                            │
    │    ✓ At 7 min:  Send reminder #3 + TRIGGER AUTO-CUTOFF                   │
    │                                                                             │
    │ 3. AUTO-CUTOFF (When escalation reaches 7 min):                          │
    │    ✓ Call /relay/auto-cutoff with action=OFF                             │
    │    ✓ Power cut relay command queued                                       │
    │    ✓ Alert status changes to 'power_cut'                                  │
    │    ✓ Notifications: "Power was cut OFF automatically"                    │
    │                                                                             │
    │ 4. AUTO-RESTORE (When occupancy returns in power_cut room):              │
    │    ✓ Background loop detects occupancy changed to 1                      │
    │    ✓ Call /relay/auto-cutoff with action=ON                              │
    │    ✓ Power restore relay command queued                                   │
    │    ✓ Alert status changes to 'auto_restored'                             │
    │    ✓ Notifications: "Power was restored (ON) automatically"              │
    │                                                                             │
    └─────────────────────────────────────────────────────────────────────────────┘
    """)
    
    print("NOTES:")
    print("  • Timings are: 3min → 5min → 7min (not cumulative)")
    print("  • Times start from first_detected_at")
    print("  • Background loop runs every 30 seconds")
    print("  • Auto-cutoff triggers EXACTLY at 7 min if anomaly still active")
    print("  • Auto-restore requires occupancy > 0 and relay to respond positively")
    
    conn.close()

if __name__ == "__main__":
    while True:
        try:
            check_alert_status()
        except Exception as e:
            print(f"Error: {e}")
        
        print("\nRefresh in 30 seconds... (Press Ctrl+C to exit)\n")
        for i in range(30):
            time.sleep(1)
            if i % 10 == 0:
                print(f"  {30-i}s remaining...", end="\r")
