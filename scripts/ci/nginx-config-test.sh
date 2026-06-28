#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

bash scripts/ci/prepare-dummy-certs.sh

IMAGE="${NGINX_TEST_IMAGE:-nginx:alpine3.20-perl}"

docker run --rm \
  -v "$ROOT/app/gateway.conf:/etc/nginx/conf.d/default.conf:ro" \
  -v "$ROOT/app:/etc/nginx/app:ro" \
  -v "$ROOT/app/xiaolin-docs/cert:/etc/nginx/cert/xiaolin-docs:ro" \
  -v "$ROOT/app/xiaolin-life/cert:/etc/nginx/cert/xiaolin-life:ro" \
  -v "$ROOT/app/ai-todo/cert:/etc/nginx/cert/ai-todo:ro" \
  -v "$ROOT/app/drink-budget/cert:/etc/nginx/cert/drink-budget:ro" \
  -v "$ROOT/app/party-helper/cert:/etc/nginx/cert/party-helper:ro" \
  "$IMAGE" nginx -t

echo "nginx -t ok"
