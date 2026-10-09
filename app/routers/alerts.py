"""
/alerts — staff-only alert feed.
"""

from typing import Optional

from fastapi import APIRouter, Depends, Query

from app.services import alert_service, auth_service

router = APIRouter(tags=["alerts"])


@router.get("/alerts")
def list_alerts(
    building: Optional[str] = Query(None),
    severity: Optional[str] = Query(None, pattern="^(warning|critical)$"),
    limit: int = Query(100, ge=1, le=500),
    _user: dict = Depends(auth_service.require_role("staff")),
) -> dict:
    """
    Return current alerts.

    Requires role: staff.

    Alerts are computed server-side from raw event values using campus
    thresholds (see app/models/campus.py). Client-provided severity
    fields are ignored for threshold-based event types.
    """
    return alert_service.list_alerts(building=building, severity=severity, limit=limit)
