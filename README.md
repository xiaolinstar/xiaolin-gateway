# 小林网关 (xiaolin-gateway)

一个独立的网关项目，负责负载均衡、证书管理和域名解析的集中管理。

## 🚀 项目功能

- **负载均衡**：基于 Nginx 实现的软负载均衡，支持多后端服务器
- **证书管理**：集中管理所有项目的 SSL 证书
- **域名解析**：统一管理域名配置和路由规则
- **容器化部署**：使用 Docker Compose 一键部署
- **IPv6 支持**：双栈网络，同时支持 IPv4 和 IPv6 访问

## 📁 项目结构

```text
xiaolin-gateway/
├── app/                        # Nginx 配置与证书
│   ├── gateway.conf            # 网关入口（80→443 跳转）
│   ├── xiaolin-docs/           # xiaolin-docs 项目
│   │   ├── xiaolin-docs.conf   # Nginx vhost 配置
│   │   └── cert/               # SSL 证书（git 忽略）
│   ├── xiaolin-life/           # xiaolin-life 项目
│   │   ├── xiaolin-life.conf   # Nginx vhost 配置
│   │   └── cert/               # SSL 证书（git 忽略）
│   ├── ai-todo/                # ai-todo API
│   │   ├── ai-todo.conf        # xingxiaolin.cn → :8082
│   │   └── cert/               # SSL 证书（git 忽略）
│   ├── drink-budget/           # drink-budget
│   │   ├── drink-budget.conf   # wodi.games → :8020
│   │   └── cert/               # SSL 证书（git 忽略）
│   └── party-helper/           # party-helper API
│       ├── party-helper.conf   # api.wodi.games → :8021
│       └── cert/               # SSL 证书（git 忽略）
├── docs/                       # 规范与说明
│   ├── routing-registry.md     # 域名 / upstream / 负责仓库（真源）
│   └── healthz-probe-standard.md
├── observability/              # 可观测配置
│   ├── prometheus.yml
│   └── grafana/                # Grafana 数据源与看板 provisioning
├── docker-compose.yml          # Docker Compose 配置
├── scripts/ci/                 # CI：dummy 证书 + nginx -t
└── .github/workflows/
    ├── ci.yml                  # gitleaks + nginx -t
    ├── cd.yml                  # CI 通过后部署
    └── uptime.yml              # 外部探活
```

## 🔧 快速开始

### 环境要求

- Docker & Docker Compose
- 域名解析到服务器 IP
- SSL 证书（生产：腾讯云免费证书；本地：自签名证书）

### 本地开发环境

```bash
# 1. 生成自签名证书（文件名与生产一致）
openssl req -x509 -newkey rsa:2048 \
  -keyout app/xiaolin-docs/cert/xiaolinstar.cn.key \
  -out app/xiaolin-docs/cert/xiaolinstar.cn_bundle.crt \
  -days 365 -nodes -subj "/CN=localhost"

openssl req -x509 -newkey rsa:2048 \
  -keyout app/xiaolin-life/cert/xiaolin.fun.key \
  -out app/xiaolin-life/cert/xiaolin.fun_bundle.crt \
  -days 365 -nodes -subj "/CN=localhost"

# 2. 启动（默认使用 80/443 端口）
docker compose up -d

# 如果本地端口被占用，使用环境变量覆盖
HTTP_PORT=8081 HTTPS_PORT=8444 docker compose up -d

# 3. 查看日志
docker logs nginx-gateway -f
```

**端口冲突处理**：通过环境变量 `HTTP_PORT` 和 `HTTPS_PORT` 覆盖默认端口，无需修改配置文件。

### 生产环境

```bash
# 1. 将正式 SSL 证书上传到 app/<project>/cert/ 目录

# 2. 启动
docker compose up -d

# 3. 验证
docker compose ps
```

生产环境通过 GitHub Actions 部署：**`main` 上 CI 通过后**自动 CD；也可手动 `workflow_dispatch`。配置真源见 [docs/routing-registry.md](docs/routing-registry.md)。

## 📈 可观测能力

阶段一已启用轻量自建监控栈：

