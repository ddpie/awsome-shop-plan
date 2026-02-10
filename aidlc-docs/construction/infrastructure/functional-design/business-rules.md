# Unit 7: infrastructure — 环境配置与种子数据

## 环境变量模板 (.env.example)

```properties
# ===== MySQL =====
MYSQL_ROOT_PASSWORD=awsomeshop_root_2026
MYSQL_PORT=3306

# ===== Database Credentials =====
AUTH_DB_NAME=auth_db
AUTH_DB_USER=auth_user
AUTH_DB_PASSWORD=auth_pass_2026

PRODUCT_DB_NAME=product_db
PRODUCT_DB_USER=product_user
PRODUCT_DB_PASSWORD=product_pass_2026

POINTS_DB_NAME=points_db
POINTS_DB_USER=points_user
POINTS_DB_PASSWORD=points_pass_2026

ORDER_DB_NAME=order_db
ORDER_DB_USER=order_user
ORDER_DB_PASSWORD=order_pass_2026

# ===== JWT =====
JWT_SECRET=awsomeshop-jwt-secret-key-change-in-production
JWT_EXPIRATION=86400

# ===== Service Ports (internal) =====
AUTH_SERVICE_PORT=8080
PRODUCT_SERVICE_PORT=8080
POINTS_SERVICE_PORT=8080
ORDER_SERVICE_PORT=8080
GATEWAY_PORT=8080
FRONTEND_PORT=80

# ===== Service URLs (Docker internal DNS) =====
AUTH_SERVICE_URL=http://auth-service:8080
PRODUCT_SERVICE_URL=http://product-service:8080
POINTS_SERVICE_URL=http://points-service:8080
ORDER_SERVICE_URL=http://order-service:8080
GATEWAY_URL=http://api-gateway:8080

# ===== File Upload =====
UPLOAD_DIR=/app/uploads
MAX_FILE_SIZE=5MB

# ===== Points Distribution =====
DEFAULT_DISTRIBUTION_AMOUNT=100
DEFAULT_DISTRIBUTION_PERIOD=MONTHLY
```

---

## 各服务配置项映射

| 服务 | 需要的环境变量 |
|------|--------------|
| mysql | MYSQL_ROOT_PASSWORD, *_DB_NAME, *_DB_USER, *_DB_PASSWORD |
| auth-service | AUTH_DB_*, JWT_SECRET, JWT_EXPIRATION |
| product-service | PRODUCT_DB_*, UPLOAD_DIR, MAX_FILE_SIZE |
| points-service | POINTS_DB_*, DEFAULT_DISTRIBUTION_* |
| order-service | ORDER_DB_*, PRODUCT_SERVICE_URL, POINTS_SERVICE_URL |
| api-gateway | JWT_SECRET, AUTH_SERVICE_URL, PRODUCT_SERVICE_URL, POINTS_SERVICE_URL, ORDER_SERVICE_URL |
| frontend | GATEWAY_URL（构建时注入或 Nginx 反向代理） |

---

## 种子数据设计

### 默认管理员账号

| 字段 | 值 |
|------|-----|
| username | admin |
| password | admin123（bcrypt 加密存储） |
| name | 系统管理员 |
| employee_id | ADMIN001 |
| role | ADMIN |

### 默认积分发放配置

| config_key | config_value | description |
|-----------|-------------|-------------|
| distribution_amount | 100 | 每次发放积分数量 |
| distribution_period | MONTHLY | 发放周期 |
| distribution_day | 1 | 每月发放日（1号） |
| distribution_enabled | true | 是否启用自动发放 |

### 示例产品分类

| 分类名称 | 父分类 |
|---------|--------|
| 电子产品 | — |
| 生活用品 | — |
| 食品饮料 | — |
| 耳机 | 电子产品 |
| 充电配件 | 电子产品 |
| 家居 | 生活用品 |
| 办公用品 | 生活用品 |
| 零食 | 食品饮料 |
| 饮品 | 食品饮料 |

---

## 配置规则

1. 所有密码和密钥在生产环境必须更换，.env.example 仅提供开发默认值
2. 每个微服务只能访问自己的 database，通过独立的数据库用户和权限控制
3. JWT_SECRET 在 auth-service 和 api-gateway 之间共享，必须保持一致
4. 微服务间通过 Docker 内部 DNS（服务名）通信，不依赖宿主机 IP
5. 前端通过 Nginx 反向代理将 /api/* 请求转发到 api-gateway
