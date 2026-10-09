#!/usr/bin/env bash
#
# One-command deploy: sync code to EC2, reinstall deps, restart the service.
#
# Usage:
#   ./scripts/deploy_app.sh [EC2_HOST]
#
# EC2_HOST defaults to the Terraform output (api_public_ip).
#

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

# Resolve EC2 host
EC2_HOST="${1:-}"
if [[ -z "$EC2_HOST" ]]; then
  if [[ -d "$REPO_ROOT/infra/terraform" ]]; then
    EC2_HOST="$(cd "$REPO_ROOT/infra/terraform" && terraform output -raw api_public_ip 2>/dev/null || true)"
  fi
fi

if [[ -z "$EC2_HOST" ]]; then
  echo "❌  Usage: $0 <EC2_HOST>   (or ensure infra/terraform state is present)"
  exit 1
fi

KEY="${EC2_KEY:-$HOME/.ssh/campuspulse-key.pem}"

# Remove stale host key (EC2 may have been replaced by Terraform)
ssh-keygen -R "$EC2_HOST" >/dev/null 2>&1 || true

echo "▶ Deploying to ec2-user@${EC2_HOST} using key ${KEY}"
echo

ssh -i "$KEY" -o StrictHostKeyChecking=accept-new "ec2-user@${EC2_HOST}" 'bash -s' <<'REMOTE'
set -euo pipefail

cd /opt/campuspulse/repo

echo "── git pull ──"
git fetch --prune origin
git reset --hard origin/main

echo "── pip install ──"
. .venv/bin/activate
pip install --upgrade pip -q
pip install -q -r requirements.txt

echo "── refresh env from SSM ──"
sudo bash -c '
set -euo pipefail
REGION=$(grep ^AWS_REGION= /opt/campuspulse/env | cut -d= -f2)
PROJECT=campuspulse

fetch_ssm() {
  aws ssm get-parameter \
    --region "$REGION" \
    --name "$1" \
    --with-decryption \
    --query "Parameter.Value" \
    --output text
}

SENSOR_KEY=$(fetch_ssm "/$PROJECT/sensor_api_key")
POOL_ID=$(fetch_ssm "/$PROJECT/cognito_user_pool_id")
CLIENT_ID=$(fetch_ssm "/$PROJECT/cognito_client_id")

grep -vE "^SENSOR_API_KEY=|^COGNITO_USER_POOL_ID=|^COGNITO_CLIENT_ID=" /opt/campuspulse/env > /tmp/env.new
{
  echo "SENSOR_API_KEY=$SENSOR_KEY"
  echo "COGNITO_USER_POOL_ID=$POOL_ID"
  echo "COGNITO_CLIENT_ID=$CLIENT_ID"
} >> /tmp/env.new

mv /tmp/env.new /opt/campuspulse/env
chmod 600 /opt/campuspulse/env
chown root:root /opt/campuspulse/env
'

echo "── restart service ──"
sudo systemctl restart campuspulse
sleep 3

echo "── service status ──"
sudo systemctl status campuspulse --no-pager | head -12

echo
echo "── /api/health ──"
curl -s -m 5 http://127.0.0.1:8000/api/health || echo "(health check failed)"
REMOTE

echo
echo "✅  Deploy complete."