- **Prometheus**：采集时序指标，默认保留 15 天
- **Grafana**：展示网关基础看板
- **Alertmanager**：接收 Prometheus 告警并负责分组、重复提醒和邮件通知
- **nginx-prometheus-exporter**：采集 Nginx `stub_status` 指标
- **node-exporter**：采集主机 CPU、内存、磁盘等指标
- **GitHub Actions Uptime Probe**：每 15 分钟从 GitHub Runner 探测公网域名，并检查证书是否会在 14 天内过期

### 本地指标面板

```bash
docker compose up -d
```

默认访问地址：

- Grafana: http://127.0.0.1:3000
- Prometheus: http://127.0.0.1:9090
- Alertmanager: http://127.0.0.1:9093

默认 Grafana 账号密码为 `admin` / `admin`。生产环境建议通过环境变量覆盖：

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

真实运行时变量文件放在项目根目录的 `.env*` 文件中。所有环境先加载 `.env`，再按场景叠加 `.env.local` 或 `.env.production`。这些真实文件已被 `.gitignore` 忽略，不要提交生产密码。详见 [docs/env/README.md](docs/env/README.md) 与 [运行时环境变量管理](docs/runtime-env-management.md)。

Prometheus、Grafana 和 Alertmanager 只绑定宿主机 `127.0.0.1`，生产环境不直接暴露到公网。需要远程查看时，通过 SSH 隧道把服务端本机端口转发到本地：

```bash
ssh -L 3000:127.0.0.1:3000 -L 9090:127.0.0.1:9090 -L 9093:127.0.0.1:9093 <user>@<server>
```

如果生产环境通过 `.env.production` 自定义了端口，例如 `GRAFANA_PORT=9000`，隧道端口也要对应调整：

```bash
ssh -L 9000:127.0.0.1:9000 -L 9090:127.0.0.1:9090 -L 9093:127.0.0.1:9093 <user>@<server>
```

隧道仅在 SSH 会话存活期间有效。需要后台运行时可加 `-N -f`：

```bash
ssh -N -f -L 9000:127.0.0.1:9000 -L 9090:127.0.0.1:9090 -L 9093:127.0.0.1:9093 <user>@<server>
```

关闭后台隧道时先查找对应进程，再结束它：

```bash
ps aux | grep "ssh .* -L"
kill <pid>
```

除非额外加上认证、HTTPS 和访问控制，否则不要把 Grafana、Prometheus 或 Alertmanager 改成 `0.0.0.0` 直接暴露公网；Prometheus 和 Alertmanager 尤其应保持本机或内网访问。

### 告警配置

Prometheus 会加载 `observability/alerts/*.yml` 中的告警规则，并把触发的告警发送给 Alertmanager。当前默认的 `observability/alertmanager/alertmanager.yml` 使用 `noop` 接收器，保证监控栈可以先稳定启动；启用真实邮件通知时，再使用本地配置覆盖。

启用邮件告警：

```bash
cp observability/alertmanager/alertmanager.yml.example observability/alertmanager/alertmanager.local.yml
mkdir -p observability/secrets
printf '%s' '<smtp-password-or-app-password>' > observability/secrets/smtp_password
chmod 600 observability/secrets/smtp_password
```

然后编辑 `observability/alertmanager/alertmanager.local.yml`：

- `smtp_smarthost`：SMTP 服务器与端口，例如 `smtp.example.com:587`
- `smtp_from` / `smtp_auth_username`：发件邮箱与认证账号
- `to`：告警收件邮箱
- `smtp_auth_password_file`：保持为 `/etc/alertmanager/secrets/smtp_password`

QQ/foxmail 邮箱实测使用 STARTTLS 端口 `587` 可以正常发送：

```yaml
smtp_smarthost: smtp.qq.com:587
smtp_require_tls: true
```

不要使用 `smtp.qq.com:465`。当前 `prom/alertmanager:v0.28.1` 不支持隐式 TLS 所需的 `smtp_force_implicit_tls` 配置，使用 `465` 会报 `does not advertise the STARTTLS extension`。

邮件模板中已设置 `send_resolved: true`，告警恢复后 Alertmanager 会发送一封 resolved 邮件。恢复通知和触发通知使用同一个分组策略，通常会在 Prometheus 规则下一次评估并把恢复状态同步给 Alertmanager 后发出。

