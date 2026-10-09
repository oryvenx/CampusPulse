"""
Campus event data model.

Matches the schema from Appendix A of the project spec:
{
  "event_id": "evt-2026-0001",
  "building": "Library-A",
  "room": "A203",
  "event_type": "occupancy",
  "value": 42,
  "unit": "people",
  "severity": "normal",
  "timestamp": "2026-05-10T09:30:00Z"
}
"""

from datetime import datetime
from enum import Enum

from pydantic import BaseModel, Field, field_validator


class EventType(str, Enum):
    OCCUPANCY = "occupancy"
    TEMPERATURE = "temperature"
    HUMIDITY = "humidity"
    ENERGY = "energy"
    DOOR = "door"
    EQUIPMENT_FAILURE = "equipment_failure"
    SERVICE_REQUEST = "service_request"


class Severity(str, Enum):
    NORMAL = "normal"
    WARNING = "warning"
    CRITICAL = "critical"


class CampusEvent(BaseModel):
    event_id: str = Field(..., examples=["evt-2026-0001"])
    building: str = Field(..., examples=["Library-A"])
    room: str = Field(..., examples=["A203"])
    event_type: EventType
    value: float
    unit: str = Field(..., examples=["people", "°C", "%", "kWh"])
    severity: Severity = Severity.NORMAL
    timestamp: datetime

    @field_validator("event_id")
    @classmethod
    def validate_event_id(cls, v: str) -> str:
        if not v.startswith("evt-"):
            raise ValueError("event_id must start with 'evt-'")
        return v


class EventCreate(BaseModel):
    """Payload accepted by POST /events (event_id and timestamp optional)."""

    event_id: str | None = None
    building: str
    room: str
    event_type: EventType
    value: float
    unit: str
    severity: Severity = Severity.NORMAL
    timestamp: datetime | None = None
