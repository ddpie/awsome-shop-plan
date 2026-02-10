# Unit 2: auth-service — 部署架构

---

## 1. 部署拓扑

```
┌─────────────────────────────────────────────────────────┐
│                  Docker Host (开发机)                      │
│                                                         │
│  ┌──────────────┐    ┌──────────────┐                   │
│  │   frontend    │    │  api-gateway  │ ← :8080 (宿主机) │
│  │   :80 (宿主机) │    │   :8080       │                   │
│  └──────┬───────┘    └──────┬───────┘                   │
│         │                   │                           │
│         │    ┌──────────────┼──────────────┐            │
│         │    │              │              │            │
│         ▼    ▼              ▼              ▼            │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐       │
│  │auth-service │  │product-svc │  │points-svc  │ ...   │
│  │  :8001      │  │  :端口     │  │  :端口     │       │
│  └──────┬─────┘  └────────────┘  └────────────┘       │
│         │                                               │
│         ▼                                               │
│  ┌────────────┐                                         │
│  │   MySQL     │ ← :3306 (宿主机，开发调试用)              │
│  │  :3306      │                                         │
│  └────────────┘                                         │
│                                                         │
│  网络: awsomeshop-net (bridge)                           │
└─────────────────────────────────────────────────────────┘
```

---

## 2. auth-service 启动流程

```
Docker Compose Up
  │
  ├── 1. MySQL 启动
  │     └── healthcheck: mysqladmin ping (每10s，最多5次)
  │
  ├── 2. MySQL 健康 → auth-service 启动
  │     ├── 加载环境变量（DB_HOST, JWT_SECRET 等）
  │     ├── 应用监听 0.0.0.0:8001
  │     ├── 建立数据库连接池 → mysql:3306/auth_db
  │     └── healthcheck: curl http://localhost:8001/actuator/health (每15s)
  │
  └── 3. auth-service 就绪
        └── 可接收来自 api-gateway 和其他微服务的请求
```

---

## 3. 请求流转路径

### 3.1 用户注册

```
浏览器 → :80 (Nginx)
  → /api/auth/register
  → proxy_pass http://api-gateway:8080
    → api-gateway 判断为公开端点，无需认证
    → 路由到 http://auth-service:8001/api/auth/register
      → AuthController.register()
        → AuthService: 参数校验 → 唯一性校验 → bcrypt加密 → 保存用户
        → PointsClient: POST http://points-service:8003/api/internal/points/init
          ├── 成功 → 返回 UserResponse
          └── 失败 → 降级，仍返回 UserResponse
```

### 3.2 用户登录

```
浏览器 → :80 (Nginx)
  → /api/auth/login
  → proxy_pass http://api-gateway:8080
    → api-gateway 判断为公开端点，无需认证
    → 路由到 http://auth-service:8001/api/auth/login
      → AuthController.login()
        → AuthService: 查询用户 → 状态检查 → bcrypt校验 → JWT生成
        → 返回 TokenResponse { token, userId, username, role, expiresIn }
```

### 3.3 获取当前用户信息

```
浏览器 → :80 (Nginx)
  → /api/users/me (Header: Authorization: Bearer <token>)
  → proxy_pass http://api-gateway:8080
    → api-gateway: JWT 校验 → 附加 X-User-Id, X-User-Role
    → 路由到 http://auth-service:8001/api/users/me
      → UserController.getCurrentUser()
        → UserService: 按 X-User-Id 查询用户
        → 返回 UserResponse
```

### 3.4 管理员用户管理

```
浏览器 → :80 (Nginx)
  → /api/admin/users (Header: Authorization: Bearer <token>)
  → proxy_pass http://api-gateway:8080
    → api-gateway: JWT 校验 → 角色校验 (ADMIN) → 附加 X-User-Id, X-User-Role
    → 路由到 http://auth-service:8001/api/admin/users
      → UserController.listUsers() / updateUser()
        → UserService: 分页查询 / 更新状态
        → 返回 PageResponse<UserResponse> / UserResponse
```

---

## 4. 端口映射汇总

| 服务 | 容器内端口 | 宿主机端口 | 说明 |
|------|-----------|-----------|------|
| auth-service | 8001 | — | 不对外暴露 |
| mysql | 3306 | 3306 | 开发调试用 |
| api-gateway | 8080 | 8080 | 统一 API 入口 |
| frontend | 80 | 80 | 用户访问入口 |

---

## 5. 数据卷

auth-service 无需挂载数据卷。数据持久化通过 MySQL 容器的 `mysql-data` 卷实现。

---

## 6. 故障场景与恢复

| 故障场景 | 影响 | 恢复方式 |
|---------|------|---------|
| auth-service 容器崩溃 | 登录/注册不可用 | Docker 自动重启（可配置 restart: unless-stopped） |
| MySQL 不可用 | auth-service 健康检查失败 | 等待 MySQL 恢复，连接池自动重连 |
| points-service 不可用 | 注册时积分初始化失败 | 降级处理，积分在首次查询时补偿初始化 |
| api-gateway 不可用 | 所有 API 请求不可达 | 重启 api-gateway 容器 |

---

## 7. 开发调试说明

### 本地独立运行（不通过 Docker）
开发阶段可直接在本地运行 auth-service，连接宿主机 MySQL（端口 3306 已暴露）：

```properties
DB_HOST=localhost
DB_PORT=3306
DB_NAME=auth_db
DB_USER=auth_user
DB_PASSWORD=auth_pass_2026
JWT_SECRET=awsomeshop-jwt-secret-key-change-in-production
JWT_EXPIRATION=86400
SERVER_PORT=8001
```

### Docker 内运行
通过 `docker compose up auth-service` 启动，自动连接 Docker 网络内的 MySQL。
