# Unit 6: api-gateway — 部署架构

---

## 1. 部署拓扑

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              宿主机 (Host)                                   │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    Docker Network: awsomeshop-net                    │   │
│  │                                                                      │   │
│  │  ┌──────────────┐                                                   │   │
│  │  │   frontend   │ :80                                               │   │
│  │  │   (Nginx)    │────────────────────┐                              │   │
│  │  └──────────────┘                    │                              │   │
│  │         │                            │                              │   │
│  │         │ /api/*                     │ 静态资源                      │   │
│  │         ▼                            ▼                              │   │
│  │  ┌──────────────┐              ┌──────────────┐                     │   │
│  │  │ api-gateway  │ :8080        │  静态文件     │                     │   │
│  │  │              │              │  /index.html │                     │   │
│  │  └──────────────┘              └──────────────┘                     │   │
│  │         │                                                           │   │
│  │         │ 路由转发                                                   │   │
│  │         │                                                           │   │
│  │    ┌────┴────┬─────────┬─────────┐                                  │   │
│  │    ▼         ▼         ▼         ▼                                  │   │
│  │ ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐                                │   │
│  │ │auth  │ │product│ │points│ │order │                                │   │
│  │ │:8001 │ │:8002  │ │:8003 │ │:8004 │                                │   │
│  │ └──┬───┘ └──┬────┘ └──┬───┘ └──┬───┘                                │   │
│  │    │        │         │        │                                    │   │
│  │    └────────┴────┬────┴────────┘                                    │   │
│  │                  ▼                                                  │   │
│  │           ┌──────────────┐                                          │   │
│  │           │    mysql     │ :3306                                    │   │
│  │           │   (MySQL)    │                                          │   │
│  │           └──────────────┘                                          │   │
│  │                                                                      │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  对外暴露端口:                                                               │
│  ├── :80   → frontend (Nginx)                                              │
│  ├── :8080 → api-gateway (可选，用于直接 API 调试)                          │
│  └── :3306 → mysql (可选，用于数据库调试)                                    │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. 端口分配汇总

| 服务 | 内部端口 | 对外暴露 | 说明 |
|------|---------|---------|------|
| mysql | 3306 | ${MYSQL_PORT:-3306} | 数据库 |
| auth-service | 8001 | - | 认证服务（仅内部） |
| product-service | 8002 | - | 产品服务（仅内部） |
| points-service | 8003 | - | 积分服务（仅内部） |
| order-service | 8004 | - | 兑换服务（仅内部） |
| **api-gateway** | **8080** | **${GATEWAY_PORT:-8080}** | **API 网关** |
| frontend | 80 | ${FRONTEND_PORT:-80} | 前端应用 |

---

## 3. 启动流程

```
1. mysql 启动
   └── 等待健康检查通过（mysqladmin ping）

2. 微服务并行启动（依赖 mysql healthy）
   ├── auth-service
   ├── product-service
   ├── points-service
   └── order-service

3. api-gateway 启动（依赖微服务启动）
   ├── 校验 JWT_SECRET 环境变量
   ├── 加载路由配置
   └── 等待健康检查通过（/actuator/health）

4. frontend 启动（依赖 api-gateway）
   └── Nginx 加载配置，代理 /api/* 到 api-gateway
```

### 启动时序图

```
时间 ──────────────────────────────────────────────────────────────────▶

mysql        [████████████████]  healthy
                              │
auth         ─────────────────[████████████]
product      ─────────────────[████████████]
points       ─────────────────[████████████]
order        ─────────────────[████████████]
                                           │
api-gateway  ─────────────────────────────[████████████]  healthy
                                                        │
frontend     ─────────────────────────────────────────[████████]
```

---

## 4. 请求流转路径

### 4.1 浏览器访问前端页面
```
浏览器 → http://localhost:80
       → frontend (Nginx)
       → 返回 index.html + 静态资源
```

### 4.2 前端调用 API（通过 Nginx 代理）
```
浏览器 → http://localhost:80/api/products
       → frontend (Nginx)
       → proxy_pass http://api-gateway:8080
       → api-gateway 路由匹配 + JWT 校验
       → http://product-service:8002/api/products
       → 响应透传
```

### 4.3 直接调用 API（调试用）
```
Postman → http://localhost:8080/api/auth/login
        → api-gateway
        → http://auth-service:8001/api/auth/login
        → 响应透传
```

### 4.4 员工创建兑换订单（完整链路）
```
浏览器 → POST http://localhost:80/api/orders
       → frontend (Nginx)
       → api-gateway:8080
       │   ├── JWT 校验 ✓
       │   ├── 权限校验 ✓ (AUTHENTICATED)
       │   └── 注入 X-User-Id, X-User-Role
       → order-service:8004
       │   ├── 调用 points-service:8003 扣除积分
       │   └── 调用 product-service:8002 扣减库存
       → 响应透传
```

### 4.5 管理员更新订单状态
```
浏览器 → PUT http://localhost:80/api/admin/orders/1/status
       → frontend (Nginx)
       → api-gateway:8080
       │   ├── JWT 校验 ✓
       │   ├── 权限校验 ✓ (ADMIN_ONLY, role=ADMIN)
       │   └── 注入 X-User-Id, X-User-Role
       → order-service:8004
       │   └── 如果取消，调用 points/product 回滚
       → 响应透传
```

### 4.6 认证失败场景
```
浏览器 → GET http://localhost:80/api/products
         （无 Authorization 头）
       → frontend (Nginx)
       → api-gateway:8080
       │   └── JWT 校验失败
       → 返回 401 { code: "GW_001", message: "未授权，请先登录" }
```

---

## 5. 故障恢复

### 5.1 下游服务不可达
```
api-gateway → http://product-service:8002
            → 连接失败
            → 返回 502 { code: "GW_003", message: "服务暂时不可用" }
```

### 5.2 下游服务响应超时
```
api-gateway → http://order-service:8004
            → 超过 3 秒无响应
            → 返回 504 { code: "GW_004", message: "请求超时" }
```

### 5.3 api-gateway 重启
- 无状态设计，重启后立即可用
- 不影响已建立的数据库连接（微服务各自管理）
- 前端 Nginx 会自动重试失败的请求

### 5.4 健康检查失败
- Docker 会根据 healthcheck 配置自动重启容器
- 重试 3 次后标记为 unhealthy
- 可配合 Docker Swarm 或 Kubernetes 实现自动恢复

---

## 6. 开发调试说明

### 6.1 查看 api-gateway 日志
```bash
docker logs -f awsomeshop-gateway
```

### 6.2 进入容器调试
```bash
docker exec -it awsomeshop-gateway /bin/sh
```

### 6.3 测试健康检查
```bash
curl http://localhost:8080/actuator/health
```

### 6.4 测试路由转发
```bash
# 公开端点（无需认证）
curl http://localhost:8080/api/auth/login \
  -X POST \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"123456"}'

# 受保护端点（需要认证）
curl http://localhost:8080/api/products \
  -H "Authorization: Bearer <token>"

# 管理员端点
curl http://localhost:8080/api/admin/orders \
  -H "Authorization: Bearer <admin-token>"
```

### 6.5 查看环境变量
```bash
docker exec awsomeshop-gateway env | grep -E "(JWT|SERVICE_URL|TIMEOUT)"
```

---

## 7. 配置变更影响

### 7.1 新增微服务
1. 在 `docker-compose.yml` 添加新服务定义
2. 在 api-gateway 环境变量添加 `NEW_SERVICE_URL`
3. 在 api-gateway 路由配置添加新路由规则
4. 在 api-gateway 权限配置添加访问规则

### 7.2 修改服务端口
1. 更新对应服务的 `SERVER_PORT` 环境变量
2. 更新 api-gateway 的 `*_SERVICE_URL` 环境变量
3. 更新其他依赖该服务的 `*_SERVICE_URL`

### 7.3 修改超时配置
1. 更新 api-gateway 的 `CONNECT_TIMEOUT` 和 `READ_TIMEOUT`
2. 无需重新构建镜像，重启容器即可生效
