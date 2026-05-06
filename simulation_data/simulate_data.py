from __future__ import annotations

import argparse
import random
import time

import requests

# ================= CONFIG =================
SERVER_URL = "http://127.0.0.1:5000/api/sensor-data"
RELAY_POLL_URL = "http://127.0.0.1:5000/relay/commands"
RELAY_STATUS_URL = "http://127.0.0.1:5000/relay/status"

DEFAULT_DEVICE_ID = "ESP32-CS-C201"


# ================= STATE =================
sumVoltage = 0.0
sumCurrent = 0.0
sumPower = 0.0
sumFrequency = 0.0
sumPowerFactor = 0.0
lastEnergy = 0.0
sumOccupancy = 0.0

sampleCount = 0
sendCount = 0

relayState = True
lastCommandId = -1
CURRENT_DEVICE_ID = DEFAULT_DEVICE_ID

lastReadTime = time.time()
lastSendTime = time.time()
lastPollTime = time.time()


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="ESP32 / PZEM sensor simulator")
    parser.add_argument("--device-id", default=DEFAULT_DEVICE_ID, help="Device ID to send to backend")
    parser.add_argument("--read-interval", type=float, default=10.0, help="Seconds between raw samples")
    parser.add_argument("--send-interval", type=float, default=60.0, help="Seconds between POSTs")
    parser.add_argument("--poll-interval", type=float, default=1.2, help="Seconds between relay polls")
    parser.add_argument(
        "--scenario",
        choices=["legacy", "normal", "mixed", "anomaly", "recovery"],
        default="legacy",
        help="How to generate power/occupancy patterns",
    )
    parser.add_argument(
        "--emit-occupancy",
        action="store_true",
        help="Include human_present in POST payloads",
    )
    parser.add_argument(
        "--count",
        type=int,
        default=0,
        help="Stop after N POSTs (0 means run forever)",
    )
    return parser.parse_args()


# ================= SENSOR SIMULATION =================
def generate_sensor_data(scenario: str, tick: int, read_interval: float):
    """Simulate realistic PZEM readings plus optional occupancy."""

    if scenario == "legacy":
        voltage = random.uniform(220, 250)
        current = random.uniform(0.1, 2.0)
        power = voltage * current * random.uniform(0.8, 1.0)
        occupancy = None
    elif scenario == "normal":
        voltage = random.uniform(223, 238)
        power = random.uniform(45.0, 95.0)
        pf = random.uniform(0.85, 0.98)
        current = max(0.05, power / max(voltage * pf, 1.0))
        occupancy = 1
    elif scenario == "mixed":
        roll = random.random()
        if roll < 0.45:
            voltage = random.uniform(223, 238)
            power = random.uniform(45.0, 95.0)
            occupancy = 1
        elif roll < 0.70:
            voltage = random.uniform(221, 235)
            power = random.uniform(3.0, 18.0)
            occupancy = 0
        else:
            voltage = random.uniform(225, 240)
            power = random.uniform(4300.0, 5600.0)
            occupancy = 0
        pf = random.uniform(0.82, 0.98)
        current = max(0.05, power / max(voltage * pf, 1.0))
    elif scenario == "anomaly":
        voltage = random.uniform(226, 242)
        power = random.uniform(4300.0, 5600.0)
        occupancy = 0
        pf = random.uniform(0.80, 0.97)
        current = max(0.05, power / max(voltage * pf, 1.0))
    else:  # recovery
        voltage = random.uniform(223, 238)
        if tick % 2 == 0:
            power = random.uniform(4300.0, 5600.0)
            occupancy = 0
        else:
            power = random.uniform(45.0, 95.0)
            occupancy = 1
        pf = random.uniform(0.82, 0.98)
        current = max(0.05, power / max(voltage * pf, 1.0))

    if scenario == "legacy":
        pf = random.uniform(0.7, 1.0)
        current = max(0.05, current)

    energy = lastEnergy + (power / 1000.0) * (read_interval / 3600.0)
    frequency = random.uniform(49.5, 50.5)
    pf = max(0.65, min(1.0, pf))

    return voltage, current, power, energy, frequency, pf, occupancy


