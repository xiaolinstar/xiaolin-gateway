#!/usr/bin/env bash
# CD helper: seed missing .env.production keys from example, set COMPOSE_FILE, run key check.
# Usage: bash scripts/cd-seed-and-verify-env.sh <DESIRED_COMPOSE_FILE>
set -euo pipefail

DESIRED_COMPOSE="${1:?DESIRED_COMPOSE required}"
BASE_ENV_FILE="${BASE_ENV_FILE:-.env}"
DEPLOY_ENV_FILE="${DEPLOY_ENV_FILE:-.env.production}"

test -f "$BASE_ENV_FILE"
touch "$DEPLOY_ENV_FILE"
echo "COMPOSE_FILE=$DESIRED_COMPOSE"

ensure_env_key() {
  local file="$1"
  local key="$2"
  local value="$3"
  local tmp
  tmp="$(mktemp)"
  if [[ -f "$file" ]] && grep -qE "^${key}=" "$file"; then
    awk -v k="$key" -v v="$value" 'BEGIN{p=k"="} index($0,p)==1{$0=p v} {print}' "$file" >"$tmp"
  else
    if [[ -f "$file" ]]; then
      cat "$file" >"$tmp"
      printf '\n' >>"$tmp"
    else
      : >"$tmp"
    fi
    printf '%s=%s\n' "$key" "$value" >>"$tmp"
  fi
  mv "$tmp" "$file"
}

EXAMPLE_PROD=".env.production.example"
if [[ -f "$EXAMPLE_PROD" ]]; then
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "${line}" || "$line" =~ ^[[:space:]]*# ]] && continue
    [[ "$line" == *=* ]] || continue
    line="${line#"${line%%[![:space:]]*}"}"
    key="${line%%=*}"
    val="${line#*=}"
    if ! grep -qE "^${key}=" "$DEPLOY_ENV_FILE" 2>/dev/null; then
      ensure_env_key "$DEPLOY_ENV_FILE" "$key" "$val"
    fi
  done < "$EXAMPLE_PROD"
fi

ensure_env_key "$BASE_ENV_FILE" COMPOSE_FILE "$DESIRED_COMPOSE"
ensure_env_key "$DEPLOY_ENV_FILE" COMPOSE_FILE "$DESIRED_COMPOSE"

DEV_STANDARDS="${DEV_STANDARDS:-$HOME/AgentProjects/dev-standards}"
CHECK="$DEV_STANDARDS/scripts/env/check-env-keys.sh"
if [[ -x "$CHECK" ]]; then
  bash "$CHECK" --project . --strict --runtime .env --runtime .env.production --warn-extra
else
  echo "warn: dev-standards check script not found (skip key validation)"
fi
