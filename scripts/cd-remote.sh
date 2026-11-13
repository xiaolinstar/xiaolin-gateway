#!/usr/bin/env bash
# CD remote entrypoint — always invoke via: bash scripts/cd-remote.sh <cmd> [...]
# Keeps appleboy SSH bodies one-liners so host zsh does not parse multiline scripts.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

cmd="${1:?usage: bash scripts/cd-remote.sh <cmd> [args]}"
shift || true

party_precheck() {
  curl -fsS --max-time 15 http://111.229.38.208:30020/healthz | python3 -c \
    'import json,sys; value=json.load(sys.stdin); assert value.get("ok") is True and value.get("service")=="party-helper-web"; print(value)'
  curl -fsS --max-time 15 -H "Origin: https://wodi.games" \
    "http://111.229.38.208:30020/online/socket.io/?EIO=4&transport=polling" | python3 -c \
    'import json,sys; value=sys.stdin.read(); assert value.startswith("0"); packet=json.loads(value[1:]); assert "websocket" in packet["upgrades"]; print("online transport handshake ready")'
  openssl x509 -in app/party-helper/cert/wodi.games_bundle.crt -noout -checkhost wodi.games \
    | grep -F "does match certificate"
  openssl x509 -in app/party-helper/cert/wodi.games_bundle.crt -noout -checkhost www.wodi.games \
    | grep -F "does match certificate"
  openssl x509 -in app/party-helper/cert/wodi.games_bundle.crt -noout -checkend 604800
}

ensure_certs_121() {
  if [[ ! -f app/xiaolin-life/cert/xiaolin.fun.pem || ! -f app/xiaolin-life/cert/xiaolin.fun.key \
     || ! -f app/ai-todo/cert/xingxiaolin.cn.pem || ! -f app/ai-todo/cert/xingxiaolin.cn.key ]]; then
    echo "life/ai-todo certs missing — generating short-lived placeholders for nginx -t"
    echo "Replace with real certs before DNS cutover"
    bash scripts/prepare-certs.sh
  fi
  openssl x509 -in app/xiaolin-life/cert/xiaolin.fun.pem -noout -checkend 60
  openssl x509 -in app/ai-todo/cert/xingxiaolin.cn.pem -noout -checkend 60
}

compose_with_env() {
  # shellcheck disable=SC1091
  set -a
  # shellcheck disable=SC1091
  source .env
  # shellcheck disable=SC1091
  source .env.production
  set +a
  docker compose --env-file .env --env-file .env.production "$@"
}

case "$cmd" in
  sync)
    git pull --ff-only
    ;;
  party-precheck)
    party_precheck
    ;;
  ensure-certs-121)
    ensure_certs_121
    ;;
  seed-verify)
    bash scripts/cd-seed-and-verify-env.sh "${1:?DESIRED_COMPOSE required}"
    ;;
  compose-pull)
    compose_with_env pull
    ;;
  compose-up)
    compose_with_env up -d --remove-orphans
    ;;
  nginx-reload)
    docker exec nginx-gateway nginx -t
    docker exec nginx-gateway nginx -s reload
    ;;
  prune)
    docker image prune -f
    ;;
  *)
    echo "unknown cmd: $cmd" >&2
    echo "known: sync party-precheck ensure-certs-121 seed-verify compose-pull compose-up nginx-reload prune" >&2
    exit 1
    ;;
esac
