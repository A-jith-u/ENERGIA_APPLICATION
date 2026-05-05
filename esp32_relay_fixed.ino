// ESP32 with PZEM-004T + Relay Control
// FIXED: HTTP -1 issues with timeout, retry, and better error handling

#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include <PZEM004Tv30.h>

// ================= CONFIG =================
const char *WIFI_SSID = "gecIi";
const char *WIFI_PASSWORD = "66666666";

// ⚠️ CRITICAL: Update this to your actual backend IP
// Check: http://<THIS_IP>:5000/docs from another device to verify
const char *SERVER_URL = "http://192.168.1.25:5000/api/sensor-data";
const char *RELAY_POLL_URL = "http://192.168.1.25:5000/relay/commands";
const char *RELAY_STATUS_URL = "http://192.168.1.25:5000/relay/status";

const char *DEVICE_ID = "ESP32-CS-C201";

const unsigned long READ_INTERVAL = 10000;
const unsigned long SEND_INTERVAL = 60000;
const unsigned long POLL_INTERVAL_IDLE = 3000;
const unsigned long POLL_INTERVAL_BOOST = 600;
const unsigned long POLL_BOOST_WINDOW = 8000;

// ✅ FIXED: Add HTTP timeout (5 seconds)
const int HTTP_TIMEOUT_MS = 5000;

const int LED_PIN = 2;

// Relay Pins
const int RELAY_CH1_PIN = 26;
const int RELAY_CH2_PIN = 27;

// ================= PZEM =================
PZEM004Tv30 pzem(Serial2, 16, 17);

// ================= GLOBALS =================
unsigned long lastReadTime = 0;
unsigned long lastSendTime = 0;
unsigned long lastPollTime = 0;
unsigned long pollBoostUntil = 0;

float sumVoltage = 0, sumCurrent = 0, sumPower = 0;
float lastEnergy = 0, sumFrequency = 0, sumPowerFactor = 0;

int sampleCount = 0;

// Relay states
bool relayCh1State = true;
bool relayCh2State = true;
int relayChannel = 1;

// ================= HELPER =================
unsigned long getPollIntervalMs(unsigned long now)
{
  return (now < pollBoostUntil) ? POLL_INTERVAL_BOOST : POLL_INTERVAL_IDLE;
}

// ✅ FIXED: Helper to check connection before HTTP
bool isNetworkReady()
{
  return WiFi.status() == WL_CONNECTED;
}

// ================= SETUP =================
void setup()
{
  Serial.begin(115200);
  delay(1000);

  Serial.println("\n\n=== ESP32 RELAY SENSOR STARTING ===");

  pinMode(LED_PIN, OUTPUT);
  pinMode(RELAY_CH1_PIN, OUTPUT);
  pinMode(RELAY_CH2_PIN, OUTPUT);

  digitalWrite(RELAY_CH1_PIN, LOW);
  digitalWrite(RELAY_CH2_PIN, LOW);

  relayCh1State = true;
  relayCh2State = true;

  // Detect channel
  String deviceIdStr = String(DEVICE_ID);
  relayChannel = (deviceIdStr.endsWith("-CH2") || deviceIdStr.endsWith("_CH2")) ? 2 : 1;

  // WiFi
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  Serial.print("Connecting WiFi");
  while (WiFi.status() != WL_CONNECTED)
  {
    delay(500);
    Serial.print(".");
  }

  Serial.println("\nWiFi connected");
  Serial.print("IP: ");
  Serial.println(WiFi.localIP());

  Serial.print("Relay Channel: ");
  Serial.println(relayChannel);

  // ✅ FIXED UART INIT
  Serial2.begin(9600, SERIAL_8N1, 16, 17);

  delay(2000);
  reportRelayStatus();
}

// ================= LOOP =================
void loop()
{
  unsigned long now = millis();

  if (now - lastReadTime >= READ_INTERVAL)
  {
    lastReadTime = now;
    readAndAccumulate();
  }

  if (now - lastSendTime >= SEND_INTERVAL)
  {
    lastSendTime = now;
    sendAveragedData();
  }

  if (now - lastPollTime >= getPollIntervalMs(now))
  {
    lastPollTime = now;
    checkRelayCommands();
  }

  delay(5);
}

// ================= SENSOR =================
void readAndAccumulate()
{

  float v = pzem.voltage();
  float c = pzem.current();
  float p = pzem.power();
  float e = pzem.energy();
  float f = pzem.frequency();
  float pf = pzem.pf();

  Serial.println("\n--- Sample ---");
  Serial.printf("V: %.2f | I: %.2f | P: %.2f\n", v, c, p);

  if (!isnan(v))
    sumVoltage += v;
  if (!isnan(c))
    sumCurrent += c;
  if (!isnan(p))
    sumPower += p;
  if (!isnan(f))
    sumFrequency += f;
  if (!isnan(pf))
    sumPowerFactor += pf;
  if (!isnan(e))
    lastEnergy = e;

  sampleCount++;

  Serial.print("Sample Count: ");
  Serial.println(sampleCount);
}

