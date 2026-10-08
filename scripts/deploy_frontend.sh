#!/usr/bin/env bash
#
# Build the SPA and sync it to S3 + invalidate CloudFront.
#
# Usage:
#   ./scripts/deploy_frontend.sh
#

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

TF_DIR="$REPO_ROOT/infra/terraform"

# ---------- resolve terraform outputs ----------
BUCKET=$(cd "$TF_DIR" && terraform output -raw frontend_bucket)
DIST_ID=$(cd "$TF_DIR" && terraform output -raw cloudfront_distribution_id)
CF_URL=$(cd "$TF_DIR" && terraform output -raw cloudfront_url)

echo "▶ Deploying frontend to s3://${BUCKET}"
echo "  CloudFront: ${CF_URL}"
echo

# ---------- build ----------
cd "$REPO_ROOT/dashboard"

if [[ ! -d node_modules ]]; then
  echo "▶ npm install"
  npm ci
fi

echo "▶ npm run build"
npm run build

# ---------- upload ----------
echo "▶ aws s3 sync"
aws s3 sync dist "s3://${BUCKET}" --delete \
  --cache-control "public,max-age=31536000,immutable" \
  --exclude "index.html" \
  --exclude "*.map"

# index.html must not be cached long
aws s3 cp dist/index.html "s3://${BUCKET}/index.html" \
  --cache-control "public,max-age=60,must-revalidate"

# ---------- invalidate ----------
echo "▶ CloudFront invalidation"
aws cloudfront create-invalidation \
  --distribution-id "$DIST_ID" \
  --paths "/" "/index.html" "/assets/*" \
  --query 'Invalidation.Status' --output text

echo
echo "✅  Frontend deployed."
echo "    URL: ${CF_URL}"