#!/usr/bin/env bash
# Verify VPS runtime env files include all keys from *.example templates.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DEV_STANDARDS="${DEV_STANDARDS:-$HOME/AgentProjects/dev-standards}"
CHECK="$DEV_STANDARDS/scripts/env/check-env-keys.sh"

if [[ ! -x "$CHECK" ]]; then
  echo "warn: dev-standards check script not found → $CHECK (skip key validation)"
  exit 0
fi

bash "$CHECK" --project "$ROOT" --strict --runtime .env --runtime .env.production --warn-extra
