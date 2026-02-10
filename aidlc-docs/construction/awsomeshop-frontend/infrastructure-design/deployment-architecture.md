# Unit 1: awsomeshop-frontend — 部署架构

---

## 1. 部署拓扑

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              Docker Host                                     │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                        awsomeshop-net (bridge)                       │   │
│  │                                                                      │   │
│  │  ┌─────────────┐                                                    │   │
│  │  │   Browser   │                                                    │   │
│  │  │  (用户访问)  │                                                    │   │
│  │  └──────┬──────┘                                                    │   │
│  │         │ :3000                                                     │   │
│  │         ↓                                                           │   │
│  │  ┌─────────────────────────────────────────────────────────────┐   │   │
│  │  │                    frontend (Nginx)                          │   │   │
│  │  │                  awsomeshop-frontend                         │   │   │
│  │  │                      :80 (内部)                               │   │   │
│  │  │  ┌─────────────────────────────────────────────────────┐   │   │   │
│  │  │  │  /           → 静态文件 (index.html, JS, CSS)        │   │   │   │
│  │  │  │  /api/*      → proxy_pass api-gateway:8080          │   │   │   │
│  │  │  │  /health     → 200 OK                               │   │   │   │
│  │  │  └─────────────────────────────────────────────────────┘   │   │   │
│  │  └──────────────────────────┬──────────────────────────────────┘   │   │
│  │                             │                                       │   │
│  │                             │ /api/*                                │   │
│  │                             ↓                                       │   │
│  │  ┌─────────────────────────────────────────────────────────────┐   │   │
│  │  │                    api-gateway                               │   │   │
│  │  │                  awsomeshop-gateway                          │   │   │
│  │  │                      :8080                                   │   │   │
│  │  └──────────────────────────┬──────────────────────────────────┘   │   │
│  │                             │                                       │   │
│  │         ┌───────────────────┼───────────────────┐                  │   │
│  │         ↓                   ↓                   ↓                  │   │
│  │  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐            │   │
│  │  │auth-service │    │product-svc  │    │points-svc   │            │   │
│  │  │   :8001     │    │   :8002     │    │   :8003     │            │   │
│  │  └─────────────┘    └─────────────┘    └─────────────┘            │   │
│  │                             │                                       │   │
│  │                             ↓                                       │   │
│  │                      ┌─────────────┐                               │   │
│  │                      │order-service│                               │   │
│  │                      │   :8004     │                               │   │
│  │                      └─────────────┘                               │   │
│  │                             │                                       │   │
│  │                             ↓                                       │   │
│  │                      ┌─────────────┐                               │   │
│  │                      │    mysql    │                               │   │
│  │                      │   :3306     │                               │   │
│  │                      └─────────────┘                               │   │
│  │                                                                      │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. 端口分配汇总

| 服务 | 容器名 | 内部端口 | 对外端口 | 说明 |
|------|--------|---------|---------|------|
| frontend | awsomeshop-frontend | 80 | 3000 | 前端 Nginx |
| api-gateway | awsomeshop-gateway | 8080 | 8080 | API 网关（可选暴露） |
| auth-service | awsomeshop-auth | 8001 | - | 认证服务（内部） |
| product-service | awsomeshop-product | 8002 | - | 产品服务（内部） |
| points-service | awsomeshop-points | 8003 | - | 积分服务（内部） |
| order-service | awsomeshop-order | 8004 | - | 兑换服务（内部） |
| mysql | awsomeshop-mysql | 3306 | 3306 | 数据库（开发调试） |

用户访问入口：`http://localhost:3000`

---

## 3. 启动流程

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              启动时序                                        │
│                                                                             │
│  T0 ─────────────────────────────────────────────────────────────────────→  │
│                                                                             │
│  [mysql]                                                                    │
│  ├── 启动 MySQL 容器                                                        │
│  ├── 执行初始化脚本 (01~06.sql)                                             │
│  └── 健康检查通过 (mysqladmin ping)                                         │
│       │                                                                     │
│       ↓ (condition: service_healthy)                                        │
│                                                                             │
│  [auth-service] [product-service] [points-service] [order-service]          │
│  ├── 并行启动                                                               │
│  ├── 连接数据库                                                             │
│  └── 健康检查通过 (/actuator/health)                                        │
│       │                                                                     │
│       ↓ (depends_on)                                                        │
│                                                                             │
│  [api-gateway]                                                              │
│  ├── 启动网关                                                               │
│  ├── 加载路由配置                                                           │
│  └── 健康检查通过 (/actuator/health)                                        │
│       │                                                                     │
│       ↓ (depends_on)                                                        │
│                                                                             │
│  [frontend]                                                                 │
│  ├── 启动 Nginx                                                             │
│  ├── 加载静态文件                                                           │
│  └── 健康检查通过 (/health)                                                 │
│       │                                                                     │
│       ↓                                                                     │
│                                                                             │
│  ✅ 系统就绪，可访问 http://localhost:3000                                   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 4. 请求流转路径

### 4.1 页面访问

```
浏览器 → http://localhost:3000/
    ↓
frontend (Nginx :80)
    ↓ try_files
/usr/share/nginx/html/index.html
    ↓
返回 HTML → 浏览器加载 JS/CSS
```

### 4.2 API 请求（以登录为例）

```
浏览器 → POST http://localhost:3000/api/auth/login
    ↓
frontend (Nginx :80)
    ↓ location /api/ → proxy_pass
api-gateway:8080/api/auth/login
    ↓ 路由匹配
auth-service:8001/api/auth/login
    ↓ 业务处理
返回 JWT → api-gateway → frontend → 浏览器
```

### 4.3 产品列表请求

```
浏览器 → GET http://localhost:3000/api/products?page=1
    ↓
frontend (Nginx) → api-gateway → product-service
    ↓
返回产品列表 JSON
```

### 4.4 兑换流程请求

```
浏览器 → POST http://localhost:3000/api/orders
    ↓
frontend (Nginx) → api-gateway → order-service
    ↓                               ↓
    ↓                    points-service (扣积分)
    ↓                               ↓
    ↓                    product-service (扣库存)
    ↓                               ↓
返回订单信息 ←─────────────────────────┘
```

### 4.5 图片访问

```
浏览器 → GET http://localhost:3000/api/files/{filename}
    ↓
frontend (Nginx) → api-gateway → product-service
    ↓
返回图片文件
```

### 4.6 静态资源请求

```
浏览器 → GET http://localhost:3000/assets/main.js
    ↓
frontend (Nginx :80)
    ↓ try_files
/usr/share/nginx/html/assets/main.js
    ↓
返回 JS 文件（无缓存）
```

---

## 5. 故障恢复

### 5.1 前端容器故障

| 故障场景 | 影响 | 恢复方式 |
|---------|------|---------|
| Nginx 进程崩溃 | 无法访问页面 | Docker 自动重启（restart: unless-stopped） |
| 健康检查失败 | 标记为 unhealthy | 检查 Nginx 配置和日志 |

### 5.2 API 网关故障

| 故障场景 | 影响 | 恢复方式 |
|---------|------|---------|
| 网关不可用 | API 请求失败 | 前端显示网络错误提示 |
| 网关超时 | 请求超时 | Nginx 返回 504，前端显示超时提示 |

### 5.3 后端服务故障

| 故障场景 | 影响 | 恢复方式 |
|---------|------|---------|
| 单个服务不可用 | 相关功能不可用 | 网关返回 503，前端显示服务不可用 |
| 数据库不可用 | 所有服务不可用 | 等待数据库恢复 |

---

## 6. 开发调试

### 6.1 本地开发（不使用 Docker）

```bash
# 1. 启动后端服务（Docker）
cd infrastructure
docker compose up -d mysql api-gateway auth-service product-service points-service order-service

# 2. 启动前端开发服务器
cd awsomeshop-frontend
npm run dev
# 访问 http://localhost:3000（开发服务器代理 /api 到 localhost:8080）
```

### 6.2 完整 Docker 部署

```bash
# 启动所有服务
cd infrastructure
docker compose up -d

# 访问 http://localhost:3000
```

### 6.3 常用命令

```bash
# 查看前端日志
docker logs -f awsomeshop-frontend

# 重新构建前端镜像
docker compose build frontend

# 重启前端服务
docker compose restart frontend

# 进入前端容器
docker exec -it awsomeshop-frontend sh

# 检查 Nginx 配置
docker exec awsomeshop-frontend nginx -t
```

### 6.4 调试 API 代理

```bash
# 测试 API 代理是否正常
curl http://localhost:3000/api/products

# 测试健康检查
curl http://localhost:3000/health
```

---

## 7. 生产环境注意事项

### 7.1 缓存策略调整

生产环境应启用静态资源缓存：

```nginx
# 生产环境 Nginx 配置
location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
    expires 1y;
    add_header Cache-Control "public, immutable";
}
```

### 7.2 HTTPS 配置

生产环境应配置 HTTPS：

```nginx
server {
    listen 443 ssl;
    ssl_certificate /etc/nginx/ssl/cert.pem;
    ssl_certificate_key /etc/nginx/ssl/key.pem;
    # ...
}
```

### 7.3 安全头

```nginx
add_header X-Frame-Options "SAMEORIGIN";
add_header X-Content-Type-Options "nosniff";
add_header X-XSS-Protection "1; mode=block";
```

---

## 8. 完整服务列表

| 序号 | 服务 | 容器名 | 端口 | 状态 |
|------|------|--------|------|------|
| 1 | frontend | awsomeshop-frontend | 3000:80 | ✅ 设计完成 |
| 2 | api-gateway | awsomeshop-gateway | 8080:8080 | ✅ 设计完成 |
| 3 | auth-service | awsomeshop-auth | 8001 | ✅ 设计完成 |
| 4 | product-service | awsomeshop-product | 8002 | ✅ 设计完成 |
| 5 | points-service | awsomeshop-points | 8003 | ✅ 设计完成 |
| 6 | order-service | awsomeshop-order | 8004 | ✅ 设计完成 |
| 7 | mysql | awsomeshop-mysql | 3306:3306 | ✅ 设计完成 |

所有 7 个服务的基础设施设计已完成。
