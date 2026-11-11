# Design: Dual-host CD (tencent-101 / aliyun-121)

Date: 2026-11-11  
Status: approved (conversation)  
Related: `docs/routing-registry.md`, `.github/workflows/cd.yml`, `docker-compose.tencent-101.yml`, `docker-compose.aliyun-121.yml`

## Goal

Run nginx-gateway on two servers with one CD workflow:

- **tencent-101** — existing VPS: docs / drinkzen / party-helper
- **aliyun-121** — new ECS: xiaolin-life + ai-todo (same-host upstreams)

Unused vhosts on each host are disabled by bind-mounting an empty conf so those certificate directories are not required. DNS cutover stays manual (existing checklists).

## Topology

```text
Internet
  ├─ *.wodi.games / drinkzen.* / xiaolinstar.cn  → DNS → tencent-101
  └─ xiaolin.fun / xingxiaolin.cn               → DNS → aliyun-121
```

| Host | GitHub Environment | Active vhosts | Cert dirs required |
|------|--------------------|---------------|--------------------|
| Tencent 101 | `tencent-101` | docs, drinkzen, party-helper | those three only |
| Aliyun 121 | `aliyun-121` | life, ai-todo (`:8082` overlay) | those two only |

## Compose

### Shared empty conf

- Add `app/_disabled/empty.conf` — comments only (valid nginx include, no `server` / `upstream`).
- `gateway.conf` keeps `include /etc/nginx/app/*/*.conf`; disabled paths are overwritten via compose bind mounts so the container never sees the real project conf.

### Overlays

| File | Role |
|------|------|
| `docker-compose.tencent-101.yml` | Bind `xiaolin-life.conf` and `ai-todo.conf` → `app/_disabled/empty.conf` |
| `docker-compose.aliyun-121.yml` | Replace current `docker-compose.121.yml`: mount `ai-todo.121.overlay` over `ai-todo.conf`; bind docs / drinkzen / party-helper `*.conf` → `empty.conf` |

Base `docker-compose.yml` keeps `extra_hosts: host-gateway` and cert volume mounts. Unused cert dirs may be empty; corresponding confs are not loaded, so `nginx -t` does not need those files.

### COMPOSE_FILE

| Target | Value |
|--------|--------|
| tencent-101 | `docker-compose.yml:docker-compose.tencent-101.yml:observability-compose.yml` |
| aliyun-121 | `docker-compose.yml:docker-compose.aliyun-121.yml:observability-compose.yml` |

CD continues to write `COMPOSE_FILE` into `.env` and `.env.production` via `ensure_env_key` (same pattern as today).

Rename: replace `docker-compose.121.yml` with `docker-compose.aliyun-121.yml` as the only production overlay. Leave `docker-compose.121.yml` as a short comment-only stub that points humans/scripts to the new filename (no compose services), or delete it and update all references in the same PR — prefer **delete + reference update** to avoid accidental `-f docker-compose.121.yml` with empty content.

## CD workflow (single file)

File: `.github/workflows/cd.yml`

### Triggers

| Event | Deploy target |
|-------|----------------|
| `workflow_run` CI success on `main` | **tencent-101 only** |
| `workflow_dispatch` | required input `target`: `tencent-101` \| `aliyun-121` |

### Inputs

- **Add** `target` (choice, required on dispatch).
- **Remove** `colocate_121` (implied by `target=aliyun-121`).
- **Keep** `skip_party_helper_precheck` — meaningful only for `tencent-101`; ignored / step skipped on `aliyun-121`.

### Job wiring

- `environment: <resolved target>` (auto path hardcodes `tencent-101`).
- Secrets (same names per environment): `SERVER_HOST`, `SERVER_USER`, `SERVER_PASSWORD`.
- `concurrency.group: production-deploy-${{ resolved_target }}` so 101 and 121 do not block each other.
- All SSH steps use environment secrets (no repo-level `SERVER_*` after migration).

### Steps by target

| Step | tencent-101 | aliyun-121 |
|------|-------------|------------|
| Party Helper H5 / cert precheck | default on (dispatch can skip) | skip |
| Ensure life + ai-todo certs (placeholder if missing) | skip | keep (real certs before DNS cutover) |
| Set `COMPOSE_FILE` | 101 string | 121 string |
| `git pull` / compose pull / up / `nginx -t` / reload / prune | unchanged pattern | unchanged pattern |

### Secrets migration

- Create GitHub Environments `tencent-101` and `aliyun-121`; move credentials from repo-level Secrets.
- Document deprecation of repository-level `SERVER_HOST` / `SERVER_USER` / `SERVER_PASSWORD`; delete after both environments work.
- Update `docs/env/README.md`, `docs/env/github-environments.example.env`, and split examples into `github-tencent-101.env` / `github-aliyun-121.env` (or equivalent clearly named files). Update `docs/env/github-production.env` to point at the new layout.

## Docs

- `docs/routing-registry.md` — dual-host ownership + compose overlay names; 121 section uses `docker-compose.aliyun-121.yml`.
- Root `README.md` — short note: auto CD → 101; manual dispatch with `target` for 121.
- Optional pointer to this design under `docs/superpowers/specs/`.

## One-time ops (human)

Per host:

1. Create Environment + Secrets (or sync script).
2. Clone / pull gateway on the server.
3. Place only the certs that host needs.
4. First `workflow_dispatch` with the matching `target` (CD writes `COMPOSE_FILE`).

Business bring-up (life `compose.behind-gateway.yaml`, ai-todo `:8082`) and DNS cutover remain outside this design (existing life checklist).

## Non-goals

- Changing `gateway.conf` include strategy / splitting `app/` trees by profile
- Business-repo CD for life / ai-todo
- Automatic DNS cutover
- Auto-deploy to `aliyun-121` on every `main` merge
- Splitting or dropping `observability-compose.yml` per host (both keep it for now)

## Acceptance

1. After CI green, CD SSHs only to tencent-101; `nginx -T` on 101 has no `xiaolin.fun` / `xingxiaolin.cn` server blocks.
2. Manual `target=aliyun-121` succeeds; `nginx -T` shows life + ai-todo (plus gateway self); ai-todo upstream is `host.docker.internal:8082`; no drinkzen / party / docs server blocks.
3. `nginx -t` passes on 101 without life/ai-todo cert files, and on 121 without drinkzen/party/docs cert files.

## Implementation note

Prefer minimal diff: compose overlays + empty conf + CD/env docs. Do not refactor unrelated vhosts.
