#!/usr/bin/env bash
# One-time migration: env/production.env → .env + .env.production (run on VPS as deploy user).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

LEGACY="$ROOT/env/production.env"
DRY=0
FORCE=0

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Migrate deprecated env/production.env to root .env and .env.production.
Idempotent: skips when legacy file is absent.

Options:
  --dry-run   Print planned writes only
  --force     Overwrite existing .env / .env.production
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY=1; shift ;;
    --force) FORCE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "error: unknown arg $1" >&2; usage >&2; exit 1 ;;
  esac
done

if [[ ! -f "$LEGACY" ]]; then
  echo "ok: no legacy file → $LEGACY (nothing to migrate)"
  exit 0
fi

declare -A LEGACY_VALS=()
while IFS= read -r line || [[ -n "$line" ]]; do
  [[ "$line" =~ ^[[:space:]]*# ]] && continue
  [[ -z "${line//[[:space:]]/}" ]] && continue
  if [[ "$line" =~ ^([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]]; then
    LEGACY_VALS["${BASH_REMATCH[1]}"]="${BASH_REMATCH[2]}"
  fi
done < "$LEGACY"

keys_in_template() {
  local template=$1
  grep -E '^[A-Za-z_][A-Za-z0-9_]*=' "$template" | cut -d= -f1
}

value_for_key() {
  local key=$1
  local template=$2
  if [[ -n "${LEGACY_VALS[$key]+x}" ]]; then
    printf '%s' "${LEGACY_VALS[$key]}"
    return 0
  fi
  grep -E "^${key}=" "$template" | head -1 | cut -d= -f2- || true
}

write_from_template() {
  local template=$1
  local out=$2
  local tmp
  tmp="$(mktemp)"
  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" =~ ^([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]]; then
      key="${BASH_REMATCH[1]}"
      val="$(value_for_key "$key" "$template")"
      printf '%s=%s\n' "$key" "$val" >> "$tmp"
    else
      printf '%s\n' "$line" >> "$tmp"
    fi
  done < "$template"
  if [[ $DRY -eq 1 ]]; then
    echo "would write $out from $template ($(wc -l < "$tmp") lines)"
    rm -f "$tmp"
  else
    mv "$tmp" "$out"
    chmod 600 "$out"
    echo "wrote $out"
  fi
}

write_env_if_needed() {
  local template=$1
  local out=$2
  if [[ -f "$out" && -s "$out" && $FORCE -eq 0 ]]; then
    echo "skip: $out exists (use --force to overwrite)"
    return 0
  fi
  write_from_template "$template" "$out"
}

write_env_if_needed "$ROOT/.env.example" "$ROOT/.env"
write_env_if_needed "$ROOT/.env.production.example" "$ROOT/.env.production"

bak="$ROOT/env/production.env.migrated.$(date +%Y%m%d%H%M%S)"
if [[ $DRY -eq 1 ]]; then
  echo "would move $LEGACY → $bak"
else
  mv "$LEGACY" "$bak"
  echo "archived legacy → $bak"
fi

if [[ $DRY -eq 0 ]]; then
  bash "$ROOT/scripts/cd/verify-runtime-env.sh"
  echo "next: ~/AgentProjects/dev-standards/scripts/sync.sh env import-config --project xiaolin-gateway"
fi
