"""
Alert engine.

Scans recent events and applies campus thresholds defined in
app.models.campus.THRESHOLDS. Returns a list of currently-breaching events
with a reason string.

The simulator sets severity client-side, but this service is the
authoritative source of alerts — it re-evaluates values server-side so that
misconfigured or malicious clients cannot inject fake "normal" severities.
"""

from __future__ import annotations

from datetime import UTC, datetime

from app.models.campus import THRESHOLDS
from app.services import event_service


# Which events map to which thresholds
def _evaluate(event: dict) -> tuple[bool, str | None, str | None]:
    """
    Return (is_alert, severity, reason) for one event.

    is_alert = True if the event breaches a threshold.
    severity = 'warning' | 'critical' | None
    reason   = human-readable explanation
    """
    et = event.get("event_type")
    value = float(event.get("value") or 0)

    if et == "occupancy":
        # value is people; we need capacity to compute %
        from app.models.campus import CAMPUS_LAYOUT

        capacity = CAMPUS_LAYOUT.get(event["building"], {}).get("capacity", {}).get(event["room"])
        if not capacity:
            return False, None, None
        pct = value / capacity
        if pct >= THRESHOLDS["occupancy_pct_critical"]:
            return (
                True,
                "critical",
                f"occupancy {value}/{capacity} ({pct:.0%}) over capacity",
            )
        if pct >= THRESHOLDS["occupancy_pct_warning"]:
            return True, "warning", f"occupancy {value}/{capacity} ({pct:.0%}) ≥80%"
        return False, None, None

    if et == "temperature":
        if value >= THRESHOLDS["temperature_c_critical"]:
            return (
                True,
                "critical",
                f"temperature {value}°C ≥ {THRESHOLDS['temperature_c_critical']}°C",
            )
        if value >= THRESHOLDS["temperature_c_warning"]:
            return (
                True,
                "warning",
                f"temperature {value}°C ≥ {THRESHOLDS['temperature_c_warning']}°C",
            )
        return False, None, None

    if et == "humidity":
        if value >= THRESHOLDS["humidity_pct_warning"]:
            return (
                True,
                "warning",
                f"humidity {value}% ≥ {THRESHOLDS['humidity_pct_warning']}%",
            )
        return False, None, None

    if et == "energy":
        if value >= THRESHOLDS["energy_kwh_critical"]:
            return (
                True,
                "critical",
                f"energy {value} kWh ≥ {THRESHOLDS['energy_kwh_critical']} kWh",
            )
        if value >= THRESHOLDS["energy_kwh_warning"]:
            return (
                True,
                "warning",
                f"energy {value} kWh ≥ {THRESHOLDS['energy_kwh_warning']} kWh",
            )
        return False, None, None

    if et in ("equipment_failure", "service_request"):
        sev = event.get("severity")
        if sev in ("warning", "critical"):
            return True, sev, f"{et} flagged as {sev}"
        return False, None, None

    return False, None, None


def list_alerts(
    building: str | None = None,
    severity: str | None = None,
    limit: int = 100,
) -> dict:
    """
    Scan recent events, apply thresholds server-side, and return alerts.
    """
    # Pull a larger window of events and filter in code
    events = event_service.list_events(building=building, limit=500)

    alerts: list[dict] = []
    for e in events:
        is_alert, sev, reason = _evaluate(e)
        if not is_alert:
            continue
        if severity and sev != severity:
            continue
        alerts.append(
            {
                **e,
                "alert_severity": sev,
                "alert_reason": reason,
            }
        )

    criticals = [a for a in alerts if a["alert_severity"] == "critical"]
    warnings = [a for a in alerts if a["alert_severity"] == "warning"]
    criticals.sort(key=lambda a: a["timestamp"], reverse=True)
    warnings.sort(key=lambda a: a["timestamp"], reverse=True)
    ordered = criticals + warnings

    by_building: dict[str, dict[str, int]] = {}
    for a in alerts:
        b = a["building"]
        bucket = by_building.setdefault(b, {"critical": 0, "warning": 0})
        bucket[a["alert_severity"]] += 1

    return {
        "count": len(ordered),
        "critical_count": len(criticals),
        "warning_count": len(warnings),
        "generated_at": datetime.now(UTC).isoformat().replace("+00:00", "Z"),
        "items": ordered[:limit],
    }
