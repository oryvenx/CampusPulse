#!/bin/bash

set -euo pipefail

REPO_DIR=/opt/campuspulse/repo
ENV_FILE=/opt/campuspulse/env

echo "════════════════════════════════════════════"
echo "  CampusPulse deploy — $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "════════════════════════════════════════════"

cd "$REPO_DIR"

# ---- 1. Pull latest ----
echo "── git fetch + reset ──"
git fetch --prune origin
git reset --hard origin/main
echo "  HEAD: $(git rev-parse --short HEAD) — $(git log -1 --pretty=%s)"

# ---- 2. Install Python deps ----
echo "── pip install ──"
. .venv/bin/activate
pip install --upgrade pip -q
pip install -q -r requirements.txt

# ---- 3. Refresh secrets from SSM ----
echo "── refresh env from SSM ──"
REGION=$(grep ^AWS_REGION= "$ENV_FILE" | cut -d= -f2)
PROJECT=campuspulse

fetch_ssm() {
  aws ssm get-parameter \
    --region "$REGION" \
    --name "$1" \
    --with-decryption \
    --query 'Parameter.Value' \
    --output text
}

SENSOR_KEY=$(fetch_ssm "/$PROJECT/sensor_api_key")
POOL_ID=$(fetch_ssm "/$PROJECT/cognito_user_pool_id")
CLIENT_ID=$(fetch_ssm "/$PROJECT/cognito_client_id")

grep -vE "^SENSOR_API_KEY=|^COGNITO_USER_POOL_ID=|^COGNITO_CLIENT_ID=" "$ENV_FILE" > /tmp/env.new
{
  echo "SENSOR_API_KEY=$SENSOR_KEY"
  echo "COGNITO_USER_POOL_ID=$POOL_ID"
  echo "COGNITO_CLIENT_ID=$CLIENT_ID"
} >> /tmp/env.new

sudo mv /tmp/env.new "$ENV_FILE"
sudo chmod 600 "$ENV_FILE"
sudo chown root:root "$ENV_FILE"

# ---- 4. Restart the app ----
echo "── systemctl restart campuspulse ──"
sudo systemctl restart campuspulse
sleep 3

# ---- 5. Verify ----
echo "── service status ──"
sudo systemctl status campuspulse --no-pager | head -8

echo
echo "── /api/health ──"
HEALTH=$(curl -s -m 5 http://127.0.0.1:8000/api/health || echo "(health check failed)")
echo "$HEALTH"

# Fail the deploy if the health check didn't return the expected JSON
if ! echo "$HEALTH" | grep -q '"status":"ok"'; then
  echo "❌  Health check failed"
  exit 1
fi

echo
echo "✅  Deploy successful on $(hostname)"