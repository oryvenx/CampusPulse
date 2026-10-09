import uuid
from app.config import settings


def _sample_event() -> dict:
    return {
        "event_id": f"evt-test-{uuid.uuid4().hex[:8]}",
        "building": "Library-A",
        "room": "A203",
        "event_type": "occupancy",
        "value": 42,
        "unit": "people",
        "severity": "normal",
    }


def test_post_event_with_sensor_key(client):
    r = client.post(
        "/api/events",
        json=_sample_event(),
        headers={"X-Sensor-Api-Key": settings.sensor_api_key},
    )
    assert r.status_code == 201, r.text
    body = r.json()
    assert body["building"] == "Library-A"
    assert body["event_type"] == "occupancy"
    assert body["value"] == 42.0


def test_post_event_without_auth(client):
    r = client.post("/api/events", json=_sample_event())
    assert r.status_code == 401


def test_get_events_without_auth(client):
    r = client.get("/api/events")
    assert r.status_code == 401


def test_get_stats_without_auth(client):
    r = client.get("/api/stats")
    assert r.status_code == 401