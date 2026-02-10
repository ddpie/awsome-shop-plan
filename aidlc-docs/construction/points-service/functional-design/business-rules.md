# Unit 4: points-service — 业务规则

---

## 1. 校验规则

### 积分初始化（内部接口）
| 字段 | 规则 | 错误码 |
|------|------|--------|
| userId | 必填，> 0 | 400 Bad Request |

### 手动调整积分
| 字段 | 规则 | 错误码 |
|------|------|--------|
| userId | 必填，> 0 | 400 Bad Request |
| amount | 必填，≠ 0 | 400 Bad Request |
| remark | 必填，非空，最长 500 字符 | 400 Bad Request |

### 兑换扣除积分（内部接口）
| 字段 | 规则 | 错误码 |
|------|------|--------|
| userId | 必填，> 0 | 400 Bad Request |
| amount | 必填，> 0 | 400 Bad Request |
| orderId | 必填，> 0 | 400 Bad Request |

### 兑换回滚（内部接口）
| 字段 | 规则 | 错误码 |
|------|------|--------|
| transactionId | 必填，> 0 | 400 Bad Request |

### 更新发放配置
| 字段 | 规则 | 错误码 |
|------|------|--------|
| amount | 必填，> 0 | 400 Bad Request |

### 分页参数
| 参数 | 默认值 | 范围 |
|------|--------|------|
| page | 0 | ≥ 0 |
| size | 20 | 1 ~ 100 |

---

## 2. 业务规则

### BR-POINTS-001: 积分余额非负
- 积分余额不允许为负数
- 任何扣除操作（兑换扣除、管理员手动扣除）都必须校验扣除后余额 ≥ 0
- 违反时返回对应错误码

### BR-POINTS-002: 积分初始化幂等
- 积分初始化接口为幂等操作
- 如果 userId 已存在余额记录，直接返回已有记录，不创建重复记录
- 初始余额固定为 0

### BR-POINTS-003: 积分变动必须记录流水
- 任何积分变动（发放、扣除、调整、回滚）都必须同时创建 point_transactions 记录
- 流水记录的 balanceAfter 必须等于变动后的实际余额
- 余额更新和流水创建在同一事务中

### BR-POINTS-004: 悲观锁并发控制
- 所有涉及余额变动的操作必须使用 `SELECT ... FOR UPDATE` 锁定余额行
- 适用场景：兑换扣除、管理员手动调整、积分回滚
- 锁超时：与数据库默认配置一致（innodb_lock_wait_timeout）

### BR-POINTS-005: 回滚唯一性
- 同一笔兑换扣除只能回滚一次
- 通过查询是否存在 type=ROLLBACK 且 referenceId 相同的记录来判断
- 重复回滚返回 POINTS_006 错误

### BR-POINTS-006: 回滚类型限制
- 只能回滚 type=REDEMPTION 的变动记录
- 不允许回滚手动调整、自动发放等其他类型的变动

### BR-POINTS-007: 手动调整必须填写备注
- 管理员手动调整积分时，remark 字段为必填
- 用于审计追溯调整原因

### BR-POINTS-008: 自动发放独立事务
- 定时任务批量发放时，每位用户的发放操作为独立事务
- 单个用户发放失败不影响其他用户
- 发放结果通过日志记录

### BR-POINTS-009: 发放配置默认值
- 如果 system_configs 中不存在 `points.distribution.amount` 配置项，使用默认值 100
- 管理员更新配置后，下次定时任务执行时自动生效

### BR-POINTS-010: 变动类型与 amount 符号一致性
- DISTRIBUTION: amount > 0
- MANUAL_ADD: amount > 0
- MANUAL_DEDUCT: amount < 0
- REDEMPTION: amount < 0
- ROLLBACK: amount > 0

---

## 3. 错误码

| 错误码 | HTTP 状态码 | 消息 | 触发场景 |
|--------|------------|------|---------|
| POINTS_001 | 404 | 积分余额记录不存在 | 查询/操作时 userId 无对应余额记录 |
| POINTS_002 | 400 | 扣除后余额不足 | 管理员手动扣除时，扣除后余额 < 0 |
| POINTS_003 | 400 | 积分不足，无法兑换 | 兑换扣除时，余额 < 扣除数量 |
| POINTS_004 | 404 | 积分变动记录不存在 | 回滚时 transactionId 无对应记录 |
| POINTS_005 | 400 | 只能回滚兑换扣除记录 | 回滚时原始记录 type ≠ REDEMPTION |
| POINTS_006 | 409 | 该笔扣除已回滚，不可重复操作 | 回滚时已存在对应的 ROLLBACK 记录 |
| POINTS_007 | 404 | 配置项不存在 | 内部错误（正常不应出现，有默认值兜底） |

### 统一错误响应格式
```json
{
  "code": "POINTS_001",
  "message": "积分余额记录不存在",
  "data": null
}
```

---

## 4. 边界条件

### 积分余额
- 最小值：0（不允许负数）
- 最大值：INT 范围（2,147,483,647），实际业务中不会达到
- 初始值：0

### 积分变动数量
- 手动调整：amount ≠ 0，正数为增加，负数为扣除
- 兑换扣除：amount > 0（请求中为正数，存储时取负）
- 自动发放：amount > 0

### 发放配置
- amount 最小值：1
- amount 无上限（由管理员自行控制合理性）

### 定时任务
- 执行时间：每月 1 日凌晨 2:00（cron: `0 0 2 1 * ?`）
- 执行频率：固定每月一次，不可配置
- 发放范围：point_balances 表中所有已有记录的用户

### 并发场景
- 同一用户同时发起兑换和管理员调整：悲观锁串行化处理
- 多个兑换请求同时扣除同一用户积分：悲观锁串行化，第二个请求等待第一个事务提交后再校验余额
- 定时任务发放期间有兑换请求：各自独立事务，不冲突（发放不使用悲观锁，仅原子 UPDATE）

---

## 5. 跨服务交互约定

### auth-service → points-service
- 接口：`POST http://points-service:8080/api/internal/points/init`
- 调用时机：用户注册成功后
- 失败处理：auth-service 记录日志，注册仍然成功
- 不做懒初始化补偿

### order-service → points-service
- 扣除：`POST http://points-service:8080/api/internal/points/deduct`
- 回滚：`POST http://points-service:8080/api/internal/points/rollback`
- 查询余额：`GET http://points-service:8080/api/internal/points/balance/{userId}`
- 调用方式：HTTP 同步调用，Docker 内部网络

### 内部接口安全
- 内部接口（/api/internal/*）不经过 API 网关
- 仅在 Docker 内部网络中可访问
- 不需要 JWT 认证（服务间信任）
