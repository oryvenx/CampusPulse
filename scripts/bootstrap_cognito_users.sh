#!/usr/bin/env bash
set -euo pipefail

POOL_ID="${1:?Usage: $0 <user_pool_id> [region]}"
REGION="${2:-eu-west-3}"

set_password() {
  local email="$1"
  local pass="$2"
  aws cognito-idp admin-set-user-password \
    --user-pool-id "$POOL_ID" \
    --username "$email" \
    --password "$pass" \
    --permanent \
    --region "$REGION"
  echo "✅ password set for $email"
}

set_password "staff1@campuspulse.local"   "Staff#2026Pass"
set_password "student1@campuspulse.local" "Student#2026Pass"

echo
echo "Login credentials:"
echo "  staff1@campuspulse.local   / Staff#2026Pass"
echo "  student1@campuspulse.local / Student#2026Pass"