# ================= READ =================
def read_and_accumulate(args: argparse.Namespace):
    global sumVoltage, sumCurrent, sumPower, sumFrequency, sumPowerFactor
    global lastEnergy, sampleCount, sumOccupancy

    v, c, p, e, f, pf, occupancy = generate_sensor_data(args.scenario, sampleCount, args.read_interval)

    sumVoltage += v
    sumCurrent += c
    sumPower += p
    sumFrequency += f
    sumPowerFactor += pf
    lastEnergy = e
    if occupancy is not None:
        sumOccupancy += occupancy

    sampleCount += 1

    print(f"\n--- SAMPLE {sampleCount} ---")
    occ_text = "N/A" if occupancy is None else str(occupancy)
    print(f"V: {v:.2f}, I: {c:.2f}, P: {p:.2f}, E: {e:.4f}, F: {f:.2f}, PF: {pf:.2f}, OCC: {occ_text}")


# ================= SEND =================
def send_averaged_data(args: argparse.Namespace):
    global sumVoltage, sumCurrent, sumPower, sumFrequency, sumPowerFactor, sampleCount, sumOccupancy
    global sendCount

    if sampleCount == 0:
        return

    payload = {
        "device_id": args.device_id,
        "voltage": sumVoltage / sampleCount,
        "current": sumCurrent / sampleCount,
        "power": sumPower / sampleCount,
        "energy": lastEnergy,
        "frequency": sumFrequency / sampleCount,
        "power_factor": sumPowerFactor / sampleCount,
        "relay_state": "ON" if relayState else "OFF",
    }

    if args.emit_occupancy:
        payload["human_present"] = int(round(sumOccupancy / sampleCount)) if sumOccupancy else 0

    print("\n=== SENDING DATA ===")
    print(payload)

    try:
        res = requests.post(SERVER_URL, json=payload, timeout=10)
        print("HTTP:", res.status_code, res.text)
    except Exception as e:
        print("Send Error:", e)

    sendCount += 1

    # reset
    sumVoltage = sumCurrent = sumPower = sumFrequency = sumPowerFactor = 0.0
    sumOccupancy = 0.0
    sampleCount = 0


# ================= RELAY =================
def execute_relay_command(state):
    global relayState

    if relayState == state:
        print("No change in relay")
        return

    relayState = state
    print("Relay changed to:", "ON" if state else "OFF")

    report_relay_status()


# ================= POLL =================
def check_relay_commands(args: argparse.Namespace):
    global lastCommandId

    try:
        url = f"{RELAY_POLL_URL}?device_id={args.device_id}"
        res = requests.get(url, timeout=5)

        print("\n=== RELAY POLL ===")
        print("HTTP:", res.status_code, res.text)

        if res.status_code == 200:
            data = res.json()

            cmd_id = data.get("command_id")
            cmd = data.get("command")

            if cmd and cmd_id != lastCommandId:
                lastCommandId = cmd_id

                if cmd == "ON":
                    execute_relay_command(True)
                elif cmd == "OFF":
                    execute_relay_command(False)

    except Exception as e:
        print("Poll Error:", e)


# ================= STATUS =================
def report_relay_status():
    payload = {
        "device_id": CURRENT_DEVICE_ID,
        "relay_state": "ON" if relayState else "OFF",
    }

    print("\n=== REPORTING RELAY STATUS ===")
    print(payload)

    try:
        res = requests.post(RELAY_STATUS_URL, json=payload, timeout=5)
        print("HTTP:", res.status_code, res.text)
    except Exception as e:
        print("Status Error:", e)


def main():
    global lastReadTime, lastSendTime, lastPollTime, CURRENT_DEVICE_ID

    args = parse_args()
    CURRENT_DEVICE_ID = args.device_id

    print("=== ESP32 SIMULATOR STARTED ===")
    print(f"device_id={args.device_id} scenario={args.scenario} emit_occupancy={args.emit_occupancy}")

    while True:
        now = time.time()

        if now - lastReadTime >= args.read_interval:
            lastReadTime = now
            read_and_accumulate(args)

        if now - lastSendTime >= args.send_interval:
            lastSendTime = now
            send_averaged_data(args)
            if args.count and sendCount >= args.count:
                print(f"Reached count={args.count}; stopping simulator.")
                return

        if now - lastPollTime >= args.poll_interval:
            lastPollTime = now
            check_relay_commands(args)

        time.sleep(0.1)


if __name__ == "__main__":
    main()