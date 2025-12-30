"""
Simple MQTT -> Postgres ingestor example.
Expects sensor messages as JSON payloads containing at least:
  {
    "device_id": "esp32-01",
    "ts": "2025-12-06T12:34:00Z",
    "value": 12.34
  }

Writes to a Postgres table `sensor_data(ds timestamp, device_id text, value double precision)`
"""

import os
import json
import time
import argparse
import paho.mqtt.client as mqtt
from sqlalchemy import create_engine, text
from datetime import datetime

from . import config as cfg

MQTT_BROKER = os.environ.get("MQTT_BROKER", "localhost")
MQTT_PORT = int(os.environ.get("MQTT_PORT", 1883))
TOPIC = os.environ.get("MQTT_TOPIC", "energia/sensors/#")
DB_URL = cfg.get_db_url()

engine = create_engine(DB_URL)


def on_connect(client, userdata, flags, rc):
    print("Connected to MQTT broker", rc)
    client.subscribe(TOPIC)


def on_message(client, userdata, msg):
    try:
        payload = json.loads(msg.payload.decode())
    except Exception as e:
        print("Invalid JSON payload", e)
        return

    device_id = payload.get("device_id") or payload.get("id") or msg.topic
    ts = payload.get("ts")
    if ts:
        try:
            ts = datetime.fromisoformat(ts.replace("Z", "+00:00"))
        except Exception:
            ts = datetime.utcnow()
    else:
        ts = datetime.utcnow()

    value = payload.get("value") if payload.get("value") is not None else payload.get("y")
    if value is None:
        print("No value field in payload")
        return

    with engine.begin() as conn:
        conn.execute(
            text("INSERT INTO sensor_data(ds, device_id, value) VALUES (:ds, :device_id, :value)"),
            {"ds": ts, "device_id": device_id, "value": float(value)},
        )
    print(f"Inserted {device_id}@{ts} -> {value}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--broker", default=MQTT_BROKER)
    parser.add_argument("--port", default=MQTT_PORT, type=int)
    parser.add_argument("--topic", default=TOPIC)
    parser.add_argument("--db", default=DB_URL)
    args = parser.parse_args()

    client = mqtt.Client()
    client.on_connect = on_connect
    client.on_message = on_message

    print("Connecting to DB at", args.db)
    engine = create_engine(args.db)

    client.connect(args.broker, args.port, 60)
    client.loop_forever()
