from typing import Optional
from fastapi import APIRouter, HTTPException, Query, status

from app.models.event import CampusEvent, EventCreate
from app.services import event_service

router = APIRouter(tags=["events"])


@router.post("/events", response_model=CampusEvent, status_code=status.HTTP_201_CREATED)
def create_event(payload: EventCreate) -> CampusEvent:
    """Ingest a campus event."""
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
) -> dict:
    """List recent events, optionally filtered."""
    items = event_service.list_events(
        building=building, event_type=event_type, severity=severity, limit=limit
    )
    return {"count": len(items), "items": items}


@router.get("/stats")
def get_stats() -> dict:
    """Aggregated operational statistics per building."""
    return event_service.get_stats()