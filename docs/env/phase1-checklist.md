# Phase 1 · xiaolin-gateway 环境迁移

> 平台优先。完成本清单后再做内容站 / 应用 env 迁移；**probe 扩展仍暂停**。
> 总 runbook：[dev-standards env-migration-runbook](https://github.com/xiaolinstar/dev-standards/blob/main/playbook/env-migration-runbook.md)

## 目标

| 检查项 | 完成标准 |
|--------|----------|
| VPS 运行时 | 存在 `.env` + `.env.production`，无 `env/production.env` |
| CD | `check-env-keys.sh` 通过；使用 `docker compose --env-file` 部署 |
| 本地备份 | `~/.config/xiaolinstar/xiaolin-gateway/production.env` 已填（人工） |
| dev-standards | `sync.sh env check --project . --strict` 通过（本地有 runtime 时） |

## Step 1 · VPS（gateway 主机 `101.34.78.2`，用户 `ubuntu`）

```bash
cd ~/AgentProjects/xiaolin-gateway
git pull

# 直接从模板创建并编辑
cp .env.example .env
cp .env.production.example .env.production
chmod 600 .env .env.production
vim .env .env.production   # 保留现有 Grafana 密码等真实值

bash ~/AgentProjects/dev-standards/scripts/env/check-env-keys.sh --project . --strict --runtime .env --runtime .env.production --warn-extra
docker compose --env-file .env --env-file .env.production config   # 可选：确认 compose 解析
```

确认 `~/AgentProjects/dev-standards` 存在（CD verify 依赖）：

```bash
test -d ~/AgentProjects/dev-standards || git clone git@github.com:xiaolinstar/dev-standards.git ~/AgentProjects/dev-standards
```

## Step 2 · 本地集中备份（本机，人工）

```bash
# 在本机执行
scp ubuntu@101.34.78.2:~/AgentProjects/xiaolin-gateway/.env \
    ~/.config/xiaolinstar/xiaolin-gateway/local.env
scp ubuntu@101.34.78.2:~/AgentProjects/xiaolin-gateway/.env.production \
    ~/.config/xiaolinstar/xiaolin-gateway/production.env
chmod 600 ~/.config/xiaolinstar/xiaolin-gateway/*.env

cd ~/AgentProjects/dev-standards
./scripts/sync.sh env check --project ~/AgentProjects/xiaolin-gateway --local --env local --strict
```

## Step 3 · 本地开发 runtime（可选）

```bash
cd ~/AgentProjects/xiaolin-gateway
cp .env.example .env
cp .env.local.example .env.local
chmod 600 .env .env.local
# 编辑后：
~/AgentProjects/dev-standards/scripts/sync.sh env check --project . --strict
```

## Step 4 · 触发 CD 验证

推送 `main` 或手动在 VPS：

```bash
docker compose --env-file .env --env-file .env.production pull
docker compose --env-file .env --env-file .env.production up -d --remove-orphans
```

## Step 5 · 更新进度

在 dev-standards `playbook/env-migration-status.yaml` 将 `xiaolin-gateway.local_config` / `vps_runtime` 标为 `done`。

## 故障排查

| 现象 | 处理 |
|------|------|
| `missing runtime file → .env` | VPS 未创建 `.env` |
| verify 缺键 | 对照 `.env.example` / `.env.production.example` 补键 |
| `dev-standards check script not found` | VPS clone dev-standards 到 `~/AgentProjects/dev-standards` |
| legacy 已迁移但仍报错 | 删除或归档 `env/production.env.migrated.*` 即可 |
