# Unit 7: infrastructure — 逻辑组件

---

## 组件清单

| 组件 | 类型 | 职责 |
|------|------|------|
| docker-compose.yml | 编排配置 | 定义所有服务、网络、卷 |
| .env.example | 配置模板 | 环境变量模板 |
| mysql/01-create-databases.sql | 初始化脚本 | 创建 4 个 database 和用户授权 |
| mysql/02-auth-schema.sql | 初始化脚本 | auth_db 表结构 |
| mysql/03-product-schema.sql | 初始化脚本 | product_db 表结构 |
| mysql/04-points-schema.sql | 初始化脚本 | points_db 表结构 |
| mysql/05-order-schema.sql | 初始化脚本 | order_db 表结构 |
| mysql/06-seed-data.sql | 初始化脚本 | 种子数据 |

---

## 目录结构

```
infrastructure/
├── docker-compose.yml
├── .env.example
└── mysql/
    ├── 01-create-databases.sql
    ├── 02-auth-schema.sql
    ├── 03-product-schema.sql
    ├── 04-points-schema.sql
    ├── 05-order-schema.sql
    └── 06-seed-data.sql
```

---

## Docker Compose 服务定义概要

### mysql
- 镜像：`mysql:8.4`
- 端口：3306:3306
- 卷：`mysql-data:/var/lib/mysql`，`./mysql:/docker-entrypoint-initdb.d`
- 环境变量：MYSQL_ROOT_PASSWORD
- 健康检查：`mysqladmin ping`
- 字符集：`--character-set-server=utf8mb4 --collation-server=utf8mb4_unicode_ci`

### auth-service
- 构建：`../auth-service`
- 端口：不暴露（内部 8080）
- 依赖：mysql (service_healthy)
- 环境变量：AUTH_DB_*, JWT_SECRET, JWT_EXPIRATION

### product-service
- 构建：`../product-service`
- 端口：不暴露（内部 8080）
- 依赖：mysql (service_healthy)
- 卷：`../uploads:/app/uploads`
- 环境变量：PRODUCT_DB_*, UPLOAD_DIR, MAX_FILE_SIZE

### points-service
- 构建：`../points-service`
- 端口：不暴露（内部 8080）
- 依赖：mysql (service_healthy)
- 环境变量：POINTS_DB_*

### order-service
- 构建：`../order-service`
- 端口：不暴露（内部 8080）
- 依赖：mysql (service_healthy)
- 环境变量：ORDER_DB_*, PRODUCT_SERVICE_URL, POINTS_SERVICE_URL

### api-gateway
- 构建：`../api-gateway`
- 端口：8080:8080
- 依赖：auth-service, product-service, points-service, order-service
- 环境变量：JWT_SECRET, *_SERVICE_URL

### frontend
- 构建：`../awsomeshop-frontend`
- 端口：80:80
- 依赖：api-gateway

---

## NFR 需求覆盖映射

| NFR 需求 | 对应设计模式/组件 |
|---------|-----------------|
| NFR-INFRA-001 数据持久化 | Named Volume (mysql-data) |
| NFR-INFRA-002 宿主机备份 | Named Volume 宿主机路径可备份 |
| NFR-INFRA-003 幂等初始化 | IF NOT EXISTS + INSERT IGNORE |
| NFR-INFRA-004 独立用户授权 | 01-create-databases.sql |
| NFR-INFRA-005 一键启动 | docker-compose.yml |
| NFR-INFRA-006 启动顺序 | depends_on + condition |
| NFR-INFRA-007 MySQL 健康检查 | healthcheck: mysqladmin ping |
| NFR-INFRA-009 图片持久化 | Bind mount (uploads) |
| NFR-INFRA-010 敏感配置 | .env + 环境变量注入 |
| NFR-INFRA-011 端口隔离 | 仅暴露 8080/80 |
| NFR-INFRA-013 配置模板 | .env.example |
| NFR-INFRA-014 网络隔离 | awsomeshop-net bridge |
| NFR-INFRA-016 日志输出 | stdout/stderr → docker logs |
| NFR-INFRA-018 集中配置 | .env 文件 |
| NFR-INFRA-019 脚本分文件 | 6 个有序 SQL 文件 |
