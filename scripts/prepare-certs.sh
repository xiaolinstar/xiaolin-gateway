#!/usr/bin/env bash
# Generate self-signed certs so nginx -t can load all vhost SSL directives in CI and local development.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

gen() {
  local dir=$1 key=$2 crt=$3
  mkdir -p "$dir"
  if [[ -f "$dir/$crt" && -f "$dir/$key" ]]; then
    return 0
  fi
  openssl req -x509 -newkey rsa:2048 \
    -keyout "$dir/$key" \
    -out "$dir/$crt" \
    -days 1 -nodes -subj "/CN=ci-gateway-test" >/dev/null 2>&1
}

gen app/xiaolin-docs/cert xiaolinstar.cn.key xiaolinstar.cn_bundle.crt

gen app/xiaolin-life/cert xiaolin.fun.key xiaolin.fun.pem

gen app/ai-todo/cert xingxiaolin.cn.key xingxiaolin.cn.pem

gen app/drinkzen/cert drinkzen.cn.key drinkzen.cn_bundle.crt
gen app/drinkzen/cert api.drinkzen.cn.key api.drinkzen.cn_bundle.crt
gen app/drinkzen/cert admin.drinkzen.cn.key admin.drinkzen.cn_bundle.crt

gen app/party-helper/cert wodi.games.key wodi.games_bundle.crt
gen app/party-helper/cert api.wodi.games.key api.wodi.games_bundle.crt
gen app/party-helper/cert admin.wodi.games.key admin.wodi.games_bundle.crt

echo "dummy certs ready under app/*/cert/"
