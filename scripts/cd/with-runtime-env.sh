#!/usr/bin/env bash
# Load root .env then .env.production (if present) and run docker compose.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

BASE="${BASE_ENV_FILE:-.env}"
DEPLOY="${DEPLOY_ENV_FILE:-.env.production}"

if [[ ! -f "$BASE" ]]; then
  echo "error: missing runtime file → $ROOT/$BASE" >&2
  echo "hint: cp .env.example .env and fill values (see docs/runtime-env-management.md)" >&2
  exit 1
fi

set -a
# shellcheck disable=SC1090
. "./$BASE"
if [[ -f "$DEPLOY" ]]; then
  # shellcheck disable=SC1090
  . "./$DEPLOY"
fi
set +a

exec docker compose "$@"
