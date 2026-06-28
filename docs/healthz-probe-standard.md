# 子系统健康检查规范（/healthz）

本规范定义经小林网关对外暴露的子系统，应如何实现健康检查端点，以及如何被 GitHub Actions 外部探活使用。

## 目标

- 所有子系统使用**同一路径** `GET /healthz` 表示存活（liveness）。
- 外部探活验证完整链路：DNS → TLS → Nginx → 后端进程。
- 与网关自身约定一致（见 `app/gateway.conf` 中的 `/healthz`）。

## 端点约定

| 项 | 要求 |
|----|------|
| 路径 | `GET /healthz`（固定，不要用 `/health`、`/ping` 等变体） |
| HTTP 状态 | `200` 或 `204` |
| 响应体 | 尽量小（如 `ok` 或空）；勿返回大 JSON/HTML |
| 鉴权 | 不要求登录或 Token |
| 副作用 | 不写库、不触发业务逻辑；仅表示进程及关键依赖可用 |
| 方法 | 仅保证 `GET`；`HEAD` 可选支持 |

## 后端实现示例

```text
GET /healthz → 200 OK
Body: ok
```

纯 API 服务无需在 `/` 提供页面；探活统一走 `/healthz`。

## 外部探活（uptime.yml）

`.github/workflows/uptime.yml` 从 GitHub Runner 每 15 分钟请求各域名，并使用 `curl --fail`（非 2xx 视为失败）。同时检查 TLS 证书是否在 14 天内过期。

**目标 URL 格式：**

```text
https://<对外域名>/healthz
```

修改探活目标时，只改 workflow 中 `matrix.target` 的 `url` 字段；`host` 仍用于证书 SNI 检查。

## 迁移进度

逐步将各子系统从探测 `/` 迁移到 `/healthz`。后端未就绪前，workflow 仍探测 `/`，避免误报。

| 子系统 | 对外域名 | workflow 探测路径 | 后端 /healthz | 备注 |
|--------|----------|-------------------|---------------|------|
| xiaolinstar | www.xiaolinstar.cn | **`/healthz`** | 已支持（204） | 2026-06 已切换 |
| xiaolin-life | www.xiaolin.fun | **`/healthz`** | 已支持（204，nginx stub） | 2026-06 已切换 |
| ai-todo | www.xingxiaolin.cn | **`/healthz`** | 已支持（200，`ok`） | 需 API CD 后生效 |
| ai-todo-staging | www.staging.xingxiaolin.cn | **`/healthz`** | 已支持（200，`ok`） | 需 API CD 后生效 |
| drink-budget | www.wodi.games | **`/healthz`** | 已支持（200） | 需 API CD 后生效 |
| party-helper | api.wodi.games | **`/healthz`** | 已支持（200） | 2026-06 已切换 |

某子系统后端实现 `/healthz` 并通过自测后：

1. 在本表更新「后端 /healthz」与「workflow 探测路径」。
2. 修改 `.github/workflows/uptime.yml` 中对应 `url` 为 `…/healthz`。
3. 合并后观察下一次 Uptime Probe workflow 是否通过。

## 新项目接入清单

1. 后端实现 `GET /healthz`（2xx）。
2. 在 `app/<project>/` 添加 Nginx vhost（`location /` 反代即可，无需在网关层单独 stub `/healthz`）。
3. 在 `uptime.yml` 的 `matrix.target` 增加一项，`url` 使用 `https://<域名>/healthz`。
4. 更新本文件迁移进度表。

## 自测命令

```bash
curl -fsS -o /dev/null -w "status=%{http_code}\n" "https://<域名>/healthz"
```

`-f`（`--fail`）与 uptime workflow 行为一致：非 2xx 退出非零。
