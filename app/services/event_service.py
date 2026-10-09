from __future__ import annotations

import uuid
from datetime import datetime, timezone
from decimal import Decimal
from typing import Any, Optional

from boto3.dynamodb.conditions import Key

from app.models.event import CampusEvent, EventCreate
from app.services.db import events_table


def _to_decimal(obj: Any) -> Any:
    """DynamoDB doesn't accept floats; convert to Decimal recursively."""
    if isinstance(obj, float):
        return Decimal(str(obj))
    if isinstance(obj, dict):
        return {k: _to_decimal(v) for k, v in obj.items()}
    if isinstance(obj, list):
        return [_to_decimal(v) for v in obj]
    return obj


def _from_decimal(obj: Any) -> Any:
    if isinstance(obj, Decimal):
        return float(obj)
    if isinstance(obj, dict):
        return {k: _from_decimal(v) for k, v in obj.items()}
    if isinstance(obj, list):
        return [_from_decimal(v) for v in obj]
    return obj


def store_event(payload: EventCreate) -> CampusEvent:
    """Validate, normalize, and persist an event. Returns the stored event."""
    now = datetime.now(timezone.utc)
    event_id = payload.event_id or f"evt-2026-{uuid.uuid4().hex[:8]}"
    ts = payload.timestamp or now

    event = CampusEvent(
        event_id=event_id,
        building=payload.building,
        room=payload.room,
        event_type=payload.event_type,
        value=payload.value,
        unit=payload.unit,
        severity=payload.severity,
        timestamp=ts,
    )

    item = event.model_dump()
    item["timestamp"] = ts.isoformat().replace("+00:00", "Z")
    item["event_type"] = event.event_type.value
    item["severity"] = event.severity.value

    events_table().put_item(Item=_to_decimal(item))
    return event


def list_events(
    building: Optional[str] = None,
    event_type: Optional[str] = None,
    severity: Optional[str] = None,
    limit: int = 50,
) -> list[dict]:
    """Return most recent events, optionally filtered."""
    table = events_table()

    if building:
        resp = table.query(
            IndexName="by_building_time",
            KeyConditionExpression=Key("building").eq(building),
            ScanIndexForward=False,
            Limit=limit,
        )
        items = resp.get("Items", [])
    else:
        resp = table.scan(Limit=limit)
        items = resp.get("Items", [])
        items.sort(key=lambda x: x["timestamp"], reverse=True)
        items = items[:limit]

    if event_type:
        items = [i for i in items if i["event_type"] == event_type]
    if severity:
        items = [i for i in items if i["severity"] == severity]

    return [_from_decimal(i) for i in items]


def get_stats() -> dict:
    """Aggregate occupancy + energy per building across recent events."""
    items = list_events(limit=500)

    by_building: dict[str, dict] = {}
    for e in items:
        b = e["building"]
        bucket = by_building.setdefault(
            b,
            {
                "occupancy_total": 0,
                "occupancy_readings": 0,
                "occupancy_max": 0,
                "energy_total_kwh": 0.0,
                "energy_readings": 0,
                "alerts": 0,
            },
        )
        if e["event_type"] == "occupancy":
            bucket["occupancy_total"] += e["value"]
            bucket["occupancy_readings"] += 1
            bucket["occupancy_max"] = max(bucket["occupancy_max"], e["value"])
        elif e["event_type"] == "energy":
            bucket["energy_total_kwh"] += e["value"]
            bucket["energy_readings"] += 1
        if e["severity"] in ("warning", "critical"):
            bucket["alerts"] += 1

    for b, bucket in by_building.items():
        r = bucket["occupancy_readings"]
        bucket["occupancy_avg"] = round(bucket["occupancy_total"] / r, 1) if r else 0
        bucket["energy_total_kwh"] = round(bucket["energy_total_kwh"], 2)

    return {
        "total_events": len(items),
        "buildings": by_building,
        "generated_at": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
    }
