# Unit 3: product-service — 技术栈决策

---

## 1. 后端框架

| 决策项 | 选择 | 说明 |
|--------|------|------|
| 后端框架 | 待定 — 用户将提供统一技术框架 | 所有微服务使用统一框架 |
| 架构分层 | 待定 — 用户将提供分层规范 | Controller → Service → Repository |

> 技术框架和架构分层将在实现阶段由用户提供，设计阶段保持技术无关。

---

## 2. 数据访问

| 决策项 | 选择 | 说明 |
|--------|------|------|
| 数据库 | MySQL 8.4（共享 Unit 7 基础设施） | product_db 独立 database |
| 字符集 | utf8mb4 | 支持中文产品名称和描述 |
| 连接方式 | 通过 Docker DNS 连接 mysql:3306 | 环境变量配置 |
| 锁策略 | 悲观锁（SELECT FOR UPDATE） | 库存扣减场景 |
| 锁超时 | 5 秒 | 快速失败，避免长时间等待 |

---

## 3. 文件存储

| 决策项 | 选择 | 说明 |
|--------|------|------|
| 存储方式 | 本地文件系统 | Docker 卷挂载到宿主机 |
| 存储路径 | UPLOAD_DIR 环境变量（默认 /app/uploads） | Docker 卷：../uploads:/app/uploads |
| 文件大小限制 | 5MB | MAX_FILE_SIZE 环境变量 |
| 允许类型 | jpg, jpeg, png, gif, webp | 图片白名单 |
| 命名策略 | UUID + 原始扩展名 | 防冲突、防路径遍历 |
| 磁盘监控 | 不需要 | MVP 阶段产品数量有限 |

---

## 4. 性能目标

| 指标 | 目标值 | 说明 |
|------|--------|------|
| P95 响应时间（查询接口） | ≤ 200ms | 产品列表、详情、分类树 |
| P95 响应时间（文件上传） | ≤ 1000ms | 含磁盘 I/O |
| 分页上限 | 100 条/页 | 防止大查询 |
| 悲观锁超时 | 5 秒 | 快速失败 |

---

## 5. 依赖关系

| 依赖 | 类型 | 说明 |
|------|------|------|
| MySQL (product_db) | 数据存储 | Unit 7 提供 |
| 本地文件系统 | 文件存储 | Docker 卷挂载 |
| 无跨服务依赖 | — | product-service 不主动调用其他微服务 |

### 被依赖关系

| 调用方 | 接口 | 说明 |
|--------|------|------|
| order-service | /api/internal/products/{id} | 查询产品信息 |
| order-service | /api/internal/products/deduct-stock | 库存扣减 |
| order-service | /api/internal/products/restore-stock | 库存恢复 |
