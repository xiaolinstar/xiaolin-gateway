# xiaolin-gateway 环境变量

真源分层见 [dev-standards env-management](https://github.com/xiaolinstar/dev-standards/blob/main/playbook/env-management.md)。

## 本仓库约定

| 层 | 路径 |
|----|------|
| L0 模板 | `.env.example`、`.env.production.example`、`.env.local.example` |
| L3 运行时（VPS / 本地） | `.env` → `.env.production`（生产）或 `.env.local`（本地） |
| L3 集中备份（可选） | `~/.config/xiaolinstar/xiaolin-gateway/production.env` |

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

## Agent 禁区

禁止 Agent 修改 `.env`、`.env.production` 与 `~/.config/xiaolinstar/**`；只改 `*.example` 并让人工/sync 更新 L3。

注册表条目：[env-registry.yaml](https://github.com/xiaolinstar/dev-standards/blob/main/playbook/env-registry.yaml) §xiaolin-gateway。

## Phase 1 迁移

见 [phase1-checklist.md](phase1-checklist.md)（VPS legacy → `.env*`、集中备份、CD 验证）。
