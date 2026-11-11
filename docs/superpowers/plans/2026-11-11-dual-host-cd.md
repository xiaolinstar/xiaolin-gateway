# Dual-host CD (tencent-101 / aliyun-121) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Split nginx-gateway CD across GitHub Environments `tencent-101` and `aliyun-121`, with compose overlays that disable unused vhosts via empty conf so each host only needs its own certificates.

**Architecture:** Keep one `cd.yml`. Auto CD after CI always deploys `tencent-101`. Manual `workflow_dispatch` requires `target`. Host-specific `docker-compose.*.yml` bind-mount `app/_disabled/empty.conf` over unused project confs; `aliyun-121` also mounts `ai-todo.121.overlay`.

**Tech Stack:** Docker Compose, Nginx, GitHub Actions Environments, appleboy/ssh-action

**Spec:** `docs/superpowers/specs/2026-11-11-dual-host-cd-design.md`

## Global Constraints

- Environment names exactly: `tencent-101`, `aliyun-121`
- Auto deploy on `workflow_run` → **tencent-101 only**
- Delete `colocate_121` input; `target=aliyun-121` implies 121 compose
- Prefer **delete** `docker-compose.121.yml` and update references (no empty stub)
- Do not change `gateway.conf` include strategy
- Do not auto-deploy `aliyun-121` on every main merge
- Minimal scope: compose overlays + CD + docs/env examples

## File map

| Path | Responsibility |
|------|----------------|
| `app/_disabled/empty.conf` | Comment-only nginx file used as bind-mount disable stub |
| `docker-compose.tencent-101.yml` | Disable life + ai-todo vhosts on 101 |
| `docker-compose.aliyun-121.yml` | ai-todo `:8082` overlay + disable docs/drinkzen/party |
| `docker-compose.121.yml` | **Delete** after aliyun file exists |
| `.github/workflows/cd.yml` | Dual-target CD + Environments |
| `.github/workflows/ci.yml` | Also `nginx -t` both production overlays |
| `docs/routing-registry.md` | Dual-host ownership + compose names |
| `docs/env/*` | Environment secret examples |
| `README.md` | Short CD target note |

---

### Task 1: Empty conf + host compose overlays

**Files:**
- Create: `app/_disabled/empty.conf`
- Create: `docker-compose.tencent-101.yml`
- Create: `docker-compose.aliyun-121.yml`
- Delete: `docker-compose.121.yml`

**Interfaces:**
- Consumes: existing `app/ai-todo/ai-todo.121.overlay`, base `docker-compose.yml` volume layout
- Produces: overlay files selected via `COMPOSE_FILE` in later tasks

- [ ] **Step 1: Create empty conf**

```nginx
# Intentionally empty — bind-mounted over unused vhost confs so
# include /etc/nginx/app/*/*.conf loads no server/upstream for that path.
# Also matched as app/_disabled/empty.conf (harmless).
```

- [ ] **Step 2: Create `docker-compose.tencent-101.yml`**

```yaml
# Overlay for Tencent Cloud VPS (Environment tencent-101).
# Disables life / ai-todo vhosts so those cert dirs are not required.
# COMPOSE_FILE=docker-compose.yml:docker-compose.tencent-101.yml:observability-compose.yml

services:
  nginx-gateway:
    volumes:
      - ./app/_disabled/empty.conf:/etc/nginx/app/xiaolin-life/xiaolin-life.conf:ro
      - ./app/_disabled/empty.conf:/etc/nginx/app/ai-todo/ai-todo.conf:ro
```

- [ ] **Step 3: Create `docker-compose.aliyun-121.yml` and delete `docker-compose.121.yml`**

```yaml
# Overlay for Aliyun ECS (Environment aliyun-121).
# life stays on host.docker.internal:8080 (base conf); ai-todo → :8082;
# docs / drinkzen / party-helper vhosts disabled (no certs on this host).
# COMPOSE_FILE=docker-compose.yml:docker-compose.aliyun-121.yml:observability-compose.yml

services:
  nginx-gateway:
    volumes:
      - ./app/ai-todo/ai-todo.121.overlay:/etc/nginx/app/ai-todo/ai-todo.conf:ro
      - ./app/_disabled/empty.conf:/etc/nginx/app/xiaolin-docs/xiaolin-docs.conf:ro
      - ./app/_disabled/empty.conf:/etc/nginx/app/drinkzen/drinkzen.conf:ro
      - ./app/_disabled/empty.conf:/etc/nginx/app/party-helper/party-helper.conf:ro
```

Then: `git rm docker-compose.121.yml`

- [ ] **Step 4: Local verify compose merge + nginx -t for both overlays**

```bash
cp -n .env.example .env
bash scripts/prepare-certs.sh

# tencent-101: life/ai-todo must disappear from nginx -T
COMPOSE_FILE=docker-compose.yml:docker-compose.tencent-101.yml \
  docker compose run --rm nginx-gateway nginx -T 2>/dev/null \
  | tee /tmp/nginx-101.T
grep -E 'server_name.*(xiaolin\.fun|xingxiaolin\.cn)' /tmp/nginx-101.T && exit 1 || true
grep -E 'server_name.*(wodi\.games|drinkzen\.cn|xiaolinstar\.cn)' /tmp/nginx-101.T

# aliyun-121: only life + ai-todo app vhosts (plus gateway)
COMPOSE_FILE=docker-compose.yml:docker-compose.aliyun-121.yml \
  docker compose run --rm nginx-gateway nginx -T 2>/dev/null \
  | tee /tmp/nginx-121.T
grep -E 'server_name.*(wodi\.games|drinkzen\.cn|xiaolinstar\.cn)' /tmp/nginx-121.T && exit 1 || true
grep -F 'host.docker.internal:8082' /tmp/nginx-121.T
grep -E 'server_name.*xiaolin\.fun' /tmp/nginx-121.T
```

Expected: both `nginx -t`/`-T` succeed; 101 has no fun/xingxiaolin server_name; 121 has `:8082` and fun, no wodi/drinkzen/xiaolinstar server blocks from those projects.

- [ ] **Step 5: Commit**

```bash
git add app/_disabled/empty.conf docker-compose.tencent-101.yml docker-compose.aliyun-121.yml
git rm docker-compose.121.yml
git commit -m "$(cat <<'EOF'
feat(compose): add tencent-101 / aliyun-121 vhost disable overlays

Bind empty.conf over unused projects so each host skips foreign certs;
replace docker-compose.121.yml with aliyun-121 overlay.

EOF
)"
```

---

### Task 2: CI covers both production overlays

**Files:**
- Modify: `.github/workflows/ci.yml` (nginx-config job)

**Interfaces:**
- Consumes: compose files from Task 1
- Produces: CI gate that fails if overlays break `nginx -t`

- [ ] **Step 1: Extend nginx-config job after existing production test**

Add two steps (keep existing base + local tests):

```yaml
      - name: Test tencent-101 overlay
        run: |
          COMPOSE_FILE=docker-compose.yml:docker-compose.tencent-101.yml \
            docker compose run --rm nginx-gateway nginx -t
      - name: Test aliyun-121 overlay
        run: |
          COMPOSE_FILE=docker-compose.yml:docker-compose.aliyun-121.yml \
            docker compose run --rm nginx-gateway nginx -t
```

Place them after `Test production config` and before (or after) local overlay test. `prepare-certs.sh` already ran in the prior step.

- [ ] **Step 2: Run locally equivalent commands (same as Task 1 Step 4 nginx -t only)**

```bash
bash scripts/prepare-certs.sh
COMPOSE_FILE=docker-compose.yml:docker-compose.tencent-101.yml \
  docker compose run --rm nginx-gateway nginx -t
COMPOSE_FILE=docker-compose.yml:docker-compose.aliyun-121.yml \
  docker compose run --rm nginx-gateway nginx -t
```

Expected: `nginx: configuration file ... test is successful` twice.

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/ci.yml
git commit -m "$(cat <<'EOF'
ci(nginx): test tencent-101 and aliyun-121 compose overlays

EOF
)"
```

---

### Task 3: Dual-target CD workflow

**Files:**
- Modify: `.github/workflows/cd.yml` (replace inputs / env / job wiring; keep SSH script bodies)

**Interfaces:**
- Consumes: `COMPOSE_FILE` strings from spec; Environment secrets `SERVER_*`
- Produces: deploy job with `environment` + per-target steps

- [ ] **Step 1: Rewrite workflow header (trigger, concurrency, env, job)**

Replace the top of `cd.yml` through job `env:` with:

```yaml
name: CD Pipeline, Deploy to Target Server

on:
  workflow_dispatch:
    inputs:
      target:
        description: "Deploy target Environment (tencent-101 auto on CI; aliyun-121 manual only)."
        required: true
        type: choice
        options:
          - tencent-101
          - aliyun-121
        default: tencent-101
      skip_party_helper_precheck:
        description: "Skip Party Helper upstream precheck (tencent-101 only)."
        required: true
        type: boolean
        default: false
  workflow_run:
    workflows: [CI]
    types: [completed]
    branches: [main]

concurrency:
  group: production-deploy-${{ github.event_name == 'workflow_dispatch' && inputs.target || 'tencent-101' }}
  cancel-in-progress: false

permissions:
  contents: read

env:
  SERVER_DIR: ~/AgentProjects/xiaolin-gateway
  BASE_ENV_FILE: .env
  DEPLOY_ENV_FILE: .env.production
  PRODUCTION_COMPOSE_FILE_TENCENT_101: docker-compose.yml:docker-compose.tencent-101.yml:observability-compose.yml
  PRODUCTION_COMPOSE_FILE_ALIYUN_121: docker-compose.yml:docker-compose.aliyun-121.yml:observability-compose.yml

jobs:
  deploy-to-server:
    runs-on: ubuntu-latest
    if: >-
      github.event_name == 'workflow_dispatch' ||
      github.event.workflow_run.conclusion == 'success'
    environment: ${{ github.event_name == 'workflow_dispatch' && inputs.target || 'tencent-101' }}
    env:
      DEPLOY_TARGET: ${{ github.event_name == 'workflow_dispatch' && inputs.target || 'tencent-101' }}
      SKIP_PARTY_HELPER_PRECHECK: ${{ github.event_name == 'workflow_dispatch' && inputs.skip_party_helper_precheck || false }}
```

Do **not** keep `colocate_121` or old `PRODUCTION_COMPOSE_FILE` / `_121` without host overlay.

- [ ] **Step 2: Gate Party Helper precheck and life/ai-todo cert ensure**

Party step `if:`:

```yaml
        if: ${{ env.DEPLOY_TARGET == 'tencent-101' && env.SKIP_PARTY_HELPER_PRECHECK != 'true' }}
```

Cert ensure step: rename to `Ensure life + ai-todo cert files exist (aliyun-121)` and set:

```yaml
        if: ${{ env.DEPLOY_TARGET == 'aliyun-121' }}
```

Script body: keep life placeholder logic; also ensure ai-todo pair exists via same `scripts/prepare-certs.sh` (script already generates both). After script, check both:

```bash
            if [[ ! -f app/xiaolin-life/cert/xiaolin.fun_bundle.crt || ! -f app/xiaolin-life/cert/xiaolin.fun.key \
               || ! -f app/ai-todo/cert/xingxiaolin.cn.pem || ! -f app/ai-todo/cert/xingxiaolin.cn.key ]]; then
              echo "life/ai-todo certs missing — generating short-lived placeholders for nginx -t"
              echo "Replace with real certs before DNS cutover"
              bash scripts/prepare-certs.sh
            fi
            openssl x509 -in app/xiaolin-life/cert/xiaolin.fun_bundle.crt -noout -checkend 60
            openssl x509 -in app/ai-todo/cert/xingxiaolin.cn.pem -noout -checkend 60
```

- [ ] **Step 3: Fix Verify runtime env keys to select COMPOSE_FILE by DEPLOY_TARGET**

Pass `envs: DEPLOY_TARGET` into ssh-action. Inside script:

```bash
            if [[ "${DEPLOY_TARGET}" == "aliyun-121" ]]; then
              DESIRED_COMPOSE="${{ env.PRODUCTION_COMPOSE_FILE_ALIYUN_121 }}"
            else
              DESIRED_COMPOSE="${{ env.PRODUCTION_COMPOSE_FILE_TENCENT_101 }}"
            fi
```

Keep `ensure_env_key` helper unchanged.

- [ ] **Step 4: Fix Pull service images default COMPOSE_FILE fallback**

```bash
            export COMPOSE_FILE="${COMPOSE_FILE:-${{ env.PRODUCTION_COMPOSE_FILE_TENCENT_101 }}}"
```

(Only used before sourcing `.env`; after Task 3 Step 3, `.env` already has the correct value for the target.)

SSH `host` / `username` / `password` remain `${{ secrets.SERVER_* }}` — they resolve from the job `environment`.

- [ ] **Step 5: Sanity-check YAML locally**

```bash
# structural check — no colocate_121; has both Environment names and new compose env keys
grep -n 'colocate_121' .github/workflows/cd.yml && exit 1 || true
grep -n 'tencent-101' .github/workflows/cd.yml
grep -n 'aliyun-121' .github/workflows/cd.yml
grep -n 'PRODUCTION_COMPOSE_FILE_TENCENT_101' .github/workflows/cd.yml
grep -n 'PRODUCTION_COMPOSE_FILE_ALIYUN_121' .github/workflows/cd.yml
grep -n 'docker-compose.121.yml' .github/workflows/cd.yml && exit 1 || true
```

Expected: no `colocate_121` / `docker-compose.121.yml`; both targets and compose keys present.

- [ ] **Step 6: Commit**

```bash
git add .github/workflows/cd.yml
git commit -m "$(cat <<'EOF'
feat(cd): deploy via tencent-101 / aliyun-121 Environments

Auto CD targets tencent-101; dispatch chooses target; compose overlays
replace colocate_121 flag.

EOF
)"
```

---

### Task 4: Docs + env examples

**Files:**
- Modify: `docs/routing-registry.md`
- Modify: `docs/env/README.md`
- Modify: `docs/env/github-environments.example.env`
- Create: `docs/env/github-tencent-101.env`
- Create: `docs/env/github-aliyun-121.env`
- Modify: `docs/env/github-production.env` (pointer to new files)
- Modify: `README.md` (CD paragraph ~line 119)
- Modify: `docs/superpowers/specs/2026-11-11-dual-host-cd-design.md` Related line if still cites `docker-compose.121.yml`

**Interfaces:**
- Consumes: Environment names + COMPOSE_FILE strings from Tasks 1–3
- Produces: operator-facing migration notes (human still creates GitHub Environments)

- [ ] **Step 1: Update routing-registry dual-host section**

Replace ai-todo row wording so 101 no longer implies active ai-todo vhost on gateway 101 (DNS + disable overlay). Update `### 121 同机` to:

```markdown
### 双机（tencent-101 / aliyun-121）

- **tencent-101**：docs / drinkzen / party-helper。Compose：`docker-compose.yml` + `docker-compose.tencent-101.yml`（life/ai-todo conf → empty）。
- **aliyun-121**：life + ai-todo。Compose：`docker-compose.yml` + `docker-compose.aliyun-121.yml`（ai-todo → `:8082`；docs/drinkzen/party → empty）。
- life 必须先以 `compose.behind-gateway.yaml` 占 `127.0.0.1:8080`，再让 gateway 抢 `80/443`。
- CD：`main` CI 通过后只部署 `tencent-101`；`aliyun-121` 仅 `workflow_dispatch` + `target=aliyun-121`。
- 切流清单见 xiaolin-life 仓 `docs/GATEWAY-121-COLOCATE-CHECKLIST.md`。
```

Adjust the registration table Upstream/后端地址 cells for life and ai-todo to say aliyun-121 ownership (ai-todo conf on disk may still show K8s IP for non-121 use; note overlay on 121).

- [ ] **Step 2: Env docs — split examples**

`docs/env/github-tencent-101.env`:

```bash
# GitHub Environment: tencent-101 (L2) — category: platform · ADR-0009
# Copy to: ~/.config/xiaolinstar/xiaolin-gateway/github-tencent-101.env
# Real values must not be committed.

GITHUB_REPOSITORY=xiaolinstar/xiaolin-gateway
# If sync script supports --environment, pass tencent-101.

SERVER_HOST=101.34.78.2
SERVER_USER=ubuntu
SERVER_PASSWORD=change-me
```

`docs/env/github-aliyun-121.env`:

```bash
# GitHub Environment: aliyun-121 (L2)
# Copy to: ~/.config/xiaolinstar/xiaolin-gateway/github-aliyun-121.env

GITHUB_REPOSITORY=xiaolinstar/xiaolin-gateway

SERVER_HOST=<aliyun-121-public-ip>
SERVER_USER=ubuntu
SERVER_PASSWORD=change-me
```

Rewrite `docs/env/github-environments.example.env` as an index pointing at the two files; note **repo-level `SERVER_*` are deprecated** after Environments are populated.

Rewrite `docs/env/github-production.env` to a short pointer (no duplicate secrets list) → use `github-tencent-101.env` / `github-aliyun-121.env`.

Update `docs/env/README.md` L2 section: CD uses **Environments** `tencent-101` / `aliyun-121`, same secret names inside each.

