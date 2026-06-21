# 运行时环境变量管理

本项目在 CI/CD 阶段继续使用 GitHub Actions Secrets 和 GitHub Environments
管理部署凭据。运行时容器配置单独放在目标服务器上管理，不再把不同环境都堆在
项目根目录的 `.env` / `.env.production` 中。

## 当前模型

- 非密钥运行时变量放在服务器的 `env/<environment>.env`。
- 运行时密钥优先使用被 git 忽略的本地文件，例如 `observability/secrets/`。
- 可提交的模板统一放在 `env/*.env.example`。
- CD 优先读取 `env/production.env`；如果暂时还没有该文件，会兼容旧的根目录
  `.env`。

生产环境：

```bash
cp env/production.env.example env/production.env
vim env/production.env
docker compose --env-file env/production.env up -d
```

本地环境：

```bash
cp env/local.env.example env/local.env
vim env/local.env
docker compose --env-file env/local.env up -d
```

根目录 `.env.example` 仅保留给旧流程兼容。新增运行时变量应优先添加到
`env/*.env.example`。

## 分类规则

新增配置时先按下面的边界归类：

| 类型 | 示例 | 存储位置 |
| --- | --- | --- |
| 构建或部署凭据 | SSH host、SSH password、镜像仓库 token | GitHub Actions Secrets / GitHub Environments |
| 运行时非密钥 | 端口、保留周期、配置文件路径、功能开关 | `env/<environment>.env` |
| 运行时密钥 | SMTP 密码、应用私钥、数据库密码 | 挂载密钥文件，或未来的密钥管理服务 |
| 公共配置 | 域名、探活 URL、Grafana provisioning | 提交到仓库的配置文件 |

不要把运行时密钥提交到仓库。容器支持文件密钥时，优先使用文件挂载而不是普通
环境变量。

当前兼容例外：`GRAFANA_ADMIN_PASSWORD` 仍然在 env 文件中配置，以避免影响现有
部署。后续可以把它迁移为 Grafana 支持的 `GF_SECURITY_ADMIN_PASSWORD__FILE`
文件密钥模式。

## 新增运行时变量

1. 在 `env/local.env.example` 和 `env/production.env.example` 增加变量。
2. 如果旧的根目录 `.env.example` 仍需兼容，同步补充。
3. 在 `docker-compose.yml` 中引用变量；能提供安全默认值时保留默认值。
4. 在服务器真实文件中更新，例如 `env/production.env`。
5. 使用 `docker compose --env-file env/production.env up -d` 重新部署。

## 迁移到 Kubernetes 的路径

当前拆分可以自然映射到 Kubernetes：

- `env/<environment>.env` -> `ConfigMap`
- 挂载的密钥文件 -> `Secret` volume
- Docker Compose service -> `Deployment` 和 `Service`
- 本机绑定端口 -> 内网 `Service`、Ingress 或 `port-forward`

迁移到 k8s 时继续保持同一套分类规则：

- 非密钥进入 ConfigMap；
- 密钥进入 Secret 或 external secret operator；
- 公开路由、探活规则、看板配置进入版本化 manifest；
- CI/CD 凭据仍放在 GitHub Environments。

如果某个变量需要同时服务 Compose 和 k8s，尽量保持变量名稳定，这样同一个镜像能
在两种运行环境中复用。
