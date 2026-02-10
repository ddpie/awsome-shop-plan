# Unit 4: points-service — 功能设计计划

## 目标
为积分服务设计详细的业务逻辑、领域模型和业务规则，覆盖积分余额管理、积分变动记录、积分自动发放（定时任务）、发放配置管理等功能。

## 覆盖用户故事
- US-008: 查看积分余额（后端余额查询）
- US-009: 查看积分变动历史（后端历史查询）
- US-020: 查看员工积分列表（后端管理查询）
- US-021: 手动调整员工积分（后端积分调整）
- US-022: 配置积分自动发放规则（后端配置管理）

## 跨服务交互
- auth-service 注册时调用 `POST /api/internal/points/init` 初始化积分余额
- order-service 兑换时调用积分扣除接口
- 定时任务需要获取所有活跃员工列表（调用 auth-service）

---

## 设计问题

### Q1: 积分余额懒初始化策略
auth-service 注册时同步调用 points-service 初始化积分（已在 Unit 2 设计中确定）。如果该调用失败，points-service 需要在首次查询时补偿初始化。补偿初始化的触发方式：

- A) 查询余额时，如果 point_balances 中无记录，自动创建一条 balance=0 的记录并返回（懒初始化）
- B) 查询余额时，如果无记录，返回错误提示用户联系管理员
- C) 不做补偿，依赖 auth-service 注册时的调用（如果失败则管理员手动处理）

[Answer]: C

### Q2: 定时任务执行策略
积分自动发放定时任务的执行频率和时间：

- A) 每月 1 日凌晨 2:00 执行（固定时间，cron: `0 0 2 1 * ?`）
- B) 可配置执行周期（通过 system_configs 表配置 cron 表达式，管理员可修改）
- C) 每月 1 日凌晨 2:00 执行，但管理员可以手动触发一次即时发放

[Answer]: A

### Q3: 定时任务获取员工列表方式
积分自动发放需要获取所有活跃员工列表。获取方式：

- A) 调用 auth-service 内部接口获取所有活跃用户列表（跨服务调用）
- B) 直接查询 point_balances 表中所有记录，为已有余额记录的用户发放（不依赖 auth-service）

[Answer]: B

### Q4: 积分扣除并发控制
order-service 调用积分扣除时的并发控制策略：

- A) 乐观锁 — point_balances 表增加 version 字段，更新时校验版本号，冲突时返回错误让调用方重试
- B) 悲观锁 — `SELECT ... FOR UPDATE` 锁定余额行，在事务内完成扣除（与 product-service 库存策略一致）
- C) 数据库层面 — 使用 `UPDATE ... SET balance = balance - ? WHERE balance >= ?` 原子操作，无需额外锁

[Answer]: B

### Q5: 管理员手动调整积分 — 扣除限制
管理员手动扣除积分时，是否允许扣成负数：

- A) 不允许 — 扣除后余额不能为负数，系统阻止操作（与 US-021 验收标准一致）
- B) 允许 — 管理员有权将余额扣成负数（用于惩罚或纠错场景）

[Answer]: A

### Q6: system_configs 表初始配置
积分发放相关的系统配置项设计：

- A) 仅配置发放额度（`points.distribution.amount`），发放周期固定为每月
- B) 配置发放额度 + 发放周期（`points.distribution.amount` + `points.distribution.cron`），均可修改
- C) 配置发放额度 + 发放开关（`points.distribution.amount` + `points.distribution.enabled`），支持暂停发放

[Answer]: A

### Q7: 积分变动历史查询 — 管理员视角
管理员查看某员工积分变动明细时（US-020 验收标准第4条），是否需要支持按变动类型筛选：

- A) 支持 — 管理员可以按类型（发放/兑换/手动调整/回滚）筛选变动记录
- B) 不支持 — MVP 阶段仅按时间倒序展示全部记录，不做类型筛选

[Answer]: A

---

## 执行步骤

- [ ] 收集用户回答
- [ ] 分析回答，确认无歧义
- [ ] 生成领域实体文档 `domain-entities.md`（DTO 定义、请求/响应模型、API 端点）
- [ ] 生成业务逻辑模型文档 `business-logic-model.md`（积分初始化/查询/扣除/调整/发放流程详细设计）
- [ ] 生成业务规则文档 `business-rules.md`（校验规则、错误码、边界条件、并发控制）
- [ ] 提交用户审批
