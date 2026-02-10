# Unit 4: points-service — NFR 设计模式

---

## 模式 1: 悲观锁并发控制

### 适用场景
- 积分扣除（兑换）
- 管理员手动调整积分
- 积分回滚

### 设计
```
开启事务
  → SET innodb_lock_wait_timeout = 5
  → SELECT * FROM point_balances WHERE user_id = ? FOR UPDATE
  → 业务校验（余额是否充足等）
  → UPDATE point_balances SET balance = balance +/- amount
  → INSERT INTO point_transactions (...)
提交事务
```

### 关键点
- 事务级别设置锁超时为 5 秒，不影响全局配置
- 锁超时后抛出异常，由统一错误处理返回友好错误信息
- 与 product-service 库存悲观锁策略保持一致

### 覆盖 NFR
- NFR-PTS-PERF-002（悲观锁超时）
- NFR-PTS-REL-001（事务一致性）

---

## 模式 2: 定时任务批次可靠性

### 适用场景
- 每月积分自动发放

### 设计
```
定时触发（cron: 0 0 2 1 * ?）
  │
  ├── 1. 检查补发
  │     └── 查询 status=RUNNING 的批次
  │         ├── 存在 → 执行补发逻辑
  │         └── 不存在 → 继续正常发放
  │
  ├── 2. 创建批次记录
  │     └── INSERT distribution_batches (status=RUNNING, distribution_amount=配置额度)
  │
  ├── 3. 查询发放目标
  │     └── SELECT * FROM point_balances → 获取总人数，更新 total_count
  │
  ├── 4. 逐条发放（独立事务）
  │     └── 对每位用户:
  │         ├── 开启事务
  │         ├── UPDATE point_balances SET balance = balance + amount
  │         ├── INSERT point_transactions (type=DISTRIBUTION)
  │         ├── 提交事务
  │         ├── 成功 → success_count++
  │         └── 失败 → fail_count++，记录日志
  │
  ├── 5. 更新批次状态
  │     └── UPDATE distribution_batches SET status=COMPLETED/FAILED,
  │         success_count=?, fail_count=?, completed_at=NOW()
  │
  └── 6. 记录日志
```

### 补发逻辑
```
查询 RUNNING 状态的批次
  │
  ├── 获取该批次的 started_at 和 distribution_amount
  │
  ├── 查询所有 point_balances 用户
  │
  ├── 查询 point_transactions 中该时间段内 type=DISTRIBUTION 的已发放用户
  │
  ├── 计算差集 = 所有用户 - 已发放用户
  │
  └── 为差集中的用户逐条补发（同正常发放逻辑）
```

### 关键点
- 批次记录提供发放过程的可观测性
- 补发基于已有流水记录判断，避免重复发放
- 单条失败不影响整体，fail_count 记录失败数量

### 覆盖 NFR
- NFR-PTS-REL-002（发放批次记录）
- NFR-PTS-REL-003（单条隔离）

---

## 模式 3: 统一错误处理

### 适用场景
- 所有 API 端点（外部 + 内部）

### 设计
```json
{
  "code": "POINTS_001",
  "message": "积分余额记录不存在",
  "data": null
}
```

### 错误分类
| HTTP 状态码 | 场景 |
|------------|------|
| 400 | 参数校验失败、余额不足、类型不匹配 |
| 404 | 余额记录不存在、变动记录不存在 |
| 409 | 重复回滚 |
| 500 | 系统内部错误、数据库异常 |

### 关键点
- 业务异常返回 4xx，系统异常返回 5xx
- 悲观锁超时异常捕获后返回 409 或 500（视具体场景）
- 与其他微服务保持一致的错误响应格式

### 覆盖 NFR
- NFR-PTS-MAINT-001（统一错误响应格式）

---

## 模式 4: 分层输入校验

### 适用场景
- 所有接收外部输入的 API 端点

### 设计
```
请求进入
  → 第1层: 框架级校验（参数类型、必填、范围）
  → 第2层: 业务逻辑校验（余额充足性、记录存在性、回滚唯一性）
  → 执行业务操作
```

### 关键点
- 第1层校验失败直接返回 400，不进入业务逻辑
- 第2层校验在事务内执行（悲观锁保护下）
- 校验规则参见 business-rules.md

### 覆盖 NFR
- NFR-PTS-SEC-003（输入校验）

---

## 模式 5: 幂等性设计

### 适用场景
- 积分初始化接口（/api/internal/points/init）
- 积分回滚接口（/api/internal/points/rollback）

### 设计

#### 初始化幂等
```
POST /api/internal/points/init
  → 查询 point_balances WHERE user_id = ?
  → 已存在 → 直接返回已有记录（不报错）
  → 不存在 → INSERT 新记录
```

#### 回滚幂等（通过唯一性校验）
```
POST /api/internal/points/rollback
  → 查询原始 REDEMPTION 记录
  → 查询是否已存在对应 ROLLBACK 记录
  → 已存在 → 返回 POINTS_006 错误（明确拒绝重复操作）
  → 不存在 → 执行回滚
```

### 关键点
- 初始化接口为"静默幂等"：重复调用返回成功
- 回滚接口为"拒绝幂等"：重复调用返回明确错误
- 两种策略适配不同的调用方需求

### 覆盖 NFR
- NFR-PTS-REL-004（幂等性保证）

---

## 模式 6: 内部接口隔离

### 适用场景
- 服务间调用接口（/api/internal/*）

### 设计
```
外部请求 → Nginx → API Gateway → 业务微服务（/api/points/*, /api/admin/points/*）
内部请求 → Docker 网络 → 业务微服务（/api/internal/points/*）
```

### 关键点
- 内部接口通过 URL 前缀 `/api/internal/` 区分
- API 网关不路由 `/api/internal/*` 请求
- Docker 网络隔离确保外部无法直接访问内部接口
- 内部接口不需要 JWT 认证

### 覆盖 NFR
- NFR-PTS-SEC-001（内部接口网络隔离）

---

## 设计模式覆盖矩阵

| 设计模式 | 覆盖 NFR |
|---------|---------|
| 悲观锁并发控制 | NFR-PTS-PERF-002, NFR-PTS-REL-001 |
| 定时任务批次可靠性 | NFR-PTS-REL-002, NFR-PTS-REL-003 |
| 统一错误处理 | NFR-PTS-MAINT-001 |
| 分层输入校验 | NFR-PTS-SEC-003 |
| 幂等性设计 | NFR-PTS-REL-004 |
| 内部接口隔离 | NFR-PTS-SEC-001 |
