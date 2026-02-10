# Unit 4: points-service — 基础设施设计

---

## 1. 容器配置

| 配置项 | 值 | 说明 |
|--------|-----|------|
| 容器名 | awsomeshop-points | 遵循 Unit 7 命名规范 |
| 内部端口 | 8003 | 容器内应用监听端口 |
| 对外暴露 | 否 | 仅通过 Docker 内部网络访问 |
| 网络 | awsomeshop-net (bridge) | Unit 7 定义的共享网络 |
| 构建上下文 | ../points-service | 相对于 infrastructure/ 目录 |

---

## 2. 环境变量

| 变量名 | 来源 | 说明 |
|--------|------|------|
| DB_HOST | mysql | Docker DNS 服务名 |
| DB_PORT | 3306 | MySQL 默认端口 |
| DB_NAME | ${POINTS_DB_NAME} | .env 文件，值：points_db |
| DB_USER | ${POINTS_DB_USER} | .env 文件，值：points_user |
| DB_PASSWORD | ${POINTS_DB_PASSWORD} | .env 文件 |
| SERVER_PORT | 8003 | 应用监听端口 |

### .env 文件新增变量

```env
# points-service
POINTS_DB_NAME=points_db
POINTS_DB_USER=points_user
POINTS_DB_PASSWORD=points_password_change_me
```

---

## 3. 服务依赖

```
points-service 启动依赖:
  └── mysql (condition: service_healthy)
        └── healthcheck: mysqladmin ping

points-service 运行时依赖:
  └── mysql (points_db) — 数据存储

被依赖方:
  ├── auth-service — 注册时调用 POST /api/internal/points/init
  └── order-service — 兑换时调用 deduct/rollback/balance 接口
```

### 依赖说明
- **mysql**: 硬依赖，points-service 必须在 MySQL 健康检查通过后才启动
- points-service 不主动调用其他微服务（定时任务仅查询本地 point_balances 表）
- Docker Compose 中仅声明 `depends_on: mysql`

---

## 4. 健康检查

### 应用层健康检查端点

```
GET /actuator/health

响应（健康）:
HTTP 200
{
  "status": "UP"
}

响应（不健康）:
HTTP 503
{
  "status": "DOWN"
}
```

### Docker Compose 健康检查配置

```yaml
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:8003/actuator/health"]
  interval: 15s
  timeout: 5s
  retries: 3
  start_period: 30s
```

### 健康检查要点
- 检查数据库连接是否正常
- start_period 30 秒，给应用足够的启动时间
- auth-service 和 order-service 调用 points-service 时，可根据健康状态判断是否降级

---

## 5. 网络连接

```
                    awsomeshop-net (bridge)
                    ┌──────────────────────────────────────────┐
                    │                                          │
  api-gateway ──────┤── http://points-service:8003 ──────────→│ points-service
                    │                                          │     │
  auth-service ─────┤── http://points-service:8003 ──────────→│     ├── mysql:3306 (points_db)
                    │   (POST /api/internal/points/init)       │     │
  order-service ────┤── http://points-service:8003 ──────────→│─────┘
                    │   (POST /api/internal/points/deduct)     │
                    │   (POST /api/internal/points/rollback)   │
                    │   (GET /api/internal/points/balance/*)   │
                    └──────────────────────────────────────────┘
```

### 服务间通信路径
| 调用方 | 被调用方 | 协议 | 地址 | 说明 |
|--------|---------|------|------|------|
| api-gateway | points-service | HTTP | http://points-service:8003 | 路由转发 /api/points/*, /api/admin/points/* |
| auth-service | points-service | HTTP | http://points-service:8003 | 注册时初始化积分 |
| order-service | points-service | HTTP | http://points-service:8003 | 兑换扣除/回滚/查询余额 |
| points-service | mysql | TCP | mysql:3306 | 数据库连接（points_db） |

---

## 6. Docker Compose 服务定义

```yaml
  points-service:
    build:
      context: ../points-service
    container_name: awsomeshop-points
    depends_on:
      mysql:
        condition: service_healthy
    environment:
      DB_HOST: mysql
      DB_PORT: 3306
      DB_NAME: ${POINTS_DB_NAME}
      DB_USER: ${POINTS_DB_USER}
      DB_PASSWORD: ${POINTS_DB_PASSWORD}
      SERVER_PORT: 8003
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8003/actuator/health"]
      interval: 15s
      timeout: 5s
      retries: 3
      start_period: 30s
    networks:
      - awsomeshop-net
```

---

## 7. 跨服务地址更新

points-service 端口确定为 8003 后，以下服务的环境变量需同步更新：

| 服务 | 环境变量 | 值 |
|------|---------|-----|
| auth-service | POINTS_SERVICE_URL | http://points-service:8003 |
| api-gateway | POINTS_SERVICE_URL | http://points-service:8003 |
| order-service | POINTS_SERVICE_URL | http://points-service:8003 |

> ⚠️ auth-service 的 POINTS_SERVICE_URL 之前为占位值，现在可确定为 `http://points-service:8003`。
> order-service 和 api-gateway 的配置将在各自的基础设施设计中定义。
