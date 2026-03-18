# Unit 5: order-service — 业务逻辑模型

---

## 1. 创建兑换订单（核心流程）

```
员工 → POST /api/v1/order (CreateOrderRequest)
  │
  ├── 1. 获取用户身份
  │     └── 从请求头 X-User-Id 获取 userId
  │
  ├── 2. 参数校验
  │     └── productId: > 0
  │
  ├── ===== 阶段一：预校验（不加锁） =====
  │
  ├── 3. 查询产品信息
  │     └── 调用 product-service: GET /api/v1/internal/product/{productId}
  │         ├── 不存在 → 返回 NOT_FOUND_001
  │         ├── status ≠ ACTIVE → 返回 BAD_REQUEST_001
  │         └── stock ≤ 0 → 返回 BAD_REQUEST_002
  │
  ├── 4. 查询积分余额
  │     └── 调用 points-service: GET /api/v1/internal/point/balance/{userId}
  │         ├── 不存在 → 返回 BAD_REQUEST_003
  │         └── balance < pointsPrice → 返回 BAD_REQUEST_004
  │
  ├── ===== 阶段二：执行扣除（先积分后库存） =====
  │
  ├── 5. 扣除积分（Saga 步骤 1）
  │     └── 调用 points-service: POST /api/v1/internal/point/deduct
  │         ├── 请求体: { userId, amount: pointsPrice, orderId: 预生成或后补 }
  │         ├── 成功 → 记录 transactionId，继续
  │         └── 失败（积分不足/超时/异常）→ 返回 BAD_REQUEST_004 或 INTERNAL_SERVER_ERROR_001
  │
  ├── 6. 扣减库存（Saga 步骤 2）
  │     └── 调用 product-service: POST /api/v1/internal/product/deduct-stock
  │         ├── 请求体: { productId, quantity: 1 }
  │         ├── 成功 → 继续
  │         └── 失败（库存不足/超时/异常）→ Saga 补偿：回滚积分，返回错误
  │               └── 补偿: 调用 points-service: POST /api/v1/internal/point/rollback
  │                   ├── 请求体: { transactionId }
  │                   └── 回滚失败 → 记录错误日志 + 人工介入（MVP 最大努力补偿模式）
  │
  ├── ===== 阶段三：创建订单记录 =====
  │
  ├── 7. 创建订单
  │     ├── userId = 当前用户
  │     ├── productId = 请求中的 productId
  │     ├── productName = 产品名称（快照）
  │     ├── productImageUrl = 产品图片（快照）
  │     ├── pointsCost = 产品所需积分
  │     ├── status = PENDING
  │     └── 保存到 order_db.orders
  │
  └── 8. 返回 OrderResponse
```

### 分布式事务策略说明

**策略：Saga 最大努力补偿模式**

1. **预校验阶段**（步骤 3-4）：先分别查询积分和库存是否充足，不加锁。这一步可以快速拦截明显不满足条件的请求，减少不必要的锁竞争。

2. **执行阶段（Saga 编排）**（步骤 5-6）：顺序执行积分扣除 → 库存扣减
   - 先扣积分的原因：积分是虚拟资产，回滚更安全可靠
   - 如果库存扣减失败，逆序补偿回滚积分

3. **补偿失败处理**：补偿操作失败时，记录错误日志并进行人工介入（MVP 阶段采用最大努力补偿，不保证强一致性）

4. **并发场景**：预校验通过但执行时条件已变（如另一用户刚好扣完库存），由 points-service/product-service 的悲观锁保证数据一致性，order-service 根据返回的错误码进行 Saga 补偿。

### orderId 处理
- 方案：先创建 PENDING 状态的订单记录获取 orderId，再执行扣除流程
- 或者：积分扣除时先不传 orderId（传 0），订单创建后再更新 point_transactions 的 referenceId
- 推荐：先创建订单（status=PENDING），用订单 ID 作为积分扣除的 orderId，扣除失败则删除订单记录

### 优化方案（推荐）

```
员工 → POST /api/v1/order
  │
  ├── 1-2. 获取用户身份 + 参数校验
  │
  ├── 3-4. 预校验（查询产品信息 + 查询积分余额）
  │
  ├── 5. 创建订单记录（status=PENDING）
  │     └── 获得 orderId
  │
  ├── 6. 扣除积分（传入 orderId）— Saga 步骤 1
  │     └── 失败 → 删除订单记录，返回错误
  │
  ├── 7. 扣减库存 — Saga 步骤 2
  │     └── 失败 → Saga 补偿：回滚积分 + 删除订单记录，返回错误
  │               补偿失败 → 记录日志 + 人工介入
  │
  └── 8. 返回 OrderResponse
```

---

## 2. 查询当前用户兑换历史

```
员工 → GET /api/v1/order?page=0&size=20
  │
  ├── 1. 获取用户身份
  │     └── 从请求头 X-User-Id 获取 userId
  │
  ├── 2. 分页参数处理
  │     ├── page: 默认 0，最小 0
  │     └── size: 默认 20，最小 1，最大 100
  │
  ├── 3. 查询订单
  │     └── 按 userId 查询 orders，按 created_at DESC 排序
  │
  └── 4. 返回 PageResponse<OrderResponse>
```

