"""
Smoke tests for the health endpoint and app boot.
"""


def test_health(client):
    r = client.get("/api/health")
    assert r.status_code == 200
    body = r.json()
    assert body["status"] == "ok"
    assert body["region"] == "eu-west-3"
    assert "env" in body
