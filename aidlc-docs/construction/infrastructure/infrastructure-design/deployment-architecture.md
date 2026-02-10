# Unit 7: infrastructure — 部署架构

---

## 1. 部署拓扑图

```mermaid
graph TD
    subgraph Host["宿主机"]
        subgraph DockerNet["Docker Network: awsomeshop-net"]
            FE["frontend<br/>Nginx :80<br/>SPA + 反向代理"]
            GW["api-gateway<br/>:8080<br/>JWT校验 + 路由"]
            AUTH["auth-service<br/>:8080"]
            PROD["product-service<br/>:8080"]
            PTS["points-service<br/>:8080"]
            ORD["order-service<br/>:8080"]
            DB["mysql<br/>:3306<br/>MySQL 8.4"]
        end

        VOL_DB["mysql-data<br/>(named volume)"]
        VOL_IMG["./uploads<br/>(bind mount)"]
    end

    Browser["浏览器"] -->|":80"| FE
    FE -->|"/api/* → proxy_pass"| GW
    GW --> AUTH
    GW --> PROD
    GW --> PTS
    GW --> ORD
    ORD -->|"跨服务调用"| PROD
    ORD -->|"跨服务调用"| PTS
    AUTH --> DB
    PROD --> DB
    PTS --> DB
    ORD --> DB
    DB --- VOL_DB
    PROD --- VOL_IMG

    style Host fill:none,stroke:#555,stroke-width:2px
    style DockerNet fill:none,stroke:#1976D2,stroke-width:2px
    style FE fill:none,stroke:#00838F,stroke-width:1px
    style GW fill:none,stroke:#7B1FA2,stroke-width:1px
    style AUTH fill:none,stroke:#1976D2,stroke-width:1px
    style PROD fill:none,stroke:#388E3C,stroke-width:1px
    style PTS fill:none,stroke:#F57C00,stroke-width:1px
    style ORD fill:none,stroke:#C62828,stroke-width:1px
    style DB fill:none,stroke:#3F51B5,stroke-width:1px
    style VOL_DB fill:none,stroke:#666,stroke-width:1px,stroke-dasharray:5
    style VOL_IMG fill:none,stroke:#666,stroke-width:1px,stroke-dasharray:5
    style Browser fill:none,stroke:#333,stroke-width:1px
```

---

## 2. 端口映射

| 服务 | 容器端口 | 宿主机端口 | 访问方式 |
|------|---------|-----------|---------|
| frontend | 80 | 80 | 浏览器直接访问 `http://localhost` |
| api-gateway | 8080 | 8080 | 浏览器不直接访问（通过 Nginx 反向代理） |
| mysql | 3306 | 3306 | 开发工具连接（如 DBeaver、Navicat） |
| auth-service | 8080 | — | 仅 Docker 内部访问 |
| product-service | 8080 | — | 仅 Docker 内部访问 |
| points-service | 8080 | — | 仅 Docker 内部访问 |
| order-service | 8080 | — | 仅 Docker 内部访问 |

用户访问入口：`http://localhost`（前端 Nginx 统一处理页面和 API）

---

## 3. 卷映射

| 卷 | 类型 | 容器路径 | 宿主机路径 | 用途 |
|----|------|---------|-----------|------|
| mysql-data | named volume | /var/lib/mysql | Docker 管理 | MySQL 数据持久化 |
| uploads | bind mount | /app/uploads | ../uploads（项目根目录） | 产品图片存储 |
| nginx config | bind mount (ro) | /etc/nginx/conf.d/default.conf | ./nginx/default.conf | Nginx 配置 |
| mysql init | bind mount (ro) | /docker-entrypoint-initdb.d | ./mysql/ | 数据库初始化脚本 |

---

## 4. 启动流程

```mermaid
sequenceDiagram
    participant User as 开发者
    participant DC as docker compose
    participant MySQL as mysql
    participant MS as 微服务 x4
    participant GW as api-gateway
    participant FE as frontend

    User->>DC: docker compose up -d
    DC->>MySQL: 启动 MySQL 8.4
    MySQL->>MySQL: 执行 initdb.d 脚本<br/>(01~06.sql)
    MySQL->>MySQL: healthcheck: mysqladmin ping
    Note over MySQL: ✅ service_healthy

    DC->>MS: 并行启动 4 个微服务<br/>(depends_on mysql healthy)
    MS->>MySQL: 建立数据库连接

    DC->>GW: 启动 api-gateway<br/>(depends_on 4 个微服务)
    DC->>FE: 启动 frontend<br/>(depends_on api-gateway)

    Note over FE: ✅ 所有服务就绪
    User->>FE: 访问 http://localhost
```

---

## 5. 请求流转路径

```
浏览器
  │
  ▼ http://localhost (port 80)
frontend (Nginx)
  │
  ├── 静态资源 → 直接返回 (HTML/JS/CSS/图片)
  ├── SPA 路由 → /index.html
  └── /api/* → proxy_pass http://api-gateway:8080
          │
          ▼
      api-gateway
          │
          ├── JWT 校验（公开端点放行）
          ├── 角色权限校验（/api/admin/* 需要 ADMIN）
          └── 路由转发：
              ├── /api/auth/*     → auth-service:8080
              ├── /api/users/*    → auth-service:8080
              ├── /api/products/* → product-service:8080
              ├── /api/categories/* → product-service:8080
              ├── /api/files/*    → product-service:8080
              ├── /api/points/*   → points-service:8080
              ├── /api/orders/*   → order-service:8080
              └── /api/admin/*    → 对应微服务
```

---

## 6. 开发常用命令

```bash
# 进入 infrastructure 目录
cd infrastructure

# 首次启动（构建镜像 + 启动）
docker compose up -d --build

# 查看所有服务状态
docker compose ps

# 查看某个服务日志
docker compose logs -f api-gateway

# 停止所有服务
docker compose down

# 停止并清除数据（重新初始化数据库）
docker compose down -v

# 仅重建某个服务
docker compose up -d --build auth-service
```

---

## 7. .gitignore 规则

```gitignore
# 环境变量（包含敏感信息）
infrastructure/.env

# 上传文件目录
uploads/

# Docker 相关
*.log
```