---

## 3. 查询兑换详情

```
员工 → GET /api/v1/order/{id}
  │
  ├── 1. 获取用户身份
  │     └── 从请求头 X-User-Id 获取 userId
  │
  ├── 2. 查询订单
  │     └── 按 id 查询 orders
  │         ├── 不存在 → 返回 NOT_FOUND_001
  │         └── userId 不匹配 → 返回 FORBIDDEN_001（不允许查看他人订单）
  │
  └── 3. 返回 OrderResponse
```

---

## 4. 管理员 — 查看所有兑换记录

```
管理员 → GET /api/v1/order/admin?page=0&size=20&keyword=xxx&startDate=&endDate=
  │
  ├── 1. 分页参数处理
  │     ├── page: 默认 0，最小 0
  │     └── size: 默认 20，最小 1，最大 100
  │
  ├── 2. 构建查询条件
  │     ├── keyword（可选）→ 模糊匹配 productName（冗余字段）
  │     ├── startDate（可选）→ created_at >= startDate
  │     └── endDate（可选）→ created_at <= endDate
  │
  ├── 3. 排序
  │     └── 按 created_at DESC
  │
  └── 4. 返回 PageResponse<OrderResponse>
```

---

## 5. 管理员 — 更新兑换状态

```
管理员 → PUT /api/v1/order/admin/{id}/status (UpdateOrderStatusRequest)
  │
  ├── 1. 参数校验
  │     └── status: 必须为合法的 OrderStatus 值
  │
  ├── 2. 查询订单
  │     └── 按 id 查询 → 不存在则返回 NOT_FOUND_001
  │
  ├── 3. 状态流转校验
  │     └── 校验当前状态 → 目标状态是否合法
  │         ├── PENDING → READY ✅
  │         ├── PENDING → CANCELLED ✅
  │         ├── READY → COMPLETED ✅
  │         ├── READY → CANCELLED ✅
  │         └── 其他 → 返回 BAD_REQUEST_005（非法状态变更）
  │
  ├── 4. 取消处理（如果目标状态为 CANCELLED）— Saga 补偿
  │     ├── a. 回滚积分
  │     │     └── 查询 point_transactions 中 referenceId=orderId 且 type=REDEMPTION 的记录
  │     │         └── 调用 points-service: POST /api/v1/internal/point/rollback
  │     │             └── 失败 → 记录错误日志 + 人工介入（最大努力补偿）
  │     │
  │     └── b. 恢复库存
  │           └── 调用 product-service: POST /api/v1/internal/product/restore-stock
  │               ├── 请求体: { productId: 订单中的 productId, quantity: 1 }
  │               └── 失败 → 记录错误日志 + 人工介入（最大努力补偿）
  │
  ├── 5. 更新状态
  │     └── UPDATE orders SET status = 目标状态
  │
  └── 6. 返回更新后的 OrderResponse
```

### 取消补偿说明（Saga 最大努力补偿模式）
- 取消兑换时采用 Saga 补偿：自动回滚积分和恢复库存
- 补偿操作失败时：记录错误日志 + 人工介入（不阻塞状态更新）
- 订单状态仍更新为 CANCELLED，但积分/库存可能需要人工处理
- MVP 阶段采用最大努力补偿策略，不保证强一致性

### 积分回滚的 transactionId 获取
- order-service 需要知道积分扣除时的 transactionId 才能调用回滚接口
- 方案：创建订单时保存积分扣除的 transactionId 到订单记录中
- 或者：回滚接口改为按 orderId 查找对应的 REDEMPTION 记录

### 推荐方案
- orders 表新增 `points_transaction_id` 字段，记录积分扣除时返回的 transactionId
- 取消时直接使用该 transactionId 调用回滚接口

---

## 6. orders 表字段补充

基于取消功能需求，orders 表需新增字段：

| 字段 | 类型 | 约束 | 说明 |
|------|------|------|------|
| points_transaction_id | BIGINT | NULL | 积分扣除流水ID（用于取消时回滚） |

---

## 7. 跨服务调用汇总

| 调用方 | 被调用方 | 接口 | 超时 | 失败处理 |
|--------|---------|------|------|---------|
| order-service | product-service | GET /api/v1/internal/product/{id} | 3s | 返回错误 |
| order-service | points-service | GET /api/v1/internal/point/balance/{userId} | 3s | 返回错误 |
| order-service | points-service | POST /api/v1/internal/point/deduct | 3s | 返回错误，删除订单 |
| order-service | product-service | POST /api/v1/internal/product/deduct-stock | 3s | Saga 补偿：回滚积分，删除订单 |
| order-service | points-service | POST /api/v1/internal/point/rollback | 3s | 记录日志 + 人工介入 |
| order-service | product-service | POST /api/v1/internal/product/restore-stock | 3s | 记录日志 + 人工介入 |
