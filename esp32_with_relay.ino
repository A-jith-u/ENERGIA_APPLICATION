// ESP32 with PZEM-004T + Relay Control
// 
// TWO-CHANNEL RELAY SETUP:
// - IN1 connected to GPIO 26 (D26) - Controls Channel 1
// - IN2 connected to GPIO 27 (D27) - Controls Channel 2
// 
// DEVICE ID NAMING:
// - For Channel 1: "ESP32-CS-C201" or "ESP32-CS-C201-CH1"
// - For Channel 2: "ESP32-CS-C202-CH2" (must end with -CH2 or _CH2)
// 
// EXAMPLE: One ESP32 can control TWO different rooms:
//   Room CS-C201 → Device "ESP32-ROOM201-CH1" → Relay Channel 1 (GPIO 26)
//   Room CS-C202 → Device "ESP32-ROOM201-CH2" → Relay Channel 2 (GPIO 27)
//
#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include <PZEM004Tv30.h>

// ================= CONFIG =================
const char* WIFI_SSID     = "UNKNOWN";
const char* WIFI_PASSWORD = "12345677";

const char* SERVER_URL         = "http://10.181.241.69:5000/api/sensor-data";
const char* RELAY_POLL_URL     = "http://10.181.241.69:5000/relay/commands";
const char* RELAY_STATUS_URL   = "http://10.181.241.69:5000/relay/status";
const char* DEVICE_ID          = "ESP32-CS-C201";

const unsigned long READ_INTERVAL   = 10000;   // 10 sec - sensor reading
const unsigned long SEND_INTERVAL   = 60000;   // 1 min - send averaged data
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

// ================= SETUP =================
void setup() {
  Serial.begin(115200);
  pinMode(LED_PIN, OUTPUT);
  pinMode(RELAY_CH1_PIN, OUTPUT);
  pinMode(RELAY_CH2_PIN, OUTPUT);
  
  // Initialize both relays to OFF state
  // Relay modules are active-low: HIGH=OFF, LOW=ON
  digitalWrite(RELAY_CH1_PIN, HIGH);
  digitalWrite(RELAY_CH2_PIN, HIGH);
  relayCh1State = false;
  relayCh2State = false;
  
  // Determine which channel to use from device ID
  // If device ID ends with -CH1, use channel 1; if -CH2, use channel 2
  // Default to channel 1 if not specified
  String deviceIdStr = String(DEVICE_ID);
  if (deviceIdStr.endsWith("-CH2") || deviceIdStr.endsWith("_CH2")) {
    relayChannel = 2;
  } else if (deviceIdStr.endsWith("-CH1") || deviceIdStr.endsWith("_CH1")) {
    relayChannel = 1;
  } else {
    relayChannel = 1;  // Default to channel 1
  }

  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  Serial.print("Connecting WiFi");
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\nWiFi connected");
  Serial.print("IP: ");
  Serial.println(WiFi.localIP());
  Serial.print("Relay Channel: ");
  Serial.println(relayChannel);

  Serial2.begin(9600);
  
  // Report initial relay state to backend
  reportRelayStatus();
}

// ================= LOOP =================
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

  // Poll for relay commands with adaptive interval for low-latency relay response.
  if (now - lastPollTime >= getPollIntervalMs(now)) {
    lastPollTime = now;
    checkRelayCommands();
  }

  delay(5);
}

// ================= SENSOR READ =================
void readAndAccumulate() {

  float v  = pzem.voltage();
  float c  = pzem.current();
  float p  = pzem.power();
  float e  = pzem.energy();
  float f  = pzem.frequency();
  float pf = pzem.pf();

  Serial.println();
  Serial.print("--- Sample (");
  Serial.print(sampleCount + 1);
  Serial.print("/");
  Serial.print(TOTAL_SAMPLES);
  Serial.println(") ---");

  Serial.print("Voltage: "); Serial.println(v);
  Serial.print("Current: "); Serial.println(c);
  Serial.print("Power  : "); Serial.println(p);
  Serial.print("Energy : "); Serial.println(e);
  Serial.print("Freq   : "); Serial.println(f);
  Serial.print("PF     : "); Serial.println(pf);
  Serial.print("Relay CH"); Serial.print(relayChannel); Serial.print(": ");
  Serial.println((relayChannel == 1 ? relayCh1State : relayCh2State) ? "ON" : "OFF");

  if (!isnan(v))  sumVoltage += v;
  if (!isnan(c))  sumCurrent += c;
  if (!isnan(p))  sumPower += p;
  if (!isnan(f))  sumFrequency += f;
  if (!isnan(pf)) sumPowerFactor += pf;
  if (!isnan(e))  lastEnergy = e;

  sampleCount++;

  digitalWrite(LED_PIN, HIGH);
  delay(50);
  digitalWrite(LED_PIN, LOW);
}

