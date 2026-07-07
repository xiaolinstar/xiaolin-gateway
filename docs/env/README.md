# xiaolin-gateway 环境变量

真源分层见 [dev-standards env-management](https://github.com/xiaolinstar/dev-standards/blob/main/playbook/env-management.md)。

## 本仓库约定

| 层 | 路径 |
|----|------|
| L0 模板 | `.env.example`、`.env.production.example`、`.env.local.example` |
| L2 CI/CD | 仓库 **Secrets** `SERVER_*`；清单见 `docs/env/github-environments.example.env` |
| L3 运行时（VPS / 本地） | `.env` → `.env.production`（生产）或 `.env.local`（本地） |
| L3 集中备份（可选） | `~/.config/xiaolinstar/xiaolin-gateway/production.env` |
| L2 本地清单（可选） | `~/.config/xiaolinstar/xiaolin-gateway/github-production.env` |

**不要**使用已废弃的 `env/production.env` 路径；CD 只加载根目录 `.env*`。

## 加载顺序

```text
.env  →  .env.production   # 生产 CD
.env  →  .env.local       # 本地开发
```

Compose 入口：`scripts/cd/with-runtime-env.sh`（先 source 再 `docker compose`）。

## 键名校验

```bash
# 本地 / CI：模板自洽；缺 .env 仅 warn
~/AgentProjects/dev-standards/scripts/sync.sh env check --project .

# VPS 部署前（CD 已集成）：缺键则 fail
bash scripts/cd/verify-runtime-env.sh

# 对比 ~/.config/xiaolinstar
~/AgentProjects/dev-standards/scripts/sync.sh env check \
  --project . --local production --strict
```

## GitHub L2 同步（party-helper 模式）

本仓 CD 使用**仓库级** Secrets（`SERVER_HOST` / `SERVER_USER` / `SERVER_PASSWORD`），不是 GitHub Environment。

```bash
mkdir -p ~/.config/xiaolinstar/xiaolin-gateway
cp docs/env/github-production.env ~/.config/xiaolinstar/xiaolin-gateway/github-production.env
chmod 600 ~/.config/xiaolinstar/xiaolin-gateway/github-production.env
# 编辑真实值后：
bash scripts/cd/sync-github-env.sh --dry-run
bash scripts/cd/sync-github-env.sh
```

也可从 dev-standards 调用：`sync.sh env sync-github --project xiaolin-gateway --dry-run`

## 外部探活（/healthz）

本仓维护 **全站 uptime 探活** workflow（`.github/workflows/uptime.yml`），统一探测各子系统 `https://<域名>/healthz`。

| 文档 | 用途 |
|------|------|
| [healthz-probe-standard.md](../healthz-probe-standard.md) | 端点约定与注册表（真源） |
| [routing-registry.md](../routing-registry.md) | 域名 / upstream / 探活 URL |

网关自身：`app/gateway.conf` 提供 `GET /healthz`（204）。

## Agent 禁区

禁止 Agent 修改 `.env`、`.env.production` 与 `~/.config/xiaolinstar/**`；只改 `*.example` 并让人工/sync 更新 L3。

注册表条目：[env-registry.yaml](https://github.com/xiaolinstar/dev-standards/blob/main/playbook/env-registry.yaml) §xiaolin-gateway。  
L2 标准：[ADR-0009](https://github.com/xiaolinstar/dev-standards/blob/main/playbook/adr/0009-l2-github-env-by-category.md)（category: **platform**）。

## Phase 1 迁移

见 [phase1-checklist.md](phase1-checklist.md)（VPS legacy → `.env*`、集中备份、CD 验证）。