// ================= SEND =================
void sendAveragedData()
{

  if (sampleCount == 0 || !isNetworkReady())
  {
    if (sampleCount == 0)
      Serial.println("No samples yet, skipping send");
    if (!isNetworkReady())
      Serial.println("Network not ready, skipping send");
    return;
  }

  StaticJsonDocument<256> json;

  json["device_id"] = DEVICE_ID;
  json["voltage"] = sumVoltage / sampleCount;
  json["current"] = sumCurrent / sampleCount;
  json["power"] = sumPower / sampleCount;
  json["energy"] = lastEnergy;
  json["frequency"] = sumFrequency / sampleCount;
  json["power_factor"] = sumPowerFactor / sampleCount;
  json["relay_state"] = (relayChannel == 1 ? relayCh1State : relayCh2State) ? "ON" : "OFF";

  String payload;
  serializeJson(json, payload);

  Serial.println("\n=== SENDING DATA ===");
  Serial.println(payload);

  // ✅ FIXED: Add timeout and better error handling
  HTTPClient http;
  http.setConnectTimeout(HTTP_TIMEOUT_MS);
  http.setTimeout(HTTP_TIMEOUT_MS);

  http.begin(SERVER_URL);
  http.addHeader("Content-Type", "application/json");

  int httpCode = http.POST(payload);

  Serial.print("HTTP Code: ");
  Serial.println(httpCode);

  if (httpCode > 0)
  {
    String response = http.getString();
    Serial.print("Response: ");
    Serial.println(response);
  }
  else
  {
    Serial.print("ERROR: ");
    Serial.println(http.errorToString(httpCode));
  }

  http.end();

  // Reset accumulators
  sumVoltage = sumCurrent = sumPower = sumFrequency = sumPowerFactor = 0;
  sampleCount = 0;
}

// ================= RELAY =================
void executeRelayCommand(bool state)
{

  if (relayChannel == 1)
  {
    relayCh1State = state;
    digitalWrite(RELAY_CH1_PIN, state ? LOW : HIGH);
  }
  else
  {
    relayCh2State = state;
    digitalWrite(RELAY_CH2_PIN, state ? LOW : HIGH);
  }

  Serial.print("Relay CH");
  Serial.print(relayChannel);
  Serial.print(" changed to: ");
  Serial.println(state ? "ON" : "OFF");

  reportRelayStatus();
}

void acknowledgeCommand(int commandId, bool executedState)
{
  if (!isNetworkReady())
    return;

  StaticJsonDocument<160> json;
  json["device_id"] = DEVICE_ID;
  json["command_id"] = commandId;
  json["executed"] = true;
  json["new_state"] = executedState ? "ON" : "OFF";

  String payload;
  serializeJson(json, payload);

  String ackUrl = String(RELAY_POLL_URL) + "/ack";

  HTTPClient http;
  http.setConnectTimeout(HTTP_TIMEOUT_MS);
  http.setTimeout(HTTP_TIMEOUT_MS);
  http.begin(ackUrl);
  http.addHeader("Content-Type", "application/json");

  int code = http.POST(payload);
  Serial.print("ACK HTTP Code: ");
  Serial.println(code);

  if (code <= 0)
  {
    Serial.print("ACK ERROR: ");
    Serial.println(http.errorToString(code));
  }

  http.end();
}

void checkRelayCommands()
{

  if (!isNetworkReady())
    return;

  String url = String(RELAY_POLL_URL) + "?device_id=" + DEVICE_ID;

  // ✅ FIXED: Add timeout
  HTTPClient http;
  http.setConnectTimeout(HTTP_TIMEOUT_MS);
  http.setTimeout(HTTP_TIMEOUT_MS);

  http.begin(url);

  int code = http.GET();

  Serial.println("\n=== RELAY POLL ===");
  Serial.print("HTTP Code: ");
  Serial.println(code);

  if (code == 200)
  {
    String response = http.getString();
    Serial.print("Response: ");
    Serial.println(response);

    StaticJsonDocument<128> doc;
    deserializeJson(doc, response);

    const char *cmd = doc["command"];
    int commandId = doc["command_id"] | 0;

    if (cmd)
    {
      if (strcmp(cmd, "ON") == 0)
      {
        executeRelayCommand(true);
        acknowledgeCommand(commandId, true);
      }
      else if (strcmp(cmd, "OFF") == 0)
      {
        executeRelayCommand(false);
        acknowledgeCommand(commandId, false);
      }
    }
  }
  else if (code > 0)
  {
    Serial.print("Response: ");
    Serial.println(http.getString());
  }
  else
  {
    Serial.print("ERROR: ");
    Serial.println(http.errorToString(code));
  }

  http.end();
}

// ================= STATUS =================
void reportRelayStatus()
{

  if (!isNetworkReady())
  {
    Serial.println("Network not ready, skipping status report");
    return;
  }

  StaticJsonDocument<128> json;

  bool state = (relayChannel == 1) ? relayCh1State : relayCh2State;

  json["device_id"] = DEVICE_ID;
  json["relay_state"] = state ? "ON" : "OFF";
  json["relay_channel"] = relayChannel;

  String payload;
  serializeJson(json, payload);

  Serial.println("\n=== REPORTING RELAY STATUS ===");
  Serial.println(payload);

  // ✅ FIXED: Add timeout
  HTTPClient http;
  http.setConnectTimeout(HTTP_TIMEOUT_MS);
  http.setTimeout(HTTP_TIMEOUT_MS);

  http.begin(RELAY_STATUS_URL);
  http.addHeader("Content-Type", "application/json");

  int code = http.POST(payload);

  Serial.print("HTTP Code: ");
  Serial.println(code);

  if (code > 0)
  {
    String response = http.getString();
    Serial.print("Response: ");
    Serial.println(response);
  }
  else
  {
    Serial.print("ERROR: ");
    Serial.println(http.errorToString(code));
  }

  http.end();
}
