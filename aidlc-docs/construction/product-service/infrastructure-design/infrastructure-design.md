# Unit 3: product-service — 基础设施设计

---

## 1. 容器配置

| 配置项 | 值 | 说明 |
|--------|-----|------|
| 容器名 | awsomeshop-product | 遵循 Unit 7 命名规范 |
| 内部端口 | 8002 | 容器内应用监听端口 |
| 对外暴露 | 否 | 仅通过 Docker 内部网络访问 |
| 网络 | awsomeshop-net (bridge) | Unit 7 定义的共享网络 |
| 构建上下文 | ../product-service | 相对于 infrastructure/ 目录 |
| 数据卷 | ../uploads:/app/uploads | 图片文件持久化 |

---

## 2. 环境变量

| 变量名 | 来源 | 说明 |
|--------|------|------|
| DB_HOST | mysql | Docker DNS 服务名 |
| DB_PORT | 3306 | MySQL 默认端口 |
| DB_NAME | ${PRODUCT_DB_NAME} | .env 文件，值：product_db |
| DB_USER | ${PRODUCT_DB_USER} | .env 文件，值：product_user |
| DB_PASSWORD | ${PRODUCT_DB_PASSWORD} | .env 文件 |
| UPLOAD_DIR | ${UPLOAD_DIR:-/app/uploads} | 图片存储目录，默认 /app/uploads |
| MAX_FILE_SIZE | ${MAX_FILE_SIZE:-5MB} | 文件大小上限，默认 5MB |
| SERVER_PORT | 8002 | 应用监听端口 |

---

## 3. 服务依赖

```
product-service 启动依赖:
  └── mysql (condition: service_healthy)
        └── healthcheck: mysqladmin ping

product-service 运行时依赖:
  └── mysql (product_db) — 数据存储

product-service 无跨服务调用依赖（被 order-service 调用，不主动调用其他服务）
```

### 依赖说明
- **mysql**: 硬依赖，product-service 必须在 MySQL 健康检查通过后才启动
- **无软依赖**: product-service 不主动调用其他微服务
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
  test: ["CMD", "curl", "-f", "http://localhost:8002/actuator/health"]
  interval: 15s
  timeout: 5s
  retries: 3
  start_period: 30s
```

### 健康检查要点
- 检查数据库连接是否正常
- 检查文件存储目录是否可写（可选）
- start_period 30 秒，给应用足够的启动时间
- api-gateway 可通过 `condition: service_healthy` 等待 product-service 就绪

---

## 5. 网络连接

```
                    awsomeshop-net (bridge)
                    ┌─────────────────────────────────────┐
                    │                                     │
  api-gateway ──────┤── http://product-service:8002 ─────→│ product-service
                    │                                     │     │
                    │                                     │     ├── mysql:3306 (product_db)
                    │                                     │     │
  order-service ────┤── http://product-service:8002 ─────→│─────┘ (内部接口调用)
                    │                                     │
                    └─────────────────────────────────────┘
```

### 服务间通信路径
| 调用方 | 被调用方 | 协议 | 地址 | 说明 |
|--------|---------|------|------|------|
| api-gateway | product-service | HTTP | http://product-service:8002 | 路由转发 /api/products/*, /api/categories/*, /api/files/*, /api/admin/products/*, /api/admin/categories/* |
| order-service | product-service | HTTP | http://product-service:8002 | 内部接口 /api/internal/products/* |
| product-service | mysql | TCP | mysql:3306 | 数据库连接（product_db） |

---

## 6. 数据卷

| 卷 | 容器路径 | 宿主机路径 | 说明 |
|----|---------|-----------|------|
| 图片存储 | /app/uploads | ../uploads | 产品图片文件持久化 |

### 卷挂载说明
- 使用 bind mount（非 Docker named volume），方便开发阶段直接查看文件
- 宿主机路径 `../uploads` 相对于 `infrastructure/` 目录，即工作区根目录下的 `uploads/`
- 容器重启不丢失图片文件
- 多个容器实例（如果未来扩展）可共享同一目录

---

## 7. Docker Compose 服务定义（更新）

> 以下为 product-service 在 docker-compose.yml 中的更新定义，端口从 8080 改为 8002，新增健康检查和 SERVER_PORT。

```yaml
  product-service:
    build:
      context: ../product-service
    container_name: awsomeshop-product
    depends_on:
      mysql:
        condition: service_healthy
    environment:
      DB_HOST: mysql
      DB_PORT: 3306
      DB_NAME: ${PRODUCT_DB_NAME}
      DB_USER: ${PRODUCT_DB_USER}
      DB_PASSWORD: ${PRODUCT_DB_PASSWORD}
      UPLOAD_DIR: ${UPLOAD_DIR:-/app/uploads}
      MAX_FILE_SIZE: ${MAX_FILE_SIZE:-5MB}
      SERVER_PORT: 8002
    volumes:
      - ../uploads:/app/uploads
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8002/actuator/health"]
      interval: 15s
      timeout: 5s
      retries: 3
      start_period: 30s
    networks:
      - awsomeshop-net
```

### 与 Unit 7 基础设施的差异
| 配置项 | Unit 7 原始定义 | 本次更新 |
|--------|----------------|---------|
| 内部端口 | 8080（隐含） | 8002（显式 SERVER_PORT） |
| 健康检查 | 无 | 新增 healthcheck |
| api-gateway 路由地址 | http://product-service:8080 | 需更新为 http://product-service:8002 |

> ⚠️ 注意：api-gateway 的 `PRODUCT_SERVICE_URL` 环境变量需从 `http://product-service:8080` 更新为 `http://product-service:8002`。此变更将在 api-gateway 基础设施设计中统一处理。
> 同样，order-service 的 `PRODUCT_SERVICE_URL` 也需更新为 `http://product-service:8002`。
