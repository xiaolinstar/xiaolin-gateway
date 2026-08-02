# 子系统健康检查规范（/healthz）

本规范定义经小林网关对外暴露的子系统，应如何实现健康检查端点，以及如何被 GitHub Actions 外部探活使用。

**真源：** 注册表与 `uptime.yml` 以 [routing-registry.md](./routing-registry.md) 与本文件为准；各业务仓 `docs/env/README.md` 只链本文，不重复维护探活 URL 列表。

## 目标

- 所有子系统使用**同一路径** `GET /healthz` 表示存活（liveness）。
- 外部探活验证完整链路：DNS → TLS → Nginx → 后端进程。
- 与网关自身约定一致（见 `app/gateway.conf` 中的 `/healthz`）。

## 端点约定

| 项 | 要求 |
|----|------|
| 路径 | `GET /healthz`（固定，不要用 `/health`、`/ping` 等变体作**外部**探活） |
| HTTP 状态 | `200` 或 `204` |
| 响应体 | 尽量小（如 `ok` 或空）；勿返回大 JSON/HTML |
| 鉴权 | 不要求登录或 Token |
| 副作用 | 不写库、不触发业务逻辑；仅表示进程可用 |
| 方法 | 仅保证 `GET`；`HEAD` 可选支持 |

## 实现方式（按类型）

| 类型 | 实现 | 示例 |
|------|------|------|
| 内容站 nginx | `location = /healthz { return 204; }` | xiaolin-docs、xiaolin-life |
| API 服务 | 轻量 handler，不查 DB | party-helper、drinkzen |
| API 深度检查 | **不用** `/healthz`；保留业务路径 | ai-todo：`/v1/health`、`/v1/health/db` 供 CD/monitor |

```text
GET /healthz → 200 OK
Body: ok
```

## 外部探活（uptime.yml）

`.github/workflows/uptime.yml` 从 GitHub Runner 每 15 分钟请求各域名，并使用 `curl --fail`（非 2xx 视为失败）。同时检查 TLS 证书是否在 14 天内过期。

**统一 URL 格式：**

```text
https://<对外域名>/healthz
```

修改探活目标时，只改 workflow 中 `matrix.target` 的 `url` 字段；`host` 仍用于证书 SNI 检查。

## 注册表（2026-06 已全部切换）

| 子系统 | 对外域名 | uptime 探测 | 后端实现 | 备注 |
|--------|----------|-------------|----------|------|
| xiaolinstar | www.xiaolinstar.cn | `/healthz` | nginx 204 | 内容站 |
| xiaolin-life | www.xiaolin.fun | `/healthz` | nginx 204 | `volumes/website/default.conf` |
| ai-todo | www.xingxiaolin.cn | `/healthz` | 200 文本 `ok` | CD 仍用 `/v1/health*` |
| ai-todo-staging | www.staging.xingxiaolin.cn | `/healthz` | 同上 | staging VPS |
| party-helper-root | www.wodi.games | `/healthz` | 301 到 API | Uptime 跟随跳转 |
| party-helper-admin | admin.wodi.games | `/healthz` | 200 | NodePort `30024` |
| party-helper-api | api.wodi.games | `/healthz` | 200 JSON | NodePort `30021` |
| drinkzen | drinkzen.cn | `/healthz` | 200 JSON | 当前与 API 共用服务 |
| drinkzen-www | www.drinkzen.cn | `/healthz` | 301 到根域名 | Uptime 跟随跳转 |
| drinkzen-api | api.drinkzen.cn | `/healthz` | 200 JSON | NodePort `31011` |
| drinkzen-admin | admin.drinkzen.cn | `/healthz` | 200 | NodePort `31012` |

合并代码后需对应用/内容仓执行 **CD**，公网 `/healthz` 才会生效；gateway `uptime.yml` 已统一探测 `/healthz`。

## 新项目接入清单

1. 后端或容器 nginx 实现 `GET /healthz`（2xx）。
2. 在 [routing-registry.md](./routing-registry.md) 登记一行。
3. `app/<project>/` 添加 Nginx vhost（`location /` 反代即可，无需在网关层 stub `/healthz`）。
4. 在 `uptime.yml` 的 `matrix.target` 增加一项，`url` 为 `https://<域名>/healthz`。
5. 业务仓 `docs/env/README.md` 增加「健康检查」段并链本文。

## 自测命令

```bash
curl -fsS -o /dev/null -w "status=%{http_code}\n" "https://<域名>/healthz"
```

`-f`（`--fail`）与 uptime workflow 行为一致：非 2xx 退出非零。
