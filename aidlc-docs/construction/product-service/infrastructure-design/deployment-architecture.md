# Unit 3: product-service — 部署架构

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
│  │  :8001      │  │  :8002     │  │  :端口     │       │
│  └────────────┘  └──────┬─────┘  └────────────┘       │
│                         │                               │
│                    ┌────┴────┐                          │
│                    │         │                          │
│                    ▼         ▼                          │
│             ┌──────────┐  ┌──────────┐                  │
│             │  MySQL    │  │ uploads/ │                  │
│             │  :3306    │  │ (卷挂载)  │                  │
│             └──────────┘  └──────────┘                  │
│                                                         │
│  网络: awsomeshop-net (bridge)                           │
└─────────────────────────────────────────────────────────┘
```

---

## 2. product-service 启动流程

```
Docker Compose Up
  │
  ├── 1. MySQL 启动
  │     └── healthcheck: mysqladmin ping (每10s，最多5次)
  │
  ├── 2. MySQL 健康 → product-service 启动
  │     ├── 加载环境变量（DB_HOST, UPLOAD_DIR, MAX_FILE_SIZE 等）
  │     ├── 应用监听 0.0.0.0:8002
  │     ├── 建立数据库连接池 → mysql:3306/product_db
  │     ├── 检查/创建上传目录 /app/uploads
  │     └── healthcheck: curl http://localhost:8002/actuator/health (每15s)
  │
  └── 3. product-service 就绪
        └── 可接收来自 api-gateway 和 order-service 的请求
```

---

## 3. 请求流转路径

### 3.1 员工浏览产品列表

```
浏览器 → :80 (Nginx)
  → /api/products?page=0&size=20&categoryId=1
  → proxy_pass http://api-gateway:8080
    → api-gateway: JWT 校验 → 附加 X-User-Id, X-User-Role
    → 路由到 http://product-service:8002/api/products?...
      → ProductController.listProducts()
        → ProductService: 分页查询 ACTIVE 产品
        → 返回 PageResponse<ProductResponse>
```

### 3.2 管理员创建产品

```
浏览器 → :80 (Nginx)
  → POST /api/admin/products (Header: Authorization: Bearer <token>)
  → proxy_pass http://api-gateway:8080
    → api-gateway: JWT 校验 → 角色校验 (ADMIN) → 附加 X-User-Id, X-User-Role
    → 路由到 http://product-service:8002/api/admin/products
      → AdminProductController.createProduct()
        → ProductService: 参数校验 → 分类校验 → 创建产品
        → 返回 ProductResponse
```

### 3.3 图片上传

```
浏览器 → :80 (Nginx, client_max_body_size 10m)
  → POST /api/files/upload (multipart/form-data)
  → proxy_pass http://api-gateway:8080
    → api-gateway: JWT 校验
    → 路由到 http://product-service:8002/api/files/upload
      → FileController.uploadFile()
        → FileService: 大小校验(≤5MB) → 类型校验 → UUID重命名 → 保存到 /app/uploads
        → 返回 FileResponse { url, filename }
```

### 3.4 图片访问

```
浏览器 → :80 (Nginx)
  → /api/files/{filename}
  → proxy_pass http://api-gateway:8080
    → api-gateway: JWT 校验
    → 路由到 http://product-service:8002/api/files/{filename}
      → FileController.getFile()
        → FileService: 从 /app/uploads 读取文件
        → 返回文件流 (Content-Type: image/*, Cache-Control: public, max-age=86400)
```

### 3.5 库存扣减（内部接口）

```
order-service → http://product-service:8002/api/internal/products/deduct-stock
  (不经过 api-gateway，Docker 内部网络直接调用)
    → InternalProductController.deductStock()
      → ProductService: SELECT FOR UPDATE → 库存校验 → 扣减
      → 返回成功/失败
```

### 3.6 分类树查询

```
浏览器 → :80 (Nginx)
  → /api/categories/tree
  → proxy_pass http://api-gateway:8080
    → api-gateway: JWT 校验
    → 路由到 http://product-service:8002/api/categories/tree
      → CategoryController.getCategoryTree()
        → CategoryService: 全量查询 → 内存组装树结构
        → 返回 List<CategoryTreeNode>
```

---

## 4. 端口映射汇总

| 服务 | 容器内端口 | 宿主机端口 | 说明 |
|------|-----------|-----------|------|
| product-service | 8002 | — | 不对外暴露 |
| auth-service | 8001 | — | 不对外暴露 |
| mysql | 3306 | 3306 | 开发调试用 |
| api-gateway | 8080 | 8080 | 统一 API 入口 |
| frontend | 80 | 80 | 用户访问入口 |

### 已确定的端口分配

| 服务 | 端口 | 状态 |
|------|------|------|
| auth-service | 8001 | ✅ 已确定 |
| product-service | 8002 | ✅ 已确定 |
| points-service | 待定 | 将在 Unit 4 基础设施设计中确定 |
| order-service | 待定 | 将在 Unit 5 基础设施设计中确定 |
| api-gateway | 8080 | ✅ 已确定（Unit 7） |

---

## 5. 数据卷映射

| 卷类型 | 容器路径 | 宿主机路径 | 服务 | 说明 |
|--------|---------|-----------|------|------|
| bind mount | /app/uploads | ../uploads | product-service | 产品图片 |
| named volume | /var/lib/mysql | mysql-data | mysql | 数据库数据 |

---

## 6. 故障场景与恢复

| 故障场景 | 影响 | 恢复方式 |
|---------|------|---------|
| product-service 容器崩溃 | 产品浏览/管理不可用，兑换流程中库存操作失败 | Docker 自动重启（可配置 restart: unless-stopped） |
| MySQL 不可用 | product-service 健康检查失败 | 等待 MySQL 恢复，连接池自动重连 |
| 上传目录不可写 | 图片上传失败，其他功能正常 | 检查卷挂载权限 |
| 磁盘空间不足 | 图片上传失败 | 清理旧文件或扩展磁盘（MVP 阶段概率极低） |
| api-gateway 不可用 | 外部 API 请求不可达 | 重启 api-gateway 容器 |
| order-service 调用超时 | 兑换流程中库存扣减超时 | order-service 侧处理超时和重试 |

---

## 7. 开发调试说明

### 本地独立运行（不通过 Docker）
开发阶段可直接在本地运行 product-service，连接宿主机 MySQL（端口 3306 已暴露）：

```properties
DB_HOST=localhost
DB_PORT=3306
DB_NAME=product_db
DB_USER=product_user
DB_PASSWORD=product_pass_2026
UPLOAD_DIR=./uploads
MAX_FILE_SIZE=5MB
SERVER_PORT=8002
```

本地运行时图片存储在项目目录下的 `./uploads/`。

### Docker 内运行
通过 `docker compose up product-service` 启动，自动连接 Docker 网络内的 MySQL，图片存储在卷挂载目录。

### 图片访问调试
- Docker 内：`curl http://product-service:8002/api/files/{filename}`
- 宿主机：`curl http://localhost:8080/api/files/{filename}`（通过 api-gateway）
- 直接查看文件：`ls uploads/`（工作区根目录）
