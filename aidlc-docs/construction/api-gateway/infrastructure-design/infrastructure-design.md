# Unit 6: api-gateway — 基础设施设计

---

## 1. 容器配置

### 基本信息

| 配置项 | 值 |
|--------|-----|
| 服务名 | api-gateway |
| 容器名 | awsomeshop-gateway |
| 内部端口 | 8080 |
| 对外暴露 | ${GATEWAY_PORT:-8080}:8080 |
| 网络 | awsomeshop-net |

### Docker Compose 服务定义

```yaml
api-gateway:
  build:
    context: ../api-gateway
  container_name: awsomeshop-gateway
  ports:
    - "${GATEWAY_PORT:-8080}:8080"
  depends_on:
    - auth-service
    - product-service
    - points-service
    - order-service
  environment:
    SERVER_PORT: 8080
    JWT_SECRET: ${JWT_SECRET}
    AUTH_SERVICE_URL: http://auth-service:8001
    PRODUCT_SERVICE_URL: http://product-service:8002
    POINTS_SERVICE_URL: http://points-service:8003
    ORDER_SERVICE_URL: http://order-service:8004
    CONNECT_TIMEOUT: 1000
    READ_TIMEOUT: 2000
  healthcheck:
    test: ["CMD", "curl", "-f", "http://localhost:8080/actuator/health"]
    interval: 15s
    timeout: 5s
    retries: 3
    start_period: 20s
  networks:
    - awsomeshop-net
```

---

## 2. 环境变量

| 变量名 | 必填 | 默认值 | 说明 |
|--------|------|--------|------|
| SERVER_PORT | 否 | 8080 | 服务端口 |
| JWT_SECRET | 是 | - | JWT 签名密钥（与 auth-service 共享） |
| AUTH_SERVICE_URL | 否 | http://auth-service:8001 | 认证服务地址 |
| PRODUCT_SERVICE_URL | 否 | http://product-service:8002 | 产品服务地址 |
| POINTS_SERVICE_URL | 否 | http://points-service:8003 | 积分服务地址 |
| ORDER_SERVICE_URL | 否 | http://order-service:8004 | 兑换服务地址 |
| CONNECT_TIMEOUT | 否 | 1000 | 连接超时（毫秒） |
| READ_TIMEOUT | 否 | 2000 | 读取超时（毫秒） |

### 启动校验
- JWT_SECRET 为空或未配置 → 启动失败（快速失败）

---

## 3. 服务依赖

### 启动依赖

| 依赖服务 | 依赖类型 | 说明 |
|---------|---------|------|
| auth-service | 软依赖 | 路由转发目标，不可达时返回 502 |
| product-service | 软依赖 | 路由转发目标，不可达时返回 502 |
| points-service | 软依赖 | 路由转发目标，不可达时返回 502 |
| order-service | 软依赖 | 路由转发目标，不可达时返回 502 |

说明：
- api-gateway 不依赖数据库
- 下游服务为软依赖，网关可以在下游服务未就绪时启动
- 下游服务不可达时，网关返回 502 错误

### 被依赖

| 依赖方 | 说明 |
|--------|------|
| frontend (Nginx) | 反向代理 /api/* 到 api-gateway |

---

## 4. 健康检查配置

```yaml
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:8080/actuator/health"]
  interval: 15s      # 检查间隔
  timeout: 5s        # 超时时间
  retries: 3         # 失败重试次数
  start_period: 20s  # 启动等待时间
```

### 健康检查端点
- 路径：`/actuator/health`
- 方法：GET
- 成功响应：HTTP 200
- 说明：与其他微服务保持一致

---

## 5. 网络连接

### 内部网络
- 网络名：awsomeshop-net
- 驱动：bridge
- 所有服务在同一网络内通过服务名互相访问

### 端口映射

| 端口 | 方向 | 说明 |
|------|------|------|
| 8080 | 对外暴露 | 通过 ${GATEWAY_PORT:-8080} 映射到宿主机 |
| 8080 | 内部 | Docker 网络内其他服务访问 |

### 访问路径
- 外部访问：`http://localhost:8080/api/*`
- 内部访问：`http://api-gateway:8080/api/*`
- 前端 Nginx 代理：`http://api-gateway:8080`

---

## 6. 目录结构

```
api-gateway/
├── src/
│   └── main/
│       └── [language]/
│           └── com/awsomeshop/gateway/
│               ├── GatewayApplication.[ext]
│               ├── filter/
│               ├── security/
│               ├── routing/
│               ├── processor/
│               ├── config/
│               ├── handler/
│               └── model/
├── src/
│   └── test/
│       └── [language]/
│           └── com/awsomeshop/gateway/
│               └── ...
├── Dockerfile
└── [build-file]
```

### Dockerfile 示例

```dockerfile
# 基础镜像将在实现阶段根据技术框架确定
FROM [base-image]

WORKDIR /app

# 复制构建产物
COPY [build-output] .

# 暴露端口
EXPOSE 8080

# 健康检查依赖 curl
RUN [install-curl-if-needed]

# 启动命令
CMD [start-command]
```

---

## 7. Unit 7 Docker Compose 更新

需要更新 `infrastructure/docker-compose.yml` 中 api-gateway 服务的配置：

### 更新前
```yaml
api-gateway:
  build:
    context: ../api-gateway
  container_name: awsomeshop-gateway
  ports:
    - "${GATEWAY_PORT:-8080}:8080"
  depends_on:
    - auth-service
    - product-service
    - points-service
    - order-service
  environment:
    JWT_SECRET: ${JWT_SECRET}
    AUTH_SERVICE_URL: http://auth-service:8080
    PRODUCT_SERVICE_URL: http://product-service:8080
    POINTS_SERVICE_URL: http://points-service:8080
    ORDER_SERVICE_URL: http://order-service:8004
  networks:
    - awsomeshop-net
```

### 更新后
```yaml
api-gateway:
  build:
    context: ../api-gateway
  container_name: awsomeshop-gateway
  ports:
    - "${GATEWAY_PORT:-8080}:8080"
  depends_on:
    - auth-service
    - product-service
    - points-service
    - order-service
  environment:
    SERVER_PORT: 8080
    JWT_SECRET: ${JWT_SECRET}
    AUTH_SERVICE_URL: http://auth-service:8001
    PRODUCT_SERVICE_URL: http://product-service:8002
    POINTS_SERVICE_URL: http://points-service:8003
    ORDER_SERVICE_URL: http://order-service:8004
    CONNECT_TIMEOUT: 1000
    READ_TIMEOUT: 2000
  healthcheck:
    test: ["CMD", "curl", "-f", "http://localhost:8080/actuator/health"]
    interval: 15s
    timeout: 5s
    retries: 3
    start_period: 20s
  networks:
    - awsomeshop-net
```

### 变更摘要
| 配置项 | 变更前 | 变更后 |
|--------|--------|--------|
| SERVER_PORT | 无 | 8080 |
| AUTH_SERVICE_URL | http://auth-service:8080 | http://auth-service:8001 |
| PRODUCT_SERVICE_URL | http://product-service:8080 | http://product-service:8002 |
| POINTS_SERVICE_URL | http://points-service:8080 | http://points-service:8003 |
| CONNECT_TIMEOUT | 无 | 1000 |
| READ_TIMEOUT | 无 | 2000 |
| healthcheck | 无 | 新增 |
