#!/usr/bin/env bash
#
# scripts/test_alert.sh — full /alerts smoke test
#
# Requires in environment:
#   SENSOR_API_KEY   — the sensor key from terraform.tfvars
#
# Optional:
#   API              — base URL (default: terraform output or 35.181.195.127:8000)
#
# Usage:
#   export SENSOR_API_KEY=$(grep sensor_api_key infra/terraform/terraform.tfvars | cut -d'"' -f2)
#   ./scripts/test_alert.sh
#

set -euo pipefail

# ---------- resolve API URL ----------
if [[ -z "${API:-}" ]]; then
  if [[ -d infra/terraform ]]; then
    API="http://$(cd infra/terraform && terraform output -raw api_public_ip 2>/dev/null || echo 35.181.195.127):8000"
  else
    API="http://35.181.195.127:8000"
  fi
fi

# ---------- require SENSOR_API_KEY ----------
if [[ -z "${SENSOR_API_KEY:-}" ]]; then
  echo "❌  SENSOR_API_KEY is not set."
  echo "    Run:  export SENSOR_API_KEY=\$(grep sensor_api_key infra/terraform/terraform.tfvars | cut -d'\"' -f2)"
  exit 1
fi

STAFF_USER="staff1@campuspulse.local"
STAFF_PASS="Staff#2026Pass"
STUDENT_USER="student1@campuspulse.local"
STUDENT_PASS="Student#2026Pass"

echo "▶ API: $API"
echo

# ---------- logins ----------
echo "── logging in as staff & student ──"
STAFF_TOKEN=$(curl -s -X POST "$API/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"$STAFF_USER\",\"password\":\"$STAFF_PASS\"}" \
  | python -c "import sys,json;print(json.load(sys.stdin)['access_token'])")

STUDENT_TOKEN=$(curl -s -X POST "$API/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"$STUDENT_USER\",\"password\":\"$STUDENT_PASS\"}" \
  | python -c "import sys,json;print(json.load(sys.stdin)['access_token'])")

echo "  staff token:   ${#STAFF_TOKEN} chars"
echo "  student token: ${#STUDENT_TOKEN} chars"
echo

# ---------- seed simulated events ----------
echo "── seeding 30 simulated events ──"
python -m simulator.generate_events --count 30 --url "$API/events" >/dev/null
echo "  done"
echo

# ---------- force three critical events ----------
# Note: we deliberately send severity=normal in the payload.
# The server-side alert engine re-evaluates the raw value and must
# still flag these as critical. This proves the client can't fake "normal".
echo "── forcing 3 critical events (severity=normal in payload) ──"
for spec in \
  '{"building":"Student-Center","room":"SC01","event_type":"occupancy","value":220,"unit":"people","severity":"normal"}' \
  '{"building":"Science-C","room":"C101","event_type":"temperature","value":35.2,"unit":"°C","severity":"normal"}' \
  '{"building":"Engineering-B","room":"B201","event_type":"energy","value":95.5,"unit":"kWh","severity":"normal"}'
do
  code=$(curl -s -o /dev/null -w "%{http_code}" \
    -X POST "$API/events" \
    -H "X-Sensor-Api-Key: $SENSOR_API_KEY" \
    -H "Content-Type: application/json" \
    -d "$spec")
  echo "  HTTP $code"
done
echo

# ---------- /alerts auth matrix ----------
echo "── /alerts auth matrix ──"
printf "  %-28s %s\n" "no-auth GET /alerts:"  "$(curl -s -o /dev/null -w '%{http_code}' "$API/alerts")"
printf "  %-28s %s\n" "student GET /alerts:"  "$(curl -s -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $STUDENT_TOKEN" "$API/alerts")"
printf "  %-28s %s\n" "staff   GET /alerts:"  "$(curl -s -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $STAFF_TOKEN" "$API/alerts")"
echo

# ---------- /alerts full list (critical first) ----------
echo "── /alerts (all, critical first) ──"
curl -s -H "Authorization: Bearer $STAFF_TOKEN" "$API/alerts" | python - <<'PY'
import sys, json
d = json.load(sys.stdin)
print(f"  total={d['count']}  critical={d['critical_count']}  warning={d['warning_count']}")
for a in d["items"][:10]:
    print(f"    {a['alert_severity']:8} {a['building']:16} {a['room']:5} "
          f"{a['event_type']:15} {a['alert_reason']}")
PY
echo

# ---------- /alerts?severity=critical ----------
echo "── /alerts?severity=critical ──"
curl -s -H "Authorization: Bearer $STAFF_TOKEN" "$API/alerts?severity=critical" | python - <<'PY'
import sys, json
d = json.load(sys.stdin)
print(f"  total={d['count']}  critical={d['critical_count']}  warning={d['warning_count']}")
for a in d["items"]:
    print(f"    {a['building']}/{a['room']}  {a['alert_reason']}")
PY
echo

# ---------- /alerts?building=Student-Center ----------
echo "── /alerts?building=Student-Center ──"
curl -s -H "Authorization: Bearer $STAFF_TOKEN" "$API/alerts?building=Student-Center" | python - <<'PY'
import sys, json
d = json.load(sys.stdin)
print(f"  total={d['count']}  critical={d['critical_count']}  warning={d['warning_count']}")
for a in d["items"][:5]:
    print(f"    {a['alert_severity']:8} {a['room']:5}  {a['alert_reason']}")
PY
echo

# ---------- /alerts summary (by_building) ----------
echo "── /alerts by_building summary ──"
curl -s -H "Authorization: Bearer $STAFF_TOKEN" "$API/alerts" | python - <<'PY'
import sys, json
d = json.load(sys.stdin)
for b, counts in sorted(d.get("by_building", {}).items()):
    print(f"  {b:20}  critical={counts['critical']}  warning={counts['warning']}")
PY
echo

echo "✅  test_alert.sh complete"
