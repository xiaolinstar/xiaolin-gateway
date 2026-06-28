# 运行时环境变量管理

本项目在 CI/CD 阶段继续使用 GitHub Actions Secrets 管理部署凭据。运行时容器
配置使用项目根目录的 `.env*` 文件分层管理。

## 当前模型

- `.env`：所有环境都会加载的基础运行时变量。
- `.env.local`：本地开发覆盖，加载顺序为 `.env` -> `.env.local`。
- `.env.production`：生产环境覆盖，CD 加载顺序为 `.env` -> `.env.production`。
- `.env*.example`：可提交模板。
- 运行时密钥优先使用被 git 忽略的本地文件，例如 `observability/secrets/`。

生产环境：

```bash
cp .env.example .env
cp .env.production.example .env.production
vim .env
vim .env.production
set -a
. ./.env
. ./.env.production
set +a
docker compose up -d
```

本地环境：

```bash
cp .env.example .env
cp .env.local.example .env.local
vim .env
vim .env.local
set -a
. ./.env
. ./.env.local
set +a
docker compose up -d
```

## Alertmanager 多环境配置

默认 `observability/alertmanager/alertmanager.yml` 使用 `noop` receiver，保证监控栈
可以启动。真实通知配置按环境放在被忽略的本地文件中：

- 本地：`observability/alertmanager/alertmanager.local.yml`
- 生产：`observability/alertmanager/alertmanager.prod.yaml`

生产环境可以从模板创建：

```bash
cp observability/alertmanager/alertmanager.prod.yaml.example observability/alertmanager/alertmanager.prod.yaml
```

然后在 `.env.production` 中指定：

```bash
ALERTMANAGER_CONFIG=./observability/alertmanager/alertmanager.prod.yaml
```

SMTP 密码等密钥仍放在 `observability/secrets/`，例如：

```bash
mkdir -p observability/secrets
printf '%s' '<smtp-password-or-app-password>' > observability/secrets/smtp_password
chmod 600 observability/secrets/smtp_password
```

## 分类规则

新增配置时先按下面的边界归类：

| 类型 | 示例 | 存储位置 |
| --- | --- | --- |
| 构建或部署凭据 | SSH host、SSH password、镜像仓库 token | GitHub Actions Secrets |
| 运行时基础变量 | 默认端口、保留周期、默认配置路径 | `.env` |
| 运行时环境覆盖 | 生产 Alertmanager 配置、生产端口覆盖 | `.env.production` |
| 运行时密钥 | SMTP 密码、应用私钥、数据库密码 | 挂载密钥文件，或未来的密钥管理服务 |
| 公共配置 | 域名、探活 URL、Grafana provisioning | 提交到仓库的配置文件 |

不要把运行时密钥提交到仓库。容器支持文件密钥时，优先使用文件挂载而不是普通
环境变量。

当前兼容例外：`GRAFANA_ADMIN_PASSWORD` 仍然在 env 文件中配置，以避免影响现有
部署。后续可以把它迁移为 Grafana 支持的 `GF_SECURITY_ADMIN_PASSWORD__FILE`
文件密钥模式。

## 新增运行时变量

1. 在 `.env.example` 增加默认值。
2. 如果某个环境需要覆盖，在 `.env.local.example` 或 `.env.production.example`
   增加对应变量。
3. 在 `docker-compose.yml` 中引用变量；能提供安全默认值时保留默认值。
4. 在服务器真实文件中更新，例如 `.env` 和 `.env.production`。
5. CD 会按 `.env` -> `.env.production` 的顺序加载变量并执行 `docker compose`。

## 迁移到 Kubernetes 的路径

当前拆分可以自然映射到 Kubernetes：

- `.env` + `.env.production` -> `ConfigMap`
- 挂载的密钥文件 -> `Secret` volume
- Docker Compose service -> `Deployment` 和 `Service`
- 本机绑定端口 -> 内网 `Service`、Ingress 或 `port-forward`
- Alertmanager 环境配置 -> `ConfigMap`

迁移到 k8s 时继续保持同一套分类规则：

- 非密钥进入 ConfigMap；
- 密钥进入 Secret 或 external secret operator；
- 公开路由、探活规则、看板配置进入版本化 manifest；
- CI/CD 凭据仍放在 GitHub Secrets 或 GitHub Environments。
