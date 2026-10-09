#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

EC2_HOST="${1:-}"
if [[ -z "$EC2_HOST" ]]; then
  if [[ -d "$REPO_ROOT/infra/terraform" ]]; then
    EC2_HOST="$(cd "$REPO_ROOT/infra/terraform" && terraform output -raw api_public_ip 2>/dev/null || true)"
  fi
fi

if [[ -z "$EC2_HOST" ]]; then
  echo "❌  Usage: $0 <EC2_HOST>"
  exit 1
fi

KEY="${EC2_KEY:-$HOME/.ssh/campuspulse-key.pem}"

# Remove stale host key (EC2 may have been replaced by Terraform)
ssh-keygen -R "$EC2_HOST" >/dev/null 2>&1 || true

echo "▶ Deploying to ec2-user@${EC2_HOST}"
echo

ssh -i "$KEY" -o StrictHostKeyChecking=accept-new "ec2-user@${EC2_HOST}" \
  "bash /opt/campuspulse/repo/scripts/deploy_ec2.sh"

echo
echo "✅  Local trigger complete."
