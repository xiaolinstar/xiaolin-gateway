# 后端暴露契约

## 设计结论

111 生产 k3s 对 101 Nginx 网关统一使用专用、显式固定的 NodePort。业务内部 Service 保持 ClusterIP，生产业务不使用 k3s LoadBalancer 直接占用宿主机端口。

```text
公网域名 -> 101 网关 -> 111:固定 NodePort -> Gateway Service -> Pod
```

101 已经负责 TLS、域名路由和公网入口，因此 111 不再为每个业务叠加一层 LoadBalancer。若未来把网关迁入同一 k3s 集群，再统一改为 ClusterIP + Service DNS。

## 暴露契约字段

每个接入网关的服务必须声明：

| 字段 | 要求 |
|------|------|
| 项目与环境 | 项目名、production/staging |
| 服务角色 | `web`、`api`、`admin` 等 |
| 暴露端点 | 网关可访问的固定 `IP:port` |
| 暴露实现 | 111 k3s 生产固定为专用 NodePort |
| 健康检查 | 无鉴权的 `GET /healthz`，返回 2xx |
| 网络边界 | 安全组/防火墙仅允许网关来源访问 |
| 负责仓库 | Service 清单和发布流程的真源 |

网关不得根据容器端口、Service `port` 或端口命名习惯猜测暴露端点。变更前必须同时检查业务仓渲染后的生产清单，并从网关网络方向执行 HTTP 探测。

## 目标端口分配

生产使用 `31000-31999`，staging 使用 `32000-32767`。每个项目保留连续 10 个端口，角色偏移固定为：Web `+0`、API `+1`、Admin `+2`。

| 项目 | 生产端口块 | Web | API | Admin |
|------|------------|-----|-----|-------|
| drinkzen | `31010-31019` | `31010` | `31011` | `31012` |
| party-helper | `31020-31029` | `31020` | `31021` | `31022` |
| ai-todo | `31030-31039` | `31030` | `31031` | `31032` |

未部署的角色只保留编号，不创建 Service 或开放安全组端口。

## 当前迁移状态

| 项目 | 角色 | 当前端点 | 目标 NodePort | 状态 |
|------|------|----------|----------------|------|
| xiaolin-docs | web | `124.222.98.227:8080` | legacy host port | 在用 |
| xiaolin-life | web | `124.222.98.227:8081` | legacy host port | 在用 |
| ai-todo | api/web | `111.229.38.208:30082` | `31031` | 后续独立迁移 |
| drinkzen | api/web | `111.229.38.208:8020` | `31011` | 本轮优先迁移 |
| drinkzen | admin | `111.229.38.208:8030` | `31012` | 本轮优先迁移 |
| party-helper | api | `111.229.38.208:30021` | `31021` | 后续独立迁移 |
| party-helper | admin | `111.229.38.208:30024` | `31022` | 接入公网前迁移 |
| ai-todo staging | api/web | `121.199.175.147:8083` | legacy host port | 在用 |

124 上的 legacy 内容服务不纳入本轮 k3s NodePort 改造；迁移到 111 时再分配对应项目端口块。

## Service 结构

每个对外角色保留业务内部 ClusterIP Service，并额外建立只供 101 网关访问的 `<service>-gateway` NodePort Service。以 drinkzen API 为例：

```yaml
apiVersion: v1
kind: Service
metadata:
  name: drinkzen-api-gateway
  namespace: drinkzen
spec:
  type: NodePort
  selector:
    app.kubernetes.io/name: drinkzen-api
    app.kubernetes.io/instance: drinkzen-api
  ports:
    - name: http
      port: 8020
      targetPort: http
      nodePort: 31011
```

原 `drinkzen-api`、`drinkzen-admin` Service 在网关切换完成后改为 ClusterIP。k3s ServiceLB 暂不全局禁用，待确认没有其他业务依赖后再单独处理。

安全组只允许 `101.34.78.2/32` 访问已经启用的生产 NodePort；不向公网开放整个 `30000-32767` 范围。

## 变更流程

1. 盘点 `kubectl get svc -A`，确认目标 NodePort 未被占用。
2. 在业务仓增加并部署并行 `<service>-gateway` NodePort Service。
3. 安全组仅对 101 开放目标端口。
4. 从 101 验证 NodePort 的 HTTP 和 `/healthz`。
5. 修改 Nginx upstream，完成 `nginx -t` 和网关部署。
6. 公网验证稳定后，将原 LoadBalancer Service 改为 ClusterIP。
7. 最后切换 DNS并加入 Uptime Probe。

不同项目分别迁移和回滚，不在一个发布窗口同时改端口。