- [ ] **Step 3: README CD blurb**

Replace the production CD sentence (~line 119) with:

```markdown
生产部署经 GitHub Actions：**`main` CI 通过后自动部署 Environment `tencent-101`**；阿里云 121 仅手动 `workflow_dispatch` 并选择 `target=aliyun-121`。双机职责与 compose 见 [docs/routing-registry.md](docs/routing-registry.md)；设计见 [docs/superpowers/specs/2026-11-11-dual-host-cd-design.md](docs/superpowers/specs/2026-11-11-dual-host-cd-design.md)。
```

Also add `xiaolin-life/` and compose overlay filenames to the project tree if that section is edited lightly — optional; do not large-rewrite README structure.

- [ ] **Step 4: Grep stale references**

```bash
rg -n 'docker-compose\.121\.yml|colocate_121|仓库级.*SERVER_' docs .github README.md || true
```

Expected: no remaining production references to deleted compose file or `colocate_121` (spec historical mention of delete is OK inside specs/plans).

- [ ] **Step 5: Commit**

```bash
git add docs/routing-registry.md docs/env/README.md docs/env/github-environments.example.env \
  docs/env/github-tencent-101.env docs/env/github-aliyun-121.env docs/env/github-production.env \
  README.md docs/superpowers/specs/2026-11-11-dual-host-cd-design.md
git commit -m "$(cat <<'EOF'
docs(cd): document tencent-101 / aliyun-121 Environments

EOF
)"
```

---

### Task 5: Human checklist (no code) — Environments + first deploy

**Files:** none in repo (operator steps; record outcome in PR description)

- [ ] **Step 1: Create GitHub Environments and secrets**

```bash
# Requires gh auth with repo admin
gh api repos/xiaolinstar/xiaolin-gateway/environments/tencent-101 -X PUT --input - <<'EOF'
{}
EOF
gh api repos/xiaolinstar/xiaolin-gateway/environments/aliyun-121 -X PUT --input - <<'EOF'
{}
EOF

# Set secrets per environment (use real values from private local env files)
gh secret set SERVER_HOST --env tencent-101 --body '101.34.78.2'
gh secret set SERVER_USER --env tencent-101 --body 'ubuntu'
gh secret set SERVER_PASSWORD --env tencent-101 < <(printf '%s' "$TENCENT_101_PASSWORD")

gh secret set SERVER_HOST --env aliyun-121 --body "$ALIYUN_121_HOST"
gh secret set SERVER_USER --env aliyun-121 --body 'ubuntu'
gh secret set SERVER_PASSWORD --env aliyun-121 < <(printf '%s' "$ALIYUN_121_PASSWORD")
```

- [ ] **Step 2: After merge — verify auto CD hits 101 only**

On 101 after CD:

```bash
docker exec nginx-gateway nginx -T 2>/dev/null | grep -E 'server_name.*(xiaolin\.fun|xingxiaolin\.cn)' && echo FAIL || echo OK_no_life_aitodo
docker exec nginx-gateway nginx -t
```

- [ ] **Step 3: Manual dispatch aliyun-121 when host ready**

GitHub → Actions → CD → Run workflow → `target=aliyun-121`.

On 121:

```bash
docker exec nginx-gateway nginx -T 2>/dev/null | grep -F 'host.docker.internal:8082'
docker exec nginx-gateway nginx -T 2>/dev/null | grep -E 'server_name.*(wodi\.games|drinkzen)' && echo FAIL || echo OK_disabled
```

- [ ] **Step 4: After both Environments work, delete repo-level `SERVER_*` Secrets** (Settings → Secrets) so only Environment secrets remain.

---

## Spec coverage (self-review)

| Spec requirement | Task |
|------------------|------|
| empty.conf + bind disable | Task 1 |
| tencent-101 / aliyun-121 compose + delete 121.yml | Task 1 |
| COMPOSE_FILE strings | Task 1–3 |
| CD Environments + target input + remove colocate_121 | Task 3 |
| Auto only tencent-101 | Task 3 |
| Party precheck 101-only; cert ensure 121 | Task 3 |
| concurrency per target | Task 3 |
| CI overlay nginx -t | Task 2 |
| routing-registry / env docs / README | Task 4 |
| Human Environment migration | Task 5 |
| Non-goals (gateway.conf, DNS, auto-121) | not implemented ✓ |

## Placeholder scan

No TBD/TODO left in task steps.
