# xiaolin-gateway 环境变量

真源分层见 [dev-standards env-management](https://github.com/xiaolinstar/dev-standards/blob/main/playbook/env-management.md)。

## 本仓库约定

| 层 | 路径 |
|----|------|
| L0 模板 | `.env.example`、`.env.production.example`、`.env.local.example` |
| L2 CI/CD | GitHub Environments `tencent-101` / `aliyun-121`：Secrets `SERVER_*`；可选 Variable `ENABLE_OBSERVABILITY`（见 [github-environments.example.env](github-environments.example.env)） |
| L3 运行时（VPS / 本地） | `.env` → `.env.production`（生产）或 `.env.local`（本地）；CD 会按目标写入 `COMPOSE_FILE` |

**不要**使用已废弃的 `env/production.env` 或扁平 `github-*.env` 真源；CD 只加载根目录 `.env*`。

## 加载顺序

```text
.env  →  .env.production   # 生产 CD
.env  →  .env.local       # 本地开发
```

Compose 入口：直接使用 `docker compose --env-file .env --env-file .env.production`（或 `.env.local`）。

## 键名校验

```bash
# 仓库模板自洽
~/AgentProjects/dev-standards/scripts/sync.sh env check --project .

# VPS 部署前（CD 已集成）
bash ~/AgentProjects/dev-standards/scripts/env/check-env-keys.sh \
  --project . --strict --runtime .env --runtime .env.production --warn-extra
```

## Observability（按 Environment）

| Environment | 默认 `ENABLE_OBSERVABILITY` | 默认 `COMPOSE_FILE` |
|-------------|------------------------------|---------------------|
| `tencent-101` | `true` | `…tencent-101.yml:observability-compose.yml` |
| `aliyun-121` | `false`（省资源） | `…aliyun-121.yml`（无监控栈） |

在对应 Environment 设置 Variable `ENABLE_OBSERVABILITY=true` 可在 121 打开监控；`false` 可在 101 关闭。

## GitHub L2 同步（人类终端；Agent 禁区）

Environments：`tencent-101`（自动 CD 默认）、`aliyun-121`（仅手动）。Secrets 同名：`SERVER_HOST` / `SERVER_USER` / `SERVER_PASSWORD`。仓库级 `SERVER_*` 与旧 Environment `production` 已废弃并移除。

```bash
~/AgentProjects/dev-standards/scripts/sync.sh env init-github-env \
  --project xiaolin-gateway --environment tencent-101
~/AgentProjects/dev-standards/scripts/sync.sh env init-github-env \
  --project xiaolin-gateway --environment aliyun-121
# 人工编辑 ~/.config/xiaolinstar/xiaolin-gateway/github/<env>/secrets.env 后：
~/AgentProjects/dev-standards/scripts/sync.sh env sync-github \
  --project xiaolin-gateway --environment tencent-101 --dry-run
~/AgentProjects/dev-standards/scripts/sync.sh env sync-github \
  --project xiaolin-gateway --environment tencent-101
# 对 aliyun-121 重复
```

## 外部探活（/healthz）

本仓维护全站 uptime workflow（`.github/workflows/uptime.yml`）。

| 文档 | 用途 |
|------|------|
| [healthz-probe-standard.md](../healthz-probe-standard.md) | 端点约定与注册表 |
| [routing-registry.md](../routing-registry.md) | 域名 / upstream / 探活 URL |

网关自身：`app/gateway.conf` 提供 `GET /healthz`（204）。

## Agent 禁区

禁止 Agent **读或写** `.env*`（非 example）与 `~/.config/xiaolinstar/**`；禁止代跑 `sync-github` / `init-github-env`。只改 `docs/env/**/*.example` 与本 README。

注册表：[env-registry.yaml](https://github.com/xiaolinstar/dev-standards/blob/main/playbook/env-registry.yaml) §xiaolin-gateway · [ADR-0009](https://github.com/xiaolinstar/dev-standards/blob/main/playbook/adr/0009-l2-github-env-by-category.md)。

## Phase 1 迁移

见 [phase1-checklist.md](phase1-checklist.md)。