最后在运行时环境文件中指定本地配置，例如生产环境写入 `.env.production`：

```bash
ALERTMANAGER_CONFIG=./observability/alertmanager/alertmanager.prod.yaml
ALERTMANAGER_PORT=9093
```

然后用下面的方式启动：

```bash
set -a
. ./.env
. ./.env.production
set +a
docker compose up -d
```

部署前建议先校验配置：

```bash
docker run --rm --entrypoint promtool -v "$PWD/observability:/etc/prometheus:ro" prom/prometheus:v3.5.0 check config /etc/prometheus/prometheus.yml
docker run --rm --entrypoint amtool -v "$PWD/observability/alertmanager:/etc/alertmanager:ro" prom/alertmanager:v0.28.1 check-config /etc/alertmanager/alertmanager.yml
```

如果启用了环境化邮件配置，校验 Alertmanager 时改用对应文件：

```bash
docker run --rm --entrypoint amtool -v "$PWD/observability/alertmanager:/etc/alertmanager:ro" prom/alertmanager:v0.28.1 check-config /etc/alertmanager/alertmanager.prod.yaml
```

### 外部探活

`.github/workflows/uptime.yml` 支持手动触发，也会每 15 分钟自动执行。任一域名请求失败、HTTP 状态异常、TLS 证书无效或 14 天内过期，workflow 都会失败并触发 GitHub 通知。

**规范：** 所有经网关对外暴露的子系统，统一使用 `GET /healthz` 作为外部探活路径（返回 2xx）。详细约定、迁移进度与接入清单见 [docs/healthz-probe-standard.md](docs/healthz-probe-standard.md)。

当前 **全部** 子系统 workflow 已切换为 `/healthz`；合并后需先对各业务仓执行 CD，再观察 gateway `uptime.yml` 是否通过。

| 子系统 | 探测 URL |
|--------|----------|
| xiaolinstar | https://www.xiaolinstar.cn/healthz |
| xiaolin-life | https://www.xiaolin.fun/healthz |
| ai-todo | https://www.xingxiaolin.cn/healthz |
| ai-todo-staging | https://www.staging.xingxiaolin.cn/healthz |
| drink-budget | https://www.wodi.games/healthz |
| party-helper | https://api.wodi.games/healthz |

如需调整探测目标，修改 workflow 中的 `matrix.target` 列表，并同步更新规范文档中的迁移表。

## 📍 配置说明

### 添加新项目

1. 在 [docs/routing-registry.md](docs/routing-registry.md) 登记一行。
2. 在 `app/` 下创建项目目录：`app/<project>/`
3. 创建 Nginx vhost 配置：`app/<project>/<project>.conf`
4. 放置 SSL 证书到 `app/<project>/cert/`（已 git 忽略）
5. 在 `docker-compose.yml` 中添加证书挂载
6. 后端实现 `GET /healthz`（见 [healthz 探活规范](docs/healthz-probe-standard.md)）
7. 在 `.github/workflows/uptime.yml` 增加探活项（`url` 为 `https://<域名>/healthz`）
8. 提 PR；CI 跑 gitleaks + `nginx -t` 通过后合并，CD 自动部署

### Nginx vhost 配置模板

```nginx
upstream <project-name> {
    server <backend-ip>:<port>;
}

server {
    listen 443 ssl;
    listen [::]:443 ssl;
    server_name <domain>;

    ssl_certificate /etc/nginx/cert/<project>/<domain>_bundle.crt;
    ssl_certificate_key /etc/nginx/cert/<project>/<domain>.key;
    ssl_session_timeout 5m;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:HIGH:!aNULL:!MD5:!RC4:!DHE;
    ssl_prefer_server_ciphers on;

    location / {
        proxy_pass http://<project-name>;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

## 🛠️ 维护命令

```bash
# 检查 Nginx 配置语法
docker exec nginx-gateway nginx -t

# 重新加载 Nginx 配置（不中断服务）
docker exec nginx-gateway nginx -s reload

# 查看 Nginx 日志
docker logs nginx-gateway -f

# 停止服务
docker compose down
```

## 📄 许可证

MIT License
