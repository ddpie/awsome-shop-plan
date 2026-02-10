# Unit 5: order-service — 技术栈决策

---

## 1. 后端框架
- **决策**: 延后到实现阶段，由用户提供统一的后端技术框架
- **影响**: 具体的依赖库、ORM 框架、HTTP 客户端实现方式将在实现阶段确定

---

## 2. 数据访问

### 数据库
- MySQL 8.4 LTS（与 Unit 7 基础设施一致）
- 独立 database: order_db
- 数据表: orders

### 索引策略
- `idx_orders_user_id` ON (user_id) — 员工查询自己的订单
- `idx_orders_status` ON (status) — 按状态筛选
- `idx_orders_created_at` ON (created_at) — 时间范围查询、排序
- 管理员按产品名称搜索使用冗余字段 productName，不跨服务查询

---

## 3. 跨服务通信

### 调用方（order-service 调用其他服务）

| 被调用服务 | 基础 URL | 用途 |
|-----------|---------|------|
| product-service | `http://product-service:8002` | 查询产品、扣减/恢复库存 |
| points-service | `http://points-service:8003` | 查询余额、扣除/回滚积分 |

### 通信协议
- 协议: HTTP REST
- 网络: Docker 内部网络（awsomeshop-network）
- 认证: 无（服务间信任，Docker 网络隔离）

### 超时配置
- 连接超时: 1 秒
- 读取超时: 2 秒
- 总超时: 3 秒

### 重试策略
- 超时或网络异常时自动重试 1 次
- 重试间隔: 立即重试（无延迟）
- 仍失败则执行补偿逻辑
- **关键前提**: 被调用的交易类接口必须保证幂等性

### 幂等性依赖

| 接口 | 幂等性保证方式 |
|------|--------------|
| POST /api/internal/points/deduct | 通过 orderId 关联，同一订单不重复扣除 |
| POST /api/internal/products/deduct-stock | 悲观锁保证不超卖 |
| POST /api/internal/points/rollback | 已设计为幂等（重复回滚返回 POINTS_006） |
| POST /api/internal/products/restore-stock | 需确保幂等性（重复恢复不多加库存） |

---

## 4. 性能目标

| 指标 | 目标值 | 说明 |
|------|--------|------|
| 兑换流程 P95 响应时间 | ≤ 2 秒 | 含预校验 2 次 + 扣除 2 次跨服务调用 + 本地操作 |
| 查询接口 P95 响应时间 | ≤ 200ms | 订单列表、详情、管理员列表 |
| 跨服务单次调用 P95 | ≤ 500ms | 含网络延迟和悲观锁等待 |
| 分页查询 | 默认 20 条/页，最大 100 条 | 数据库级别 LIMIT/OFFSET |

---

## 5. 依赖关系

| 依赖 | 类型 | 说明 |
|------|------|------|
| MySQL 8.4 | 数据库 | order_db |
| product-service (8002) | 运行时依赖 | 查询产品、扣减/恢复库存 |
| points-service (8003) | 运行时依赖 | 查询余额、扣除/回滚积分 |
| Docker 网络 | 基础设施 | 内部服务通信 |

---

## 6. 补偿策略决策

### 补偿模式
- 采用"最大努力"补偿策略
- 补偿失败仅记录错误日志（ERROR 级别）
- MVP 阶段由管理员定期检查日志处理异常

### 不采用补偿失败表的原因
- MVP 阶段用户量有限，异常情况概率低
- 错误日志已包含足够的排查信息（订单 ID、失败原因）
- 减少系统复杂度，后续可按需升级
