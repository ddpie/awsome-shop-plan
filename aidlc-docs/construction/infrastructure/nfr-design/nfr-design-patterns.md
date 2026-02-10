# Unit 7: infrastructure — NFR 设计模式

---

## 1. 数据持久化模式

### 模式：Named Volume + Bind Mount

| 数据类型 | 持久化方式 | 说明 |
|---------|-----------|------|
| MySQL 数据 | Docker named volume (`mysql-data`) | Docker 管理生命周期，容器删除后数据保留 |
| 产品图片 | Bind mount (`./uploads:/app/uploads`) | 直接映射宿主机目录，便于备份和访问 |

设计要点：
- named volume 由 Docker 管理，路径在 `/var/lib/docker/volumes/`，宿主机可直接备份该目录
- bind mount 使用相对路径，项目目录下的 `uploads/` 文件夹
- 两种方式都满足容器重建后数据不丢失的需求

---

## 2. 服务发现模式

### 模式：Docker DNS 内部解析

所有微服务通过 Docker Compose 服务名进行 DNS 解析，无需额外的服务注册中心。

```
api-gateway → auth-service:8080      (通过服务名解析)
api-gateway → product-service:8080
api-gateway → points-service:8080
api-gateway → order-service:8080
order-service → product-service:8080  (跨服务调用)
order-service → points-service:8080
```

设计要点：
- Docker Compose 自动为同一网络中的服务创建 DNS 记录
- 服务 URL 通过环境变量注入，格式：`http://<service-name>:<port>`
- MVP 阶段无需 Consul/Eureka 等服务注册中心

---

## 3. 健康检查模式

### 模式：Docker Healthcheck + depends_on condition

```
MySQL healthcheck:
  test: mysqladmin ping -h localhost
  interval: 10s
  timeout: 5s
  retries: 5

微服务 depends_on:
  mysql:
    condition: service_healthy
```

启动链：
1. MySQL 启动 → healthcheck 通过
2. 4 个微服务并行启动（depends_on mysql healthy）
3. api-gateway 启动（depends_on 4 个微服务）
4. frontend 启动（depends_on api-gateway）

---

## 4. 网络隔离模式

### 模式：单一 Bridge 网络 + 端口选择性暴露

```
awsomeshop-net (bridge):
  ├── mysql:3306          → 宿主机 3306（开发调试）
  ├── auth-service:8080   → 不暴露
  ├── product-service:8080 → 不暴露
  ├── points-service:8080  → 不暴露
  ├── order-service:8080   → 不暴露
  ├── api-gateway:8080    → 宿主机 8080
  └── frontend:80         → 宿主机 80
```

设计要点：
- 外部只能通过 api-gateway (8080) 和 frontend (80) 访问
- 微服务之间在内部网络自由通信
- MySQL 暴露 3306 仅用于开发阶段数据库管理工具连接

---

## 5. 配置管理模式

### 模式：环境变量 + .env 文件

```
.env                    ← 实际配置（git ignore）
.env.example            ← 模板（git tracked）
docker-compose.yml      ← 引用 ${VAR_NAME}
```

设计要点：
- 所有敏感信息通过环境变量注入
- docker-compose.yml 中使用 `${VAR_NAME}` 引用
- .env 文件不纳入版本控制
- .env.example 提供完整模板和默认值

---

## 6. 数据库初始化模式

### 模式：有序脚本自动执行

```
infrastructure/mysql/
  01-create-databases.sql    ← 创建 database + 用户授权
  02-auth-schema.sql         ← auth_db 表结构
  03-product-schema.sql      ← product_db 表结构
  04-points-schema.sql       ← points_db 表结构
  05-order-schema.sql        ← order_db 表结构
  06-seed-data.sql           ← 种子数据
```

设计要点：
- 利用 MySQL Docker 镜像的 `docker-entrypoint-initdb.d` 机制
- 脚本按文件名排序执行
- 使用 `CREATE DATABASE IF NOT EXISTS` 和 `CREATE TABLE IF NOT EXISTS` 保证幂等性
- 种子数据使用 `INSERT IGNORE` 避免重复插入
