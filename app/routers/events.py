"""
/events, /stats — protected.
"""

from typing import Optional

from fastapi import APIRouter, Depends, Header, HTTPException, Query, status
from fastapi.security import HTTPAuthorizationCredentials

from app.config import settings
from app.models.event import CampusEvent, EventCreate
from app.services import auth_service, event_service

router = APIRouter(tags=["events"])


def _sensor_or_staff(
    x_sensor_api_key: Optional[str] = Header(default=None, alias="X-Sensor-Api-Key"),
    creds: Optional[HTTPAuthorizationCredentials] = Depends(auth_service.bearer_scheme),
) -> dict:
    """
    POST /events accepts EITHER:
      - X-Sensor-Api-Key header matching SENSOR_API_KEY (simulated IoT devices), OR
      - Bearer token whose cognito:groups includes 'staff' (staff UI).
    """
    # Path 1: sensor API key
    if x_sensor_api_key and settings.sensor_api_key and x_sensor_api_key == settings.sensor_api_key:
        return {"sub": "sensor", "cognito:groups": ["staff"]}

    # Path 2: staff JWT
    if creds is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing X-Sensor-Api-Key or bearer token",
            headers={"WWW-Authenticate": "Bearer"},
        )
    claims = auth_service.verify_token(creds.credentials)
    if "staff" not in (claims.get("cognito:groups") or []):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Requires role: staff",
        )
    return claims


@router.post(
    "/events",
    response_model=CampusEvent,
    status_code=status.HTTP_201_CREATED,
)
def create_event(
    payload: EventCreate,
    _auth: dict = Depends(_sensor_or_staff),
) -> CampusEvent:
    """Ingest a campus event. Sensor API key OR staff JWT required."""
    try:
        return event_service.store_event(payload)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/events")
def get_events(
    building: Optional[str] = Query(None),
    event_type: Optional[str] = Query(None),
    severity: Optional[str] = Query(None),
    limit: int = Query(50, ge=1, le=500),
    _user: dict = Depends(auth_service.current_user),
) -> dict:
    """List recent events. Any authenticated Cognito user."""
    items = event_service.list_events(
        building=building, event_type=event_type, severity=severity, limit=limit
    )
    return {"count": len(items), "items": items}


@router.get("/stats")
def get_stats(_user: dict = Depends(auth_service.current_user)) -> dict:
    """Aggregated stats. Any authenticated Cognito user."""
    return event_service.get_stats()