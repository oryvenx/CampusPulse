import os
import argparse
import json
import random
import time
import uuid
from datetime import datetime, timezone

import httpx

from app.models.campus import CAMPUS_LAYOUT, THRESHOLDS


API_URL_DEFAULT = "http://localhost:8000/events"
SENSOR_API_KEY = os.environ.get("SENSOR_API_KEY", "")

# ---------- value generators per event type ----------


def _gen_occupancy(room: str, capacity: int) -> tuple[float, str, str]:
    # Use time of day to make occupancy realistic
    hour = datetime.now(timezone.utc).hour
    base_pct = 0.7 if 8 <= hour <= 18 else 0.1
    pct = max(0.0, min(1.3, random.gauss(base_pct, 0.25)))
    value = round(capacity * pct)
    if value > capacity:
        severity = "critical"
    elif value >= capacity * THRESHOLDS["occupancy_pct_warning"]:
        severity = "warning"
    else:
        severity = "normal"
    return value, "people", severity


def _gen_temperature() -> tuple[float, str, str]:
    value = round(random.gauss(23.0, 4.0), 1)
    if value >= THRESHOLDS["temperature_c_critical"]:
        severity = "critical"
    elif value >= THRESHOLDS["temperature_c_warning"]:
        severity = "warning"
    else:
        severity = "normal"
    return value, "°C", severity


def _gen_humidity() -> tuple[float, str, str]:
    value = round(random.gauss(50.0, 12.0), 1)
    severity = "warning" if value >= THRESHOLDS["humidity_pct_warning"] else "normal"
    return value, "%", severity


def _gen_energy() -> tuple[float, str, str]:
    value = round(random.gauss(30.0, 20.0), 2)
    value = max(0.5, value)
    if value >= THRESHOLDS["energy_kwh_critical"]:
        severity = "critical"
    elif value >= THRESHOLDS["energy_kwh_warning"]:
        severity = "warning"
    else:
        severity = "normal"
    return value, "kWh", severity


def _gen_door() -> tuple[float, str, str]:
    return random.choice([0, 1]), "state", "normal"


def _gen_equipment_failure() -> tuple[float, str, str]:
    return 1, "flag", random.choice(["warning", "critical"])


def _gen_service_request() -> tuple[float, str, str]:
    return 1, "ticket", random.choice(["normal", "warning", "critical"])


GENERATORS = {
    "occupancy": lambda b, r, c: _gen_occupancy(r, c),
    "temperature": lambda b, r, c: _gen_temperature(),
    "humidity": lambda b, r, c: _gen_humidity(),
    "energy": lambda b, r, c: _gen_energy(),
    "door": lambda b, r, c: _gen_door(),
    "equipment_failure": lambda b, r, c: _gen_equipment_failure(),
    "service_request": lambda b, r, c: _gen_service_request(),
}


# ---------- main ----------


def build_event() -> dict:
    building = random.choice(list(CAMPUS_LAYOUT.keys()))
    room = random.choice(CAMPUS_LAYOUT[building]["rooms"])
    capacity = CAMPUS_LAYOUT[building]["capacity"][room]

    # Weighted event types (occupancy & energy dominate)
    event_type = random.choices(
        list(GENERATORS.keys()),
        weights=[30, 20, 10, 20, 5, 5, 10],
        k=1,
    )[0]

    value, unit, severity = GENERATORS[event_type](building, room, capacity)

    return {
        "event_id": f"evt-2026-{uuid.uuid4().hex[:8]}",
        "building": building,
        "room": room,
        "event_type": event_type,
        "value": value,
        "unit": unit,
        "severity": severity,
        "timestamp": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
    }


def send_event(client: httpx.Client, url: str, event: dict) -> None:
    headers = {}
    if SENSOR_API_KEY:
        headers["X-Sensor-Api-Key"] = SENSOR_API_KEY
    try:
        r = client.post(url, json=event, headers=headers, timeout=5.0)
        tag = "OK " if r.status_code < 300 else "ERR"
        print(
            f"[{tag} {r.status_code}] {event['event_type']:<17} "
            f"{event['building']}/{event['room']} = {event['value']} {event['unit']} "
            f"({event['severity']})"
        )
    except Exception as e:
        print(f"[ERR] {e} — event={json.dumps(event)}")


def run(count: int, loop: int | None, url: str, dry_run: bool) -> None:
    with httpx.Client() as client:
        sent = 0
        while True:
            batch = 1 if loop else count
            for _ in range(batch):
                event = build_event()
                if dry_run:
                    print(json.dumps(event, indent=2))
                else:
                    send_event(client, url, event)
                sent += 1

            if not loop:
                break

            print(f"--- sent {sent} events, sleeping {loop}s ---")
            time.sleep(loop)


def main() -> None:
    parser = argparse.ArgumentParser(description="CampusPulse event simulator")
    parser.add_argument(
        "--count", type=int, default=20, help="Number of events to send (default 20)"
    )
    parser.add_argument(
        "--loop",
        type=int,
        default=None,
        help="If set, loop forever sending 1 event every N seconds",
    )
    parser.add_argument(
        "--url",
        default=API_URL_DEFAULT,
        help=f"API endpoint (default {API_URL_DEFAULT})",
    )
    parser.add_argument(
        "--dry-run", action="store_true", help="Print events without sending"
    )
    args = parser.parse_args()

    run(args.count, args.loop, args.url, args.dry_run)


if __name__ == "__main__":
    main()
