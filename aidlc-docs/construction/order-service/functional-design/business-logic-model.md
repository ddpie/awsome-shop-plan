# Unit 5: order-service — 业务逻辑模型

---

## 1. 创建兑换订单（核心流程）

```
员工 → POST /api/orders (CreateOrderRequest)
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
  │     └── 调用 product-service: GET /api/internal/products/{productId}
  │         ├── 不存在 → 返回 ORDER_001
  │         ├── status ≠ ACTIVE → 返回 ORDER_002
  │         └── stock ≤ 0 → 返回 ORDER_003
  │
  ├── 4. 查询积分余额
  │     └── 调用 points-service: GET /api/internal/points/balance/{userId}
  │         ├── 不存在 → 返回 ORDER_004
  │         └── balance < pointsPrice → 返回 ORDER_005
  │
  ├── ===== 阶段二：执行扣除（先积分后库存） =====
  │
  ├── 5. 扣除积分
  │     └── 调用 points-service: POST /api/internal/points/deduct
  │         ├── 请求体: { userId, amount: pointsPrice, orderId: 预生成或后补 }
  │         ├── 成功 → 记录 transactionId，继续
  │         └── 失败（积分不足/超时/异常）→ 返回 ORDER_005 或 ORDER_008
  │
  ├── 6. 扣减库存
  │     └── 调用 product-service: POST /api/internal/products/deduct-stock
  │         ├── 请求体: { productId, quantity: 1 }
  │         ├── 成功 → 继续
  │         └── 失败（库存不足/超时/异常）→ 补偿回滚积分，返回错误
  │               └── 补偿: 调用 points-service: POST /api/internal/points/rollback
  │                   ├── 请求体: { transactionId }
  │                   └── 回滚失败 → 记录错误日志（需人工介入）
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

### 跨服务事务策略说明

**策略：先校验再执行 + 顺序扣除 + 补偿回滚**

1. **预校验阶段**（步骤 3-4）：先分别查询积分和库存是否充足，不加锁。这一步可以快速拦截明显不满足条件的请求，减少不必要的锁竞争。

2. **执行阶段**（步骤 5-6）：先扣积分，再扣库存。
   - 先扣积分的原因：积分是虚拟资产，回滚更安全可靠
   - 如果库存扣减失败，回滚积分

3. **并发场景**：预校验通过但执行时条件已变（如另一用户刚好扣完库存），由 points-service/product-service 的悲观锁保证数据一致性，order-service 根据返回的错误码进行补偿。

### orderId 处理
- 方案：先创建 PENDING 状态的订单记录获取 orderId，再执行扣除流程
- 或者：积分扣除时先不传 orderId（传 0），订单创建后再更新 point_transactions 的 referenceId
- 推荐：先创建订单（status=PENDING），用订单 ID 作为积分扣除的 orderId，扣除失败则删除订单记录

### 优化方案（推荐）

```
员工 → POST /api/orders
  │
  ├── 1-2. 获取用户身份 + 参数校验
  │
  ├── 3-4. 预校验（查询产品信息 + 查询积分余额）
  │
  ├── 5. 创建订单记录（status=PENDING）
  │     └── 获得 orderId
  │
  ├── 6. 扣除积分（传入 orderId）
  │     └── 失败 → 删除订单记录，返回错误
  │
  ├── 7. 扣减库存
  │     └── 失败 → 回滚积分 + 删除订单记录，返回错误
  │
  └── 8. 返回 OrderResponse
```

---

## 2. 查询当前用户兑换历史

```
员工 → GET /api/orders?page=0&size=20
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
员工 → GET /api/orders/{id}
  │
  ├── 1. 获取用户身份
  │     └── 从请求头 X-User-Id 获取 userId
  │
  ├── 2. 查询订单
  │     └── 按 id 查询 orders
  │         ├── 不存在 → 返回 ORDER_006
  │         └── userId 不匹配 → 返回 ORDER_007（不允许查看他人订单）
  │
  └── 3. 返回 OrderResponse
```

---

## 4. 管理员 — 查看所有兑换记录

```
管理员 → GET /api/admin/orders?page=0&size=20&keyword=xxx&startDate=&endDate=
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
管理员 → PUT /api/admin/orders/{id}/status (UpdateOrderStatusRequest)
  │
  ├── 1. 参数校验
  │     └── status: 必须为合法的 OrderStatus 值
  │
  ├── 2. 查询订单
  │     └── 按 id 查询 → 不存在则返回 ORDER_006
  │
  ├── 3. 状态流转校验
  │     └── 校验当前状态 → 目标状态是否合法
  │         ├── PENDING → READY ✅
  │         ├── PENDING → CANCELLED ✅
  │         ├── READY → COMPLETED ✅
  │         ├── READY → CANCELLED ✅
  │         └── 其他 → 返回 ORDER_009（非法状态变更）
  │
  ├── 4. 取消处理（如果目标状态为 CANCELLED）
  │     ├── a. 回滚积分
  │     │     └── 查询 point_transactions 中 referenceId=orderId 且 type=REDEMPTION 的记录
  │     │         └── 调用 points-service: POST /api/internal/points/rollback
  │     │             └── 失败 → 记录错误日志，状态仍更新为 CANCELLED（需人工介入处理积分）
  │     │
  │     └── b. 恢复库存
  │           └── 调用 product-service: POST /api/internal/products/restore-stock
  │               ├── 请求体: { productId: 订单中的 productId, quantity: 1 }
  │               └── 失败 → 记录错误日志（需人工介入处理库存）
  │
  ├── 5. 更新状态
  │     └── UPDATE orders SET status = 目标状态
  │
  └── 6. 返回更新后的 OrderResponse
```

### 取消补偿说明
- 取消兑换时自动回滚积分和恢复库存
- 回滚/恢复调用失败不阻塞状态更新（订单仍标记为 CANCELLED）
- 失败情况记录错误日志，由管理员人工介入处理
- 这是"最大努力"补偿策略，适合 MVP 阶段

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
| order-service | product-service | GET /api/internal/products/{id} | 3s | 返回错误 |
| order-service | points-service | GET /api/internal/points/balance/{userId} | 3s | 返回错误 |
| order-service | points-service | POST /api/internal/points/deduct | 3s | 返回错误，删除订单 |
| order-service | product-service | POST /api/internal/products/deduct-stock | 3s | 回滚积分，删除订单 |
| order-service | points-service | POST /api/internal/points/rollback | 3s | 记录日志（人工介入） |
| order-service | product-service | POST /api/internal/products/restore-stock | 3s | 记录日志（人工介入） |
