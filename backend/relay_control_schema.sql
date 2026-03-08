-- ===================================================================
-- RELAY CONTROL DATABASE SCHEMA
-- Tables for managing ESP32 relay commands and status
-- ===================================================================

-- Table: relay_commands
-- Stores queued commands for ESP32 devices to poll and execute
CREATE TABLE IF NOT EXISTS relay_commands (
    id SERIAL PRIMARY KEY,
    device_id VARCHAR(50) NOT NULL,           -- ESP32 device ID (e.g., "ESP32-CS-C201")
    command VARCHAR(10) NOT NULL,              -- "ON" or "OFF"
    sergeant_id VARCHAR(20),                   -- Who initiated the command
    reason TEXT,                               -- Why the command was issued
    status VARCHAR(20) DEFAULT 'PENDING',      -- PENDING, EXECUTED, FAILED
    created_at TIMESTAMP DEFAULT NOW(),        -- When command was queued
    executed_at TIMESTAMP,                     -- When ESP32 executed it
    CONSTRAINT valid_command CHECK (command IN ('ON', 'OFF')),
    CONSTRAINT valid_status CHECK (status IN ('PENDING', 'EXECUTED', 'FAILED'))
);

-- Index for fast polling by device
CREATE INDEX IF NOT EXISTS idx_relay_commands_device_status 
    ON relay_commands(device_id, status, created_at);

-- Index for command expiration cleanup
CREATE INDEX IF NOT EXISTS idx_relay_commands_created_at 
    ON relay_commands(created_at);


-- Table: relay_states
-- Current state of each relay device (updated by ESP32)
CREATE TABLE IF NOT EXISTS relay_states (
    device_id VARCHAR(50) PRIMARY KEY,         -- ESP32 device ID
    state VARCHAR(10) NOT NULL,                -- "ON", "OFF", or "UNKNOWN"
    last_updated TIMESTAMP DEFAULT NOW(),      -- Last status report from ESP32
    CONSTRAINT valid_state CHECK (state IN ('ON', 'OFF', 'UNKNOWN'))
);

-- Index for checking stale devices
CREATE INDEX IF NOT EXISTS idx_relay_states_last_updated 
    ON relay_states(last_updated);


-- Table: relay_control_logs
-- Audit trail of all relay control actions
CREATE TABLE IF NOT EXISTS relay_control_logs (
    id SERIAL PRIMARY KEY,
    room_id VARCHAR(20),                       -- Which room was affected
    relay_channel INT,                         -- Which relay channel (1 or 2)
    action VARCHAR(10) NOT NULL,               -- "ON" or "OFF"
    trigger_type VARCHAR(20) NOT NULL,         -- "manual" or "auto"
    triggered_by_user_id VARCHAR(50),          -- User or "system"
    triggered_by_user_name VARCHAR(100),       -- Name for display
    reason TEXT,                               -- Why action was taken
    timestamp TIMESTAMP DEFAULT NOW(),
    CONSTRAINT valid_action CHECK (action IN ('ON', 'OFF')),
    CONSTRAINT valid_trigger CHECK (trigger_type IN ('manual', 'auto'))
);

-- Index for room history queries
CREATE INDEX IF NOT EXISTS idx_relay_logs_room 
    ON relay_control_logs(room_id, timestamp DESC);

-- Index for user audit trail
CREATE INDEX IF NOT EXISTS idx_relay_logs_user 
    ON relay_control_logs(triggered_by_user_id, timestamp DESC);


-- Table: room_relay_mapping
-- Maps rooms to their relay devices and channels
CREATE TABLE IF NOT EXISTS room_relay_mapping (
    id SERIAL PRIMARY KEY,
    room_id VARCHAR(20) NOT NULL UNIQUE,       -- Room identifier
    relay_device_id VARCHAR(50) NOT NULL,      -- ESP32 device ID
    relay_channel INT NOT NULL,                -- 1 or 2 (for dual-channel relay)
    relay_pin INT,                             -- GPIO pin on ESP32
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    CONSTRAINT valid_channel CHECK (relay_channel IN (1, 2)),
    FOREIGN KEY (room_id) REFERENCES rooms(room_id) ON DELETE CASCADE
);

-- Index for device lookup
CREATE INDEX IF NOT EXISTS idx_room_relay_device 
    ON room_relay_mapping(relay_device_id);


-- ===================================================================
-- CLEANUP FUNCTION
-- Automatically delete old executed/failed commands (keep for 7 days)
-- ===================================================================

CREATE OR REPLACE FUNCTION cleanup_old_relay_commands()
RETURNS void AS $$
BEGIN
    DELETE FROM relay_commands
    WHERE status IN ('EXECUTED', 'FAILED')
    AND executed_at < NOW() - INTERVAL '7 days';
END;
$$ LANGUAGE plpgsql;

-- You can schedule this with pg_cron or run periodically:
-- SELECT cleanup_old_relay_commands();


-- ===================================================================
-- SAMPLE DATA (for testing)
-- ===================================================================

-- Example room-relay mappings
INSERT INTO room_relay_mapping (room_id, relay_device_id, relay_channel, relay_pin)
VALUES 
    ('CS-C201', 'ESP32-CS-C201', 1, 4),
    ('CS-C202', 'ESP32-CS-C202', 1, 4),
    ('EEE-E301', 'ESP32-EEE-E301', 1, 4)
ON CONFLICT (room_id) DO NOTHING;

-- Initialize relay states (ESP32s will update these when they come online)
INSERT INTO relay_states (device_id, state, last_updated)
VALUES 
    ('ESP32-CS-C201', 'UNKNOWN', NOW()),
    ('ESP32-CS-C202', 'UNKNOWN', NOW()),
    ('ESP32-EEE-E301', 'UNKNOWN', NOW())
ON CONFLICT (device_id) DO UPDATE SET last_updated = NOW();


-- ===================================================================
-- USEFUL QUERIES
-- ===================================================================

-- Get all pending commands (what ESP32 would see)
-- SELECT * FROM relay_commands 
-- WHERE status = 'PENDING' 
-- ORDER BY created_at;

-- Get live status of all devices
-- SELECT device_id, state, last_updated,
--        EXTRACT(EPOCH FROM (NOW() - last_updated)) AS age_seconds
-- FROM relay_states
-- ORDER BY device_id;

-- Get relay control history for a room
-- SELECT rcl.*, s.full_name 
-- FROM relay_control_logs rcl
-- LEFT JOIN sergeants s ON rcl.triggered_by_user_id = s.sergeant_id
-- WHERE rcl.room_id = 'CS-C201'
-- ORDER BY timestamp DESC
-- LIMIT 20;

-- Find stale devices (no update in 1 minute)
-- SELECT device_id, state, last_updated
-- FROM relay_states
-- WHERE last_updated < NOW() - INTERVAL '1 minute';

