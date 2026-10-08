API=http://35.181.195.127:8000

# 1. Login as staff
STAFF_JSON=$(curl -s -X POST $API/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"staff1@campuspulse.local","password":"Staff#2026Pass"}')
echo "$STAFF_JSON" | python -m json.tool
STAFF_TOKEN=$(echo "$STAFF_JSON" | python -c "import sys,json;print(json.load(sys.stdin)['access_token'])")
echo "STAFF_TOKEN length: ${#STAFF_TOKEN}"

# 2. Login as student
STUDENT_JSON=$(curl -s -X POST $API/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"student1@campuspulse.local","password":"Student#2026Pass"}')
STUDENT_TOKEN=$(echo "$STUDENT_JSON" | python -c "import sys,json;print(json.load(sys.stdin)['access_token'])")
echo "STUDENT_TOKEN length: ${#STUDENT_TOKEN}"

# 3. No token → 401
curl -s -o /dev/null -w "no-auth /events: %{http_code}\n" $API/events
# expect: 401

# 4. Student reads → 200
curl -s -o /dev/null -w "student GET /events: %{http_code}\n" \
  -H "Authorization: Bearer $STUDENT_TOKEN" $API/events
# expect: 200

# 5. Student writes → 403
curl -s -o /dev/null -w "student POST /events: %{http_code}\n" \
  -X POST $API/events \
  -H "Authorization: Bearer $STUDENT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"building":"X","room":"Y","event_type":"occupancy","value":1,"unit":"people"}'
# expect: 403

# 6. Staff writes → 201
curl -s -o /dev/null -w "staff POST /events: %{http_code}\n" \
  -X POST $API/events \
  -H "Authorization: Bearer $STAFF_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"building":"Library-A","room":"A203","event_type":"occupancy","value":42,"unit":"people"}'
# expect: 201

# 7. Sensor key writes → 201
SENSOR_KEY=$(cd infra/terraform && terraform output -raw sensor_api_key 2>/dev/null || echo "PUT_YOUR_KEY_HERE")
curl -s -o /dev/null -w "sensor POST /events: %{http_code}\n" \
  -X POST $API/events \
  -H "X-Sensor-Api-Key: $SENSOR_KEY" \
  -H "Content-Type: application/json" \
  -d '{"building":"Science-C","room":"C101","event_type":"temperature","value":22.5,"unit":"°C"}'
# expect: 201

# 8. /auth/me
curl -s -H "Authorization: Bearer $STAFF_TOKEN" $API/auth/me | python -m json.tool
# expect: {"username":"staff1@campuspulse.local","email":...,"name":"Ada Staff","groups":["staff"]}