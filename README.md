# 小林网关 (xiaolin-gateway)

一个独立的网关项目，负责负载均衡、证书管理和域名解析的集中管理。

## 🚀 项目功能

- **负载均衡**：基于 Nginx 实现的软负载均衡，支持多后端服务器
- **证书管理**：集中管理所有项目的 SSL 证书
- **域名解析**：统一管理域名配置和路由规则
- **可观测性**：集成 Prometheus + Grafana 可观测性系统
- **容器化部署**：使用 Docker Compose 一键部署

## 📁 项目结构

```
xiaolin-gateway/
├── app/                # 业务应用相关文件
├── nginx/              # Nginx 配置
│   ├── nginx.conf      # 主配置文件
│   └── conf.d/         # 虚拟主机配置
│       ├── xiaolin-docs.conf     # xiaolin-docs 项目配置
│       └── undercover-game.conf  # undercover-game 项目配置
├── certs/              # SSL 证书目录
├── logs/               # 日志目录
├── observability/      # 可观测性配置
│   ├── prometheus.yml  # Prometheus 配置
│   └── grafana/        # Grafana 配置
├── docker-compose.yml  # Docker Compose 配置
├── .gitignore          # Git 忽略文件
└── README.md           # 项目说明
```

### 目录说明

- **app/**：存放业务应用相关的文件，如后端服务代码、前端应用等
- **nginx/**：Nginx 负载均衡和代理配置
- **certs/**：SSL 证书目录（已忽略）
- **logs/**：日志目录（已忽略）
- **observability/**：可观测性系统配置
- **observability/grafana/**：Grafana 数据目录（已忽略）

## 🔧 快速开始

### 环境要求

- Docker & Docker Compose
- 域名解析到服务器 IP
- SSL 证书（可使用 Let's Encrypt 或自签名证书）

### 配置步骤

1. **准备证书**：将 SSL 证书放置到 `certs/` 目录
   - `docs.xiaolin.com.crt` 和 `docs.xiaolin.com.key`
   - `game.xiaolin.com.crt` 和 `game.xiaolin.com.key`

2. **配置域名**：在 DNS 服务商处将域名解析到服务器 IP
   - `docs.xiaolin.com` → 服务器 IP
   - `game.xiaolin.com` → 服务器 IP

3. **启动服务**：

```bash
# 启动网关服务
docker-compose up -d

# 查看服务状态
docker-compose ps
```

### 访问地址

- **Nginx 网关**：http://服务器IP 或 https://域名
- **Grafana 可观测性**：http://服务器IP:3000（默认用户名/密码：admin/admin）
- **Prometheus**：http://服务器IP:9090

## 📍 配置说明

### Nginx 配置

- **主配置**：`nginx/nginx.conf` - 全局 Nginx 配置
- **虚拟主机**：`nginx/conf.d/` 目录下的每个文件对应一个项目的配置

### 负载均衡配置

在每个项目的配置文件中，可以通过 `upstream` 块添加多个后端服务器：

```nginx
upstream xiaolin_docs {
    server xiaolin-docs:80;
    server xiaolin-docs-2:80;  # 额外的后端服务器
}
```

### 证书管理

将所有项目的 SSL 证书集中存储在 `certs/` 目录，在 Nginx 配置中引用：

```nginx
ssl_certificate /etc/nginx/certs/docs.xiaolin.com.crt;
ssl_certificate_key /etc/nginx/certs/docs.xiaolin.com.key;
```

### 域名解析

通过 Nginx 的 `server_name` 指令配置域名：

```nginx
server {
    listen 443 ssl http2;
    server_name docs.xiaolin.com;
    # ...
}
```

## 📊 可观测性系统

### Prometheus

- 配置文件：`observability/prometheus.yml`
- 监控目标：Nginx、Prometheus 自身、Grafana

### Grafana

- 默认端口：3000
- 数据源：Prometheus
- 可创建监控面板，监控 Nginx 性能指标

## 🔄 部署流程

1. **更新配置**：修改 Nginx 配置文件，添加新的项目或更新现有配置
2. **重新加载**：运行 `docker-compose up -d` 重新加载配置
3. **验证**：访问域名，确保服务正常运行
4. **可观测性**：通过 Grafana 可观测性系统监控状态

## 🛠️ 维护命令

```bash
# 查看 Nginx 日志
docker logs xiaolin-gateway-nginx

# 重新加载 Nginx 配置
docker exec xiaolin-gateway-nginx nginx -s reload

# 检查 Nginx 配置语法
docker exec xiaolin-gateway-nginx nginx -t

# 停止服务
docker-compose down
```

## 📝 扩展指南

### 添加新项目

1. 在 `nginx/conf.d/` 目录创建新的配置文件
2. 配置上游服务器和域名
3. 放置对应的 SSL 证书到 `certs/` 目录
4. 重启网关服务

### 负载均衡策略

Nginx 支持多种负载均衡策略：
- **轮询**（默认）：按顺序分配请求
- **权重**：`server backend:80 weight=5;`
- **ip_hash**：根据客户端 IP 分配固定服务器
- **least_conn**：分配给连接数最少的服务器

## 📄 许可证

MIT License
