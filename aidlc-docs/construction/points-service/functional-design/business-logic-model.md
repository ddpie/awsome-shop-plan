# Unit 4: points-service — 业务逻辑模型

---

## 1. 积分余额初始化

```
auth-service → POST /api/internal/points/init (InitPointsRequest)
  │
  ├── 1. 参数校验
  │     └── userId: > 0
  │
  ├── 2. 唯一性校验
  │     └── 查询 point_balances 中是否已存在该 userId
  │         ├── 已存在 → 返回已有的 PointBalanceResponse（幂等处理）
  │         └── 不存在 → 继续创建
  │
  ├── 3. 创建余额记录
  │     ├── userId = 请求中的 userId
  │     ├── balance = 0
  │     └── 保存到 points_db.point_balances
  │
  └── 4. 返回 PointBalanceResponse
```

### 幂等性说明
- 该接口设计为幂等操作：如果 userId 已存在余额记录，直接返回已有记录，不报错
- 这样即使 auth-service 重试调用也不会产生重复数据

### 失败处理
- 如果 points-service 不可用，auth-service 记录日志但注册仍然成功（已在 Unit 2 设计中确定）
- 不做懒初始化补偿（Q1=C），如果初始化失败，由管理员通过手动调整积分功能处理

---

## 2. 查询当前用户积分余额

```
客户端 → GET /api/points/balance
  │
  ├── 1. 获取用户身份
  │     └── 从请求头 X-User-Id 获取 userId
  │
  ├── 2. 查询余额
  │     └── 按 userId 查询 point_balances
  │         ├── 存在 → 返回 PointBalanceResponse
  │         └── 不存在 → 返回 POINTS_001 错误
  │
  └── 3. 返回 PointBalanceResponse
```

---

## 3. 查询当前用户积分变动历史

```
客户端 → GET /api/points/transactions?page=0&size=20
  │
  ├── 1. 获取用户身份
  │     └── 从请求头 X-User-Id 获取 userId
  │
  ├── 2. 分页参数处理
  │     ├── page: 默认 0，最小 0
  │     └── size: 默认 20，最小 1，最大 100
  │
  ├── 3. 查询变动记录
  │     └── 按 userId 查询 point_transactions，按 created_at DESC 排序
  │
  └── 4. 返回 PageResponse<PointTransactionResponse>
```

---

## 4. 管理员 — 查看所有员工积分余额

```
管理员 → GET /api/admin/points/balances?page=0&size=20&keyword=xxx
  │
  ├── 1. 分页参数处理
  │     ├── page: 默认 0，最小 0
  │     └── size: 默认 20，最小 1，最大 100
  │
  ├── 2. 关键词搜索（可选）
  │     └── keyword 匹配 userId（points-service 仅存储 userId，
  │         姓名/工号搜索需前端或 BFF 层配合 auth-service 实现）
  │
  └── 3. 返回 PageResponse<UserPointResponse>
```

### 关键词搜索说明
- points-service 的 point_balances 表仅存储 userId，不存储姓名和工号
- 按姓名/工号搜索的实现方案：前端先调用 auth-service 的用户列表接口搜索，获取 userId 列表，再查询积分
- MVP 阶段 keyword 参数仅支持按 userId 精确匹配，后续可优化

---

## 5. 管理员 — 查看指定员工积分变动明细

```
管理员 → GET /api/admin/points/transactions/{userId}?page=0&size=20&type=DISTRIBUTION
  │
  ├── 1. 参数校验
  │     └── userId: > 0
  │
  ├── 2. 分页参数处理
  │     ├── page: 默认 0，最小 0
  │     └── size: 默认 20，最小 1，最大 100
  │
  ├── 3. 类型筛选（可选）
  │     └── type 参数：DISTRIBUTION / MANUAL_ADD / MANUAL_DEDUCT / REDEMPTION / ROLLBACK
  │         ├── 提供 → 按类型筛选
  │         └── 不提供 → 返回所有类型
  │
  ├── 4. 查询变动记录
  │     └── 按 userId（+ type 可选）查询 point_transactions，按 created_at DESC 排序
  │
  └── 5. 返回 PageResponse<PointTransactionResponse>
```

---

## 6. 管理员 — 手动调整员工积分

```
管理员 → POST /api/admin/points/adjust (AdjustPointsRequest)
  │
  ├── 1. 参数校验
  │     ├── userId: > 0
  │     ├── amount: ≠ 0
  │     └── remark: 非空，最长 500 字符
  │
  ├── 2. 查询当前余额（悲观锁）
  │     └── SELECT ... FROM point_balances WHERE user_id = ? FOR UPDATE
  │         └── 不存在 → 返回 POINTS_001 错误
  │
  ├── 3. 余额校验（扣除场景）
  │     └── 如果 amount < 0:
  │         └── balance + amount < 0 → 返回 POINTS_002 错误（余额不足）
  │
  ├── 4. 更新余额
  │     └── UPDATE point_balances SET balance = balance + amount
  │
  ├── 5. 创建变动记录
  │     ├── type = amount > 0 ? MANUAL_ADD : MANUAL_DEDUCT
  │     ├── amount = 请求中的 amount
  │     ├── balanceAfter = 更新后的余额
  │     ├── operatorId = 从请求头 X-User-Id 获取（管理员ID）
  │     └── remark = 请求中的 remark
  │
  └── 6. 返回 PointTransactionResponse
```

### 事务边界
- 步骤 2-5 在同一个数据库事务中执行
- 悲观锁确保并发安全

---

## 7. 兑换扣除积分（内部接口）

