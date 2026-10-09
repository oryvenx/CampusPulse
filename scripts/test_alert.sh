API=http://35.181.195.127:8000

# Get tokens
STAFF_TOKEN=$(curl -s -X POST $API/auth/login -H "Content-Type: application/json" \
  -d '{"username":"staff1@campuspulse.local","password":"Staff#2026Pass"}' \
  | python -c "import sys,json;print(json.load(sys.stdin)['access_token'])")

STUDENT_TOKEN=$(curl -s -X POST $API/auth/login -H "Content-Type: application/json" \
  -d '{"username":"student1@campuspulse.local","password":"Student#2026Pass"}' \
  | python -c "import sys,json;print(json.load(sys.stdin)['access_token'])")

# Send a few alerts to make sure we have data
export SENSOR_API_KEY=715890858d59fd4263778485e99ed79f905f494eeb0ed2ab
python -m simulator.generate_events --count 30 --url $API/events

# Test matrix
echo "=== /alerts auth matrix ==="
curl -s -o /dev/null -w "no-auth GET /alerts:  %{http_code}\n" $API/alerts
curl -s -o /dev/null -w "student GET /alerts:  %{http_code}\n" -H "Authorization: Bearer $STUDENT_TOKEN" $API/alerts
curl -s -o /dev/null -w "staff   GET /alerts:  %{http_code}\n" -H "Authorization: Bearer $STAFF_TOKEN" $API/alerts

echo
echo "=== /alerts content (staff) ==="
curl -s -H "Authorization: Bearer $STAFF_TOKEN" $API/alerts | python -m json.tool | head -60

echo
echo "=== /alerts?severity=critical (staff) ==="
curl -s -H "Authorization: Bearer $STAFF_TOKEN" "$API/alerts?severity=critical" \
  | python -c "import sys,json;d=json.load(sys.stdin);print(f'critical_count={d[\"critical_count\"]}, warning_count={d[\"warning_count\"]}, total={d[\"count\"]}')"

echo
echo "=== /alerts?building=Library-A (staff) ==="
curl -s -H "Authorization: Bearer $STAFF_TOKEN" "$API/alerts?building=Library-A" \
  | python -c "import sys,json;d=json.load(sys.stdin);print(f'total={d[\"count\"]}');[print(f'  {a[\"alert_severity\"]:8} {a[\"building\"]}/{a[\"room\"]} {a[\"event_type\"]:15} {a[\"alert_reason\"]}') for a in d['items'][:5]]"
