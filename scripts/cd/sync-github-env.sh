#!/usr/bin/env bash
set -euo pipefail

DEV_STANDARDS="${DEV_STANDARDS:-$HOME/AgentProjects/dev-standards}"
exec node "$DEV_STANDARDS/scripts/env/sync-github-env.mjs" --project xiaolin-gateway "$@"
