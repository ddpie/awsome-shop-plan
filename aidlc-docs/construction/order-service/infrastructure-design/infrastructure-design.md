# Unit 5: order-service — 基础设施设计

---

## 1. 容器配置

| 配置项 | 值 | 说明 |
|--------|-----|------|
| 容器名 | awsomeshop-order | 遵循 Unit 7 命名规范 |
| 内部端口 | 8004 | 容器内应用监听端口 |
| 对外暴露 | 否 | 仅通过 Docker 内部网络访问 |
| 网络 | awsomeshop-net (bridge) | Unit 7 定义的共享网络 |
| 构建上下文 | ../order-service | 相对于 infrastructure/ 目录 |

---

## 2. 环境变量

| 变量名 | 来源 | 说明 |
|--------|------|------|
| DB_HOST | mysql | Docker DNS 服务名 |
| DB_PORT | 3306 | MySQL 默认端口 |
| DB_NAME | ${ORDER_DB_NAME} | .env 文件，值：order_db |
| DB_USER | ${ORDER_DB_USER} | .env 文件，值：order_user |
| DB_PASSWORD | ${ORDER_DB_PASSWORD} | .env 文件 |
| SERVER_PORT | 8004 | 应用监听端口 |
| PRODUCT_SERVICE_URL | http://product-service:8002 | product-service 基础 URL |
| POINTS_SERVICE_URL | http://points-service:8003 | points-service 基础 URL |
| CONNECT_TIMEOUT | 1000 | 跨服务连接超时（ms） |
| READ_TIMEOUT | 2000 | 跨服务读取超时（ms） |

### .env 文件变量（已在 Unit 7 中定义）

```env
# order-service
ORDER_DB_NAME=order_db
ORDER_DB_USER=order_user
ORDER_DB_PASSWORD=order_pass_2026
```

---

## 3. 服务依赖

```
order-service 启动依赖:
  └── mysql (condition: service_healthy)
        └── healthcheck: mysqladmin ping

order-service 运行时依赖:
  ├── mysql (order_db) — 数据存储
  ├── product-service (:8002) — 查询产品、扣减/恢复库存
  └── points-service (:8003) — 查询余额、扣除/回滚积分

被依赖方:
  └── api-gateway — 路由转发 /api/orders/*, /api/admin/orders/*
```

### 依赖说明
- **mysql**: 硬依赖，order-service 必须在 MySQL 健康检查通过后才启动
- **product-service / points-service**: 运行时软依赖，通过 HTTP 调用，不在 depends_on 中声明
- Docker Compose 中仅声明 `depends_on: mysql`（与其他微服务一致）
- 跨服务调用失败时由 RetryableHttpClient 处理重试和补偿

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
  test: ["CMD", "curl", "-f", "http://localhost:8004/actuator/health"]
  interval: 15s
  timeout: 5s
  retries: 3
  start_period: 30s
```

### 健康检查要点
- 检查数据库连接是否正常
- start_period 30 秒，给应用足够的启动时间
- api-gateway 路由到 order-service 时，可根据健康状态判断是否降级

---

## 5. 网络连接

```
                    awsomeshop-net (bridge)
                    ┌──────────────────────────────────────────┐
                    │                                          │
  api-gateway ──────┤── http://order-service:8004 ───────────→│ order-service
                    │   (路由 /api/orders/*, /api/admin/orders/*)│     │
                    │                                          │     ├── mysql:3306 (order_db)
                    │                                          │     │
  order-service ────┤── http://product-service:8002 ─────────→│ product-service
                    │   (查询产品/扣减库存/恢复库存)              │
                    │                                          │
  order-service ────┤── http://points-service:8003 ──────────→│ points-service
                    │   (查询余额/扣除积分/回滚积分)              │
                    └──────────────────────────────────────────┘
```

### 服务间通信路径

| 调用方 | 被调用方 | 协议 | 地址 | 说明 |
|--------|---------|------|------|------|
| api-gateway | order-service | HTTP | http://order-service:8004 | 路由转发 /api/orders/*, /api/admin/orders/* |
| order-service | product-service | HTTP | http://product-service:8002 | 查询产品、扣减/恢复库存 |
| order-service | points-service | HTTP | http://points-service:8003 | 查询余额、扣除/回滚积分 |
| order-service | mysql | TCP | mysql:3306 | 数据库连接（order_db） |

---

## 6. Docker Compose 服务定义

```yaml
  order-service:
    build:
      context: ../order-service
    container_name: awsomeshop-order
    depends_on:
      mysql:
        condition: service_healthy
    environment:
      DB_HOST: mysql
      DB_PORT: 3306
      DB_NAME: ${ORDER_DB_NAME}
      DB_USER: ${ORDER_DB_USER}
      DB_PASSWORD: ${ORDER_DB_PASSWORD}
      SERVER_PORT: 8004
      PRODUCT_SERVICE_URL: http://product-service:8002
      POINTS_SERVICE_URL: http://points-service:8003
      CONNECT_TIMEOUT: 1000
      READ_TIMEOUT: 2000
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8004/actuator/health"]
      interval: 15s
      timeout: 5s
      retries: 3
      start_period: 30s
    networks:
      - awsomeshop-net
```

---

## 7. 跨服务地址更新

order-service 端口确定为 8004 后，以下服务的环境变量需同步更新：

| 服务 | 环境变量 | 值 |
|------|---------|-----|
| api-gateway | ORDER_SERVICE_URL | http://order-service:8004 |

### Unit 7 Docker Compose 需更新的配置

Unit 7 `infrastructure-design.md` 中 order-service 的 Docker Compose 定义需更新：
- `PRODUCT_SERVICE_URL`: `http://product-service:8080` → `http://product-service:8002`
- `POINTS_SERVICE_URL`: `http://points-service:8080` → `http://points-service:8003`
- 新增 `SERVER_PORT: 8004`
- 新增 `CONNECT_TIMEOUT: 1000`
- 新增 `READ_TIMEOUT: 2000`
- 新增 healthcheck 配置

api-gateway 的 `ORDER_SERVICE_URL` 也需从 `http://order-service:8080` 更新为 `http://order-service:8004`。

> ⚠️ 这些更新将在 Unit 7 的 Docker Compose 配置中同步修正。
