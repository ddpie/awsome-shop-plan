# Unit 7: infrastructure — 基础设施设计

---

## 1. 项目目录结构

```
infrastructure/
├── docker-compose.yml          # Docker Compose 编排（name: awsomeshop）
├── .env.example                # 环境变量模板
├── .env                        # 实际环境变量（git ignore）
├── mysql/
│   ├── 01-create-databases.sql # 创建 database + 用户授权
│   ├── 02-auth-schema.sql      # auth_db 表结构
│   ├── 03-product-schema.sql   # product_db 表结构
│   ├── 04-points-schema.sql    # points_db 表结构
│   ├── 05-order-schema.sql     # order_db 表结构
│   └── 06-seed-data.sql        # 种子数据
└── nginx/
    └── default.conf            # 前端 Nginx 配置（SPA + API 反向代理）
```

---

## 2. Docker Compose 完整配置

```yaml
name: awsomeshop

services:

  mysql:
    image: mysql:8.4
    container_name: awsomeshop-mysql
    ports:
      - "${MYSQL_PORT:-3306}:3306"
    environment:
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
    volumes:
      - mysql-data:/var/lib/mysql
      - ./mysql:/docker-entrypoint-initdb.d
    command: >
      --character-set-server=utf8mb4
      --collation-server=utf8mb4_unicode_ci
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 30s
    networks:
      - awsomeshop-net

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
    networks:
      - awsomeshop-net

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
    volumes:
      - ../uploads:/app/uploads
    networks:
      - awsomeshop-net

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
    networks:
      - awsomeshop-net

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

  frontend:
    build:
      context: ../awsomeshop-frontend
    container_name: awsomeshop-frontend
    ports:
      - "${FRONTEND_PORT:-3000}:80"
    depends_on:
      - api-gateway
    volumes:
      - ./nginx/default.conf:/etc/nginx/conf.d/default.conf:ro
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost/health"]
      interval: 15s
      timeout: 5s
      retries: 3
      start_period: 10s
    networks:
      - awsomeshop-net

volumes:
  mysql-data:

networks:
  awsomeshop-net:
    driver: bridge
```

---

## 3. Nginx 配置（前端 SPA + API 反向代理）

```nginx
# infrastructure/nginx/default.conf

server {
    listen 80;
    server_name localhost;

    root /usr/share/nginx/html;
    index index.html;

    # Gzip 压缩
    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml;
    gzip_min_length 1000;

    # SPA 路由：所有非文件请求回退到 index.html
    location / {
        try_files $uri $uri/ /index.html;
    }

    # API 反向代理：/api/* → api-gateway
    location /api/ {
        proxy_pass http://api-gateway:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # 超时配置
        proxy_connect_timeout 10s;
        proxy_read_timeout 30s;

        # 文件上传大小限制
        client_max_body_size 10m;
    }

    # 静态资源：开发阶段不缓存
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires -1;
        add_header Cache-Control "no-cache, no-store, must-revalidate";
        add_header Pragma "no-cache";
    }

    # 健康检查端点
    location /health {
        access_log off;
        return 200 "OK";
        add_header Content-Type text/plain;
    }
}
```

---

## 4. 环境变量模板 (.env.example)

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

# ===== Service Ports =====
GATEWAY_PORT=8080
FRONTEND_PORT=3000

# ===== File Upload =====
UPLOAD_DIR=/app/uploads
MAX_FILE_SIZE=5MB
```

---

## 5. 容器命名规范

| 服务 | 容器名 | 说明 |
|------|--------|------|
| mysql | awsomeshop-mysql | 数据库 |
| auth-service | awsomeshop-auth | 认证服务 |
| product-service | awsomeshop-product | 产品服务 |
| points-service | awsomeshop-points | 积分服务 |
| order-service | awsomeshop-order | 兑换服务 |
| api-gateway | awsomeshop-gateway | API 网关 |
| frontend | awsomeshop-frontend | 前端应用 |

Docker Compose 项目名 `awsomeshop` 会自动为网络和卷添加前缀：
- 网络：`awsomeshop_awsomeshop-net`
- 卷：`awsomeshop_mysql-data`
