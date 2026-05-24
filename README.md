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
│   └── ai-todo/                # ai-todo API
│       ├── ai-todo.conf        # wodi.games → :8082
│       └── cert/               # wodi.games 证书（git 忽略）
├── observability/              # 监控配置（下个版本启用）
│   └── prometheus.yml
├── docker-compose.yml          # Docker Compose 配置
└── .github/workflows/cd.yml    # CD 自动部署
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

生产环境通过 GitHub Actions CD 流水线自动部署，push 到 main 分支即可触发。

## 📍 配置说明

### 添加新项目

1. 在 `app/` 下创建项目目录：`app/<project>/`
2. 创建 Nginx vhost 配置：`app/<project>/<project>.conf`
3. 放置 SSL 证书到 `app/<project>/cert/`（已 git 忽略）
4. 在 `docker-compose.yml` 中添加证书挂载
5. 重启服务

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