```
order-service → POST /api/internal/points/deduct (DeductPointsRequest)
  │
  ├── 1. 参数校验
  │     ├── userId: > 0
  │     ├── amount: > 0
  │     └── orderId: > 0
  │
  ├── 2. 查询当前余额（悲观锁）
  │     └── SELECT ... FROM point_balances WHERE user_id = ? FOR UPDATE
  │         └── 不存在 → 返回 POINTS_001 错误
  │
  ├── 3. 余额校验
  │     └── balance < amount → 返回 POINTS_003 错误（积分不足）
  │
  ├── 4. 扣除余额
  │     └── UPDATE point_balances SET balance = balance - amount
  │
  ├── 5. 创建变动记录
  │     ├── type = REDEMPTION
  │     ├── amount = -amount（负数）
  │     ├── balanceAfter = 扣除后的余额
  │     ├── referenceId = orderId
  │     └── remark = "兑换扣除"
  │
  └── 6. 返回 PointTransactionResponse
```

### 事务边界
- 步骤 2-5 在同一个数据库事务中执行
- 悲观锁（SELECT FOR UPDATE）防止并发扣除导致余额为负

---

## 8. 兑换回滚积分（内部接口）

```
order-service → POST /api/internal/points/rollback (RollbackDeductionRequest)
  │
  ├── 1. 参数校验
  │     └── transactionId: > 0
  │
  ├── 2. 查询原始扣除记录
  │     └── 按 transactionId 查询 point_transactions
  │         ├── 不存在 → 返回 POINTS_004 错误
  │         └── type ≠ REDEMPTION → 返回 POINTS_005 错误（只能回滚兑换扣除）
  │
  ├── 3. 检查是否已回滚
  │     └── 查询是否存在 type=ROLLBACK 且 referenceId=原始记录的 referenceId 的记录
  │         └── 已存在 → 返回 POINTS_006 错误（不可重复回滚）
  │
  ├── 4. 恢复余额（悲观锁）
  │     ├── SELECT ... FROM point_balances WHERE user_id = ? FOR UPDATE
  │     └── UPDATE point_balances SET balance = balance + abs(原始amount)
  │
  ├── 5. 创建回滚记录
  │     ├── type = ROLLBACK
  │     ├── amount = abs(原始amount)（正数）
  │     ├── balanceAfter = 恢复后的余额
  │     ├── referenceId = 原始记录的 referenceId（orderId）
  │     └── remark = "兑换回滚"
  │
  └── 6. 返回成功（HTTP 200）
```

### 事务边界
- 步骤 2-5 在同一个数据库事务中执行

---

## 9. 查询指定用户积分余额（内部接口）

```
order-service → GET /api/internal/points/balance/{userId}
  │
  ├── 1. 参数校验
  │     └── userId: > 0
  │
  ├── 2. 查询余额
  │     └── 按 userId 查询 point_balances
  │         ├── 存在 → 返回 PointBalanceResponse
  │         └── 不存在 → 返回 POINTS_001 错误
  │
  └── 3. 返回 PointBalanceResponse
```

---

## 10. 积分自动发放（定时任务）

```
BE-SCHEDULER（cron: 0 0 2 1 * ? — 每月1日凌晨2:00）
  │
  ├── 1. 读取发放配置
  │     └── 从 system_configs 查询 points.distribution.amount
  │         └── 不存在 → 使用默认值 100
  │
  ├── 2. 查询所有余额记录
  │     └── SELECT * FROM point_balances（查询所有已有余额记录的用户）
  │         说明：不依赖 auth-service（Q3=B），仅为已初始化积分的用户发放
  │
  ├── 3. 批量发放
  │     └── 对每位用户（逐条处理，单条失败不影响其他用户）：
  │         ├── a. 更新余额: UPDATE point_balances SET balance = balance + amount
  │         ├── b. 创建变动记录:
  │         │     ├── type = DISTRIBUTION
  │         │     ├── amount = 发放额度（正数）
  │         │     ├── balanceAfter = 更新后的余额
  │         │     └── remark = "系统自动发放 - YYYY年MM月"
  │         └── c. 单条事务提交
  │
  ├── 4. 记录发放结果
  │     └── 日志记录：发放总人数、成功数、失败数
  │
  └── 5. 完成
```

### 发放策略说明
- 仅为 point_balances 表中已有记录的用户发放（Q3=B）
- 如果用户注册时积分初始化失败（Q1=C），该用户不会收到自动发放，需管理员手动处理
- 每条发放独立事务，单条失败不影响其他用户
- 发放备注包含年月信息，便于追溯

---

## 11. 管理员 — 获取发放配置

```
管理员 → GET /api/admin/points/config
  │
  ├── 1. 查询配置
  │     └── 从 system_configs 查询 config_key = 'points.distribution.amount'
  │         ├── 存在 → 返回配置值
  │         └── 不存在 → 返回默认值 100
  │
  └── 2. 返回 DistributionConfigResponse
```

---

## 12. 管理员 — 更新发放配置

```
管理员 → PUT /api/admin/points/config (UpdateDistributionConfigRequest)
  │
  ├── 1. 参数校验
  │     └── amount: > 0
  │
  ├── 2. 更新配置
  │     └── UPSERT system_configs:
  │         ├── config_key = 'points.distribution.amount'
  │         ├── config_value = amount（转为字符串）
  │         └── description = "每月自动发放积分额度"
  │
  └── 3. 返回 DistributionConfigResponse
```

### UPSERT 说明
- 如果配置项已存在，更新 config_value
- 如果配置项不存在，插入新记录
- 下次定时任务执行时自动使用新配置
