#!/usr/bin/env bash
# Generate self-signed certs so nginx -t can load all vhost SSL directives in CI.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
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
mkdir -p app/xiaolin-docs/cert/xiaolinstar.com
gen app/xiaolin-docs/cert/xiaolinstar.com xiaolinstar.com.key xiaolinstar.com_bundle.crt

gen app/xiaolin-life/cert xiaolin.fun.key xiaolin.fun_bundle.crt

gen app/ai-todo/cert www.xingxiaolin.cn.key www.xingxiaolin.cn.pem
gen app/ai-todo/cert www.staging.xingxiaolin.cn.key www.staging.xingxiaolin.cn.pem

gen app/drink-budget/cert wodi.games.key wodi.games_bundle.crt
gen app/drink-budget/cert admin.wodi.games.key admin.wodi.games_bundle.crt
gen app/drink-budget/cert admin.drink-budget.com.key admin.drink-budget.com_bundle.crt

gen app/party-helper/cert api.wodi.games.key api.wodi.games_bundle.crt

echo "dummy certs ready under app/*/cert/"
