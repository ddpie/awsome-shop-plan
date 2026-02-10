# Unit 2: auth-service — 基础设施设计

---

## 1. 容器配置

| 配置项 | 值 | 说明 |
|--------|-----|------|
| 容器名 | awsomeshop-auth | 遵循 Unit 7 命名规范 |
| 内部端口 | 8001 | 容器内应用监听端口 |
| 对外暴露 | 否 | 仅通过 Docker 内部网络访问 |
| 网络 | awsomeshop-net (bridge) | Unit 7 定义的共享网络 |
| 构建上下文 | ../auth-service | 相对于 infrastructure/ 目录 |

---

## 2. 环境变量

| 变量名 | 来源 | 说明 |
|--------|------|------|
| DB_HOST | mysql | Docker DNS 服务名 |
| DB_PORT | 3306 | MySQL 默认端口 |
| DB_NAME | ${AUTH_DB_NAME} | .env 文件，值：auth_db |
| DB_USER | ${AUTH_DB_USER} | .env 文件，值：auth_user |
| DB_PASSWORD | ${AUTH_DB_PASSWORD} | .env 文件 |
| JWT_SECRET | ${JWT_SECRET} | .env 文件，与 api-gateway 共享 |
| JWT_EXPIRATION | ${JWT_EXPIRATION} | .env 文件，默认 86400 秒 |
| POINTS_SERVICE_URL | http://points-service:8003 | 积分服务内部地址 |
| SERVER_PORT | 8001 | 应用监听端口 |

> 注1：points-service 端口已确定为 8003。

---

## 3. 服务依赖

```
auth-service 启动依赖:
  └── mysql (condition: service_healthy)
        └── healthcheck: mysqladmin ping

auth-service 运行时依赖:
  ├── mysql (auth_db) — 数据存储
  └── points-service — 注册时初始化积分（可降级）
```

### 依赖说明
- **mysql**: 硬依赖，auth-service 必须在 MySQL 健康检查通过后才启动
- **points-service**: 软依赖，调用失败不影响 auth-service 正常运行（降级策略）
- Docker Compose 中仅声明 `depends_on: mysql`，不声明对 points-service 的依赖（避免启动顺序耦合）

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
  test: ["CMD", "curl", "-f", "http://localhost:8001/actuator/health"]
  interval: 15s
  timeout: 5s
  retries: 3
  start_period: 30s
```

### 健康检查要点
- 检查数据库连接是否正常
- start_period 30 秒，给应用足够的启动时间
- 其他依赖 auth-service 的服务（如 api-gateway）可通过 `condition: service_healthy` 等待

---

## 5. 网络连接

```
                    awsomeshop-net (bridge)
                    ┌─────────────────────────────────────┐
                    │                                     │
  api-gateway ──────┤── http://auth-service:8001 ────────→│ auth-service
                    │                                     │     │
                    │                                     │     ├── mysql:3306 (auth_db)
                    │                                     │     │
  points-service ←──┤── http://points-service:8003 ←──────│─────┘ (注册时调用)
                    │                                     │
                    └─────────────────────────────────────┘
```

### 服务间通信路径
| 调用方 | 被调用方 | 协议 | 地址 | 说明 |
|--------|---------|------|------|------|
| api-gateway | auth-service | HTTP | http://auth-service:8001 | 路由转发 /api/auth/*, /api/users/*, /api/admin/users/* |
| auth-service | points-service | HTTP | http://points-service:8003 | 注册时初始化积分（POST /api/internal/points/init） |
| auth-service | mysql | TCP | mysql:3306 | 数据库连接（auth_db） |

---

## 6. Docker Compose 服务定义（更新）

> 以下为 auth-service 在 docker-compose.yml 中的更新定义，端口从 8080 改为 8001，新增健康检查。

```yaml
  auth-service:
    build:
      context: ../auth-service
    container_name: awsomeshop-auth
    depends_on:
      mysql:
        condition: service_healthy
    environment:
      DB_HOST: mysql
      DB_PORT: 3306
      DB_NAME: ${AUTH_DB_NAME}
      DB_USER: ${AUTH_DB_USER}
      DB_PASSWORD: ${AUTH_DB_PASSWORD}
      JWT_SECRET: ${JWT_SECRET}
      JWT_EXPIRATION: ${JWT_EXPIRATION}
      SERVER_PORT: 8001
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8001/actuator/health"]
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
| 内部端口 | 8080（隐含） | 8001（显式 SERVER_PORT） |
| 健康检查 | 无 | 新增 healthcheck |
| api-gateway 路由地址 | http://auth-service:8080 | 需更新为 http://auth-service:8001 |

> ⚠️ 注意：api-gateway 的 `AUTH_SERVICE_URL` 环境变量需从 `http://auth-service:8080` 更新为 `http://auth-service:8001`。此变更将在 api-gateway 基础设施设计中统一处理。