// ================= SEND SENSOR DATA =================
void sendAveragedData() {

  if (sampleCount == 0) return;

  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("WiFi disconnected, data not sent");
    return;
  }

  StaticJsonDocument<256> json;

  json["device_id"]     = DEVICE_ID;
  json["voltage"]       = sumVoltage / sampleCount;
  json["current"]       = sumCurrent / sampleCount;
  json["power"]         = sumPower / sampleCount;
  json["energy"]        = lastEnergy;
  json["frequency"]     = sumFrequency / sampleCount;
  json["power_factor"]  = sumPowerFactor / sampleCount;
  json["relay_state"]   = (relayChannel == 1 ? relayCh1State : relayCh2State) ? "ON" : "OFF";
  json["relay_channel"] = relayChannel;
  json["human_present"] = nullptr;

  String payload;
  serializeJson(json, payload);

  Serial.println("\n=== HTTP SEND SENSOR DATA ===");
  Serial.println(payload);

  HTTPClient http;
  http.begin(SERVER_URL);
  http.addHeader("Content-Type", "application/json");

  int httpCode = http.POST(payload);

  Serial.print("HTTP Status: ");
  Serial.println(httpCode);

  if (httpCode > 0) {
    String response = http.getString();
    Serial.print("Response: ");
    Serial.println(response);
  }

  http.end();

  // Reset for next cycle
  sumVoltage = 0;
  sumCurrent = 0;
  sumPower = 0;
  sumFrequency = 0;
  sumPowerFactor = 0;
  sampleCount = 0;
}

// ================= CHECK RELAY COMMANDS =================
void checkRelayCommands() {
  
  if (WiFi.status() != WL_CONNECTED) {
    return;
  }

  HTTPClient http;
  String url = String(RELAY_POLL_URL) + "?device_id=" + DEVICE_ID;
  
  http.begin(url);
  http.addHeader("Content-Type", "application/json");
  http.setTimeout(1200);
  
  int httpCode = http.GET();
  
  if (httpCode == 200) {
    String response = http.getString();
    
    StaticJsonDocument<256> doc;
    DeserializationError error = deserializeJson(doc, response);
    
    if (!error) {
      const char* command = doc["command"];
      int commandId = doc["command_id"];
      
      if (command != nullptr) {
        Serial.println("\n=== RELAY COMMAND RECEIVED ===");
        Serial.print("Command: ");
        Serial.println(command);
        
        bool newState = false;
        
        if (strcmp(command, "ON") == 0) {
          newState = true;
          executeRelayCommand(true);
          Serial.println("✓ Relay turned ON");
        } 
        else if (strcmp(command, "OFF") == 0) {
          newState = false;
          executeRelayCommand(false);
          Serial.println("✓ Relay turned OFF");
        }
        
        // Acknowledge command execution
        acknowledgeCommand(commandId, newState);

        // Keep polling very fast for a short period to drain queued commands quickly.
        pollBoostUntil = millis() + POLL_BOOST_WINDOW;
      }
    }
  } 
  else if (httpCode == 204) {
    // No commands pending - this is normal
  }
  else if (httpCode > 0) {
    Serial.print("Poll error: ");
    Serial.println(httpCode);
  }
  
  http.end();
}

// ================= EXECUTE RELAY COMMAND =================
void executeRelayCommand(bool state) {
  // Update state for the appropriate channel
  // Relay modules are active-low: HIGH=OFF, LOW=ON (inverted logic)
  if (relayChannel == 1) {
    relayCh1State = state;
    digitalWrite(RELAY_CH1_PIN, state ? LOW : HIGH);
  } else {
    relayCh2State = state;
    digitalWrite(RELAY_CH2_PIN, state ? LOW : HIGH);
  }
  
  Serial.print("Relay CH");
  Serial.print(relayChannel);
  Serial.print(" set to: ");
  Serial.println(state ? "ON (HIGH)" : "OFF (LOW)");
  
  // Visual feedback
  for (int i = 0; i < 3; i++) {
    digitalWrite(LED_PIN, HIGH);
    delay(100);
    digitalWrite(LED_PIN, LOW);
    delay(100);
  }
  
  // Report status immediately after execution
  reportRelayStatus();

  // Stay in boost mode briefly to reduce latency for consecutive toggles.
  pollBoostUntil = millis() + POLL_BOOST_WINDOW;
}

// ================= REPORT RELAY STATUS =================
void reportRelayStatus() {
  
  if (WiFi.status() != WL_CONNECTED) {
    return;
  }

  bool currentState = (relayChannel == 1) ? relayCh1State : relayCh2State;

  StaticJsonDocument<128> json;
  json["device_id"] = DEVICE_ID;
  json["relay_state"] = currentState ? "ON" : "OFF";
  json["timestamp"] = millis();

  String payload;
  serializeJson(json, payload);

  Serial.println("\n=== REPORTING RELAY STATUS ===");
  Serial.println(payload);

  HTTPClient http;
  http.begin(RELAY_STATUS_URL);
  http.addHeader("Content-Type", "application/json");
  http.setTimeout(1200);

  int httpCode = http.POST(payload);

  if (httpCode > 0) {
    Serial.print("Status reported: ");
    Serial.println(httpCode);
  }

  http.end();
}

// ================= ACKNOWLEDGE COMMAND =================
void acknowledgeCommand(int commandId, bool executedState) {
  
  if (WiFi.status() != WL_CONNECTED) {
    return;
  }

  StaticJsonDocument<128> json;
  json["device_id"] = DEVICE_ID;
  json["command_id"] = commandId;
  json["executed"] = true;
  json["new_state"] = executedState ? "ON" : "OFF";
  json["relay_channel"] = relayChannel;

  String payload;
  serializeJson(json, payload);

  String url = String(RELAY_POLL_URL) + "/ack";
  
  HTTPClient http;
  http.begin(url);
  http.addHeader("Content-Type", "application/json");
  http.setTimeout(1200);

  int httpCode = http.POST(payload);

  if (httpCode > 0) {
    Serial.print("Command acknowledged: ");
    Serial.println(httpCode);
  }

  http.end();
}
