# 路由注册表（真源）

> 公网入口与 upstream 的**唯一真相来源**。各业务仓库 README 只链本文，不重复维护 Nginx 细节。
> 变更 vhost 时：**先改本文 → 改 `app/<project>/` conf → 改 `uptime.yml`（若域名/探活变）→ CI `nginx -t` → CD**。
> 后端端口的归属和分配规则见 [backend-exposure-standard.md](./backend-exposure-standard.md)。

## 拓扑

```text
Internet → nginx-gateway (80/443)
              ├─ TLS 终结 + 反代 → 各 VPS 端口上的业务/内容容器
              └─ 网关自身 GET /healthz（gateway.conf）
```

当前后端均指向固定 VPS IP + 端口（见下表）。换机或改端口时同步更新 **upstream conf** 与 **负责仓库的 deploy 文档**。

## 注册表

| ID | 类 | 对外域名 | Gateway conf | Upstream | 后端地址 | 负责仓库 | Healthz |
|----|-----|----------|--------------|----------|----------|----------|---------|
| docs | ③ 内容 | `www.xiaolinstar.cn` | `app/xiaolin-docs/xiaolin-docs.conf` | `xiaolin-service` | `124.222.98.227:8080` | [xiaolin-docs](https://github.com/xiaolinstar/xiaolin-docs) | ✅ `GET /healthz` |
| docs-com | ③ 内容 | `www.xiaolinstar.com` | 同上（301 → .cn） | — | — | xiaolin-docs | — |
| life | ③ 内容 | `www.xiaolin.fun` | `app/xiaolin-life/xiaolin-life.conf` | `xiaolin-life` | `124.222.98.227:8081` | [xiaolin-life](https://github.com/xiaolinstar/xiaolin-life) | ✅ `GET /healthz` |
| ai-todo | ② 应用 | `www.xingxiaolin.cn` | `app/ai-todo/ai-todo.conf` | `ai-todo-api` | `111.229.38.208:30082` | [ai-todo](https://github.com/xiaolinstar/ai-todo) | ✅ `GET /healthz`（`/v1/health` 仍用于深度检查） |
| ai-todo-stg | ② 应用 | `www.staging.xingxiaolin.cn` | 同上 | `ai-todo-api-staging` | `121.199.175.147:8083` | ai-todo | ✅ 同上 |
| drink | ② 应用 | `www.wodi.games` | `app/drink-budget/drink-budget.conf` | `drink-budget-api` | `111.229.38.208:8020` | [drink-budget](https://github.com/xiaolinstar/drink-budget) | ✅ `GET /healthz` |
| drinkzen | ② 应用 | `drinkzen.cn` | `app/drinkzen/drinkzen.conf` | `drinkzen-api`（过渡） | `111.229.38.208:31011` | [drinkzen](https://github.com/xiaolinstar/drinkzen) | ✅ `GET /healthz` |
| drinkzen-api | ② 应用 | `api.drinkzen.cn` | 同上 | `drinkzen-api` | `111.229.38.208:31011` | drinkzen | ✅ `GET /healthz` |
| drinkzen-admin | ② 应用 | `admin.drinkzen.cn` | 同上 | `drinkzen-admin` | `111.229.38.208:31012` | drinkzen | ✅ `GET /healthz` |
| party | ② 应用 | `api.wodi.games` | `app/party-helper/party-helper.conf` | `party-helper-api` | `111.229.38.208:30021` | [party-helper](https://github.com/xiaolinstar/party-helper) | ✅ `GET /healthz` |

### drinkzen Web 拆分计划

最终状态中，`drinkzen.cn` 与 `api.drinkzen.cn` 暂时共用 `drinkzen-api:31011`。独立 Web Service 部署后再拆分用户入口：

| 服务角色 | Upstream | 暴露端点 | 切换条件 |
|----------|----------|----------|----------|
| 用户端 Web | `drinkzen-web` | 目标 NodePort `31010` | Service 部署且 `GET /healthz` 可用 |
| 业务 API | `drinkzen-api` | NodePort `31011` | 固定生产契约 |
| 管理后台 | `drinkzen-admin` | NodePort `31012` | 固定生产契约 |

Web Service 就绪后，仅将 `drinkzen.cn` 的 `proxy_pass` 改为 `http://drinkzen-web`，API 域名和管理后台无需改动。`www.drinkzen.cn` 待单域名证书签发后单独配置 301 跳转。

### 证书目录（git 忽略，服务器手动上传）

| 项目 | 宿主机路径 | 文件名模式 |
|------|------------|------------|
| xiaolin-docs | `app/xiaolin-docs/cert/` | `xiaolinstar.cn_*`、`.com/` 子目录 |
| xiaolin-life | `app/xiaolin-life/cert/` | `xiaolin.fun_*` |
| ai-todo | `app/ai-todo/cert/` | `www.xingxiaolin.cn.pem`、`www.staging.xingxiaolin.cn.pem` |
| drink-budget | `app/drink-budget/cert/` | `wodi.games_*` |
| drinkzen | `app/drinkzen/cert/` | `drinkzen.cn_*`、`api.drinkzen.cn_*`、`admin.drinkzen.cn_*` |
| party-helper | `app/party-helper/cert/` | `api.wodi.games_*` |

## 外部探活（uptime.yml）

规范：[healthz-probe-standard.md](./healthz-probe-standard.md) · workflow：`.github/workflows/uptime.yml`

| ID | 探活 URL |
|----|----------|
| xiaolinstar | `https://www.xiaolinstar.cn/healthz` |
| xiaolin-life | `https://www.xiaolin.fun/healthz` |
| ai-todo | `https://www.xingxiaolin.cn/healthz` |
| ai-todo-staging | `https://www.staging.xingxiaolin.cn/healthz` |
| drink-budget | `https://www.wodi.games/healthz` |
| party-helper | `https://api.wodi.games/healthz` |

drinkzen 的三个公网探测将在 DNS 切换并完成预检后加入 workflow。

## 新项目接入

1. 在负责仓库完成部署（固定 listen 端口或文档说明）。
2. 本文新增一行注册表。
3. `app/<project>/` 添加 vhost + `docker-compose.yml` 证书 volume。
4. 后端实现 `GET /healthz`。
5. `uptime.yml` 增加 matrix 项。
6. 更新 [healthz-probe-standard.md](./healthz-probe-standard.md) 注册表。

## 维护责任

| 变更类型 | 改哪里 |
|----------|--------|
| 换域名 / 证书 | ① gateway（本文 + conf + cert 目录） |
| API 发版 | ② 业务仓 CD；gateway 不动 |
| 文档/内容发版 | ③ 内容仓 CD；gateway 不动 |
| 换 VPS IP 或端口 | ① gateway upstream + ②/③ deploy 文档 |
