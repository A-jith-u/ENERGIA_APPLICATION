// ESP32 with PZEM-004T + Relay Control
// 
// FIXES for "Relay Not Detected" Issue:
// 1. Set proper WiFi credentials (line 21-22)
// 2. Added periodic relay status reporting every 20 seconds

#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include <PZEM004Tv30.h>

// ================= CONFIG =================
const char* WIFI_SSID     = "YourActualWiFiSSID";  // ← FIX THIS!
const char* WIFI_PASSWORD = "YourActualPassword";  // ← FIX THIS!

const char* SERVER_URL         = "http://10.181.241.69:5000/api/sensor-data";
const char* RELAY_POLL_URL     = "http://10.181.241.69:5000/relay/commands";
const char* RELAY_STATUS_URL   = "http://10.181.241.69:5000/relay/status";
const char* DEVICE_ID          = "ESP32-CS-C201";

const unsigned long READ_INTERVAL   = 10000;   // 10 sec - sensor reading
const unsigned long SEND_INTERVAL   = 60000;   // 1 min - send averaged data
const unsigned long STATUS_INTERVAL = 20000;   // 20 sec - relay status heartbeat (ADDED)
const unsigned long POLL_INTERVAL_IDLE  = 1200; // 1.2 sec - normal command polling
const unsigned long POLL_INTERVAL_BOOST = 250;  // 0.25 sec - short burst after command
const unsigned long POLL_BOOST_WINDOW   = 8000; // 8 sec burst window

const int TOTAL_SAMPLES = SEND_INTERVAL / READ_INTERVAL;
const int LED_PIN   = 2;

// Two-channel relay configuration
const int RELAY_CH1_PIN = 26;  // IN1 connected to GPIO26 (D26)
const int RELAY_CH2_PIN = 27;  // IN2 connected to GPIO27 (D27)

// ================= PZEM =================
PZEM004Tv30 pzem(Serial2, 16, 17);

// ================= GLOBALS =================
unsigned long lastReadTime = 0;
unsigned long lastSendTime = 0;
unsigned long lastPollTime = 0;
unsigned long lastStatusTime = 0;  // ADDED - track last status report
unsigned long pollBoostUntil = 0;

float sumVoltage = 0;
float sumCurrent = 0;
float sumPower = 0;
float lastEnergy = 0;
float sumFrequency = 0;
float sumPowerFactor = 0;

int sampleCount = 0;

// Relay states for both channels
bool relayCh1State = false;  // false = OFF, true = ON
bool relayCh2State = false;  // false = OFF, true = ON
int relayChannel = 1;        // Which channel this device controls (1 or 2)

unsigned long getPollIntervalMs(unsigned long now) {
  return (now < pollBoostUntil) ? POLL_INTERVAL_BOOST : POLL_INTERVAL_IDLE;
}

// ... (keep all existing functions: setup, readAndAccumulate, sendAveragedData, etc.)

// ================= MODIFIED LOOP =================
void loop() {

  unsigned long now = millis();

  // Read sensor data every 10 seconds
  if (now - lastReadTime >= READ_INTERVAL) {
    lastReadTime = now;
    readAndAccumulate();
  }

  // Send averaged data every 60 seconds
  if (now - lastSendTime >= SEND_INTERVAL) {
    lastSendTime = now;
    sendAveragedData();
  }

  // ADDED: Report relay status every 20 seconds (heartbeat for online detection)
  if (now - lastStatusTime >= STATUS_INTERVAL) {
    lastStatusTime = now;
    reportRelayStatus();
  }

  // Poll for relay commands with adaptive interval for low-latency relay response.
  if (now - lastPollTime >= getPollIntervalMs(now)) {
    lastPollTime = now;
    checkRelayCommands();
  }

  delay(5);
}

// (keep all other existing functions unchanged)
