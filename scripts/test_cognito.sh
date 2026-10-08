#!/usr/bin/env bash
# scripts/test_cognito.sh — full RBAC smoke test
set -euo pipefail

API="${API:-http://35.181.195.127:8000}"
SENSOR_KEY="${SENSOR_API_KEY:?export SENSOR_API_KEY first}"
STAFF_USER="staff1@campuspulse.local"
STAFF_PASS="Staff#2026Pass"
STUDENT_USER="student1@campuspulse.local"
STUDENT_PASS="Student#2026Pass"

echo "=== Login staff ==="
STAFF_JSON=$(curl -s -X POST "$API/auth/login" -H "Content-Type: application/json" \
  -d "{\"username\":\"$STAFF_USER\",\"password\":\"$STAFF_PASS\"}")
echo "$STAFF_JSON" | python -m json.tool

STAFF_TOKEN=$(echo "$STAFF_JSON" | python -c "import sys,json;print(json.load(sys.stdin)['access_token'])")
STAFF_ID_TOKEN=$(echo "$STAFF_JSON" | python -c "import sys,json;print(json.load(sys.stdin)['id_token'])")

echo "=== Login student ==="
STUDENT_JSON=$(curl -s -X POST "$API/auth/login" -H "Content-Type: application/json" \
  -d "{\"username\":\"$STUDENT_USER\",\"password\":\"$STUDENT_PASS\"}")
STUDENT_TOKEN=$(echo "$STUDENT_JSON" | python -c "import sys,json;print(json.load(sys.stdin)['access_token'])")

echo "STAFF_TOKEN length:   ${#STAFF_TOKEN}"
echo "STUDENT_TOKEN length: ${#STUDENT_TOKEN}"

echo "=== RBAC matrix ==="
curl -s -o /dev/null -w "no-auth   GET /events:  %{http_code}\n" "$API/events"
curl -s -o /dev/null -w "student   GET /events:  %{http_code}\n" -H "Authorization: Bearer $STUDENT_TOKEN" "$API/events"
curl -s -o /dev/null -w "student   POST /events: %{http_code}\n" -X POST "$API/events" -H "Authorization: Bearer $STUDENT_TOKEN" -H "Content-Type: application/json" -d '{"building":"X","room":"Y","event_type":"occupancy","value":1,"unit":"people"}'
curl -s -o /dev/null -w "staff     POST /events: %{http_code}\n" -X POST "$API/events" -H "Authorization: Bearer $STAFF_TOKEN" -H "Content-Type: application/json" -d '{"building":"Library-A","room":"A203","event_type":"occupancy","value":42,"unit":"people"}'
curl -s -o /dev/null -w "sensor    POST /events: %{http_code}\n" -X POST "$API/events" -H "X-Sensor-Api-Key: $SENSOR_KEY" -H "Content-Type: application/json" -d '{"building":"Science-C","room":"C101","event_type":"temperature","value":22.5,"unit":"°C"}'
curl -s -o /dev/null -w "no-auth   GET /stats:   %{http_code}\n" "$API/stats"
curl -s -o /dev/null -w "student   GET /stats:   %{http_code}\n" -H "Authorization: Bearer $STUDENT_TOKEN" "$API/stats"

echo "=== /auth/me (using id_token) ==="
curl -s -H "Authorization: Bearer $STAFF_ID_TOKEN" "$API/auth/me" | python -m json.tool