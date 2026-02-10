# Unit 4: points-service — 技术栈决策

---

## 1. 后端框架
- **决策**: 延后到实现阶段，由用户提供统一的后端技术框架
- **影响**: 具体的依赖库、ORM 框架、定时任务实现方式将在实现阶段确定

---

## 2. 数据访问

### 数据库
- MySQL 8.4 LTS（与 Unit 7 基础设施一致）
- 独立 database: points_db
- 数据表: point_balances, point_transactions, system_configs, distribution_batches（新增）

### 并发控制
- 悲观锁: `SELECT ... FOR UPDATE`
- 锁超时: 5 秒（事务级别 `SET innodb_lock_wait_timeout = 5`）
- 适用场景: 积分扣除、管理员手动调整、积分回滚

### 新增表: distribution_batches（发放批次）

| 字段 | 类型 | 约束 | 说明 |
|------|------|------|------|
| id | BIGINT | PK, AUTO_INCREMENT | 批次ID |
| distribution_amount | INT | NOT NULL | 本次发放额度 |
| total_count | INT | NOT NULL, DEFAULT 0 | 应发放总人数 |
| success_count | INT | NOT NULL, DEFAULT 0 | 成功发放人数 |
| fail_count | INT | NOT NULL, DEFAULT 0 | 失败人数 |
| status | ENUM('RUNNING','COMPLETED','FAILED') | NOT NULL, DEFAULT 'RUNNING' | 批次状态 |
| started_at | DATETIME | NOT NULL, DEFAULT CURRENT_TIMESTAMP | 开始时间 |
| completed_at | DATETIME | NULL | 完成时间 |

索引：
- `idx_distribution_batches_status` ON (status)
- `idx_distribution_batches_started_at` ON (started_at)

### 数据库初始化脚本更新
- infrastructure 的 init.sql 需新增 distribution_batches 表的建表语句

---

## 3. 定时任务

### 实现方式
- 具体实现依赖后端框架（如 Spring @Scheduled、Node.js node-cron 等）
- cron 表达式: `0 0 2 1 * ?`（每月 1 日凌晨 2:00）
- 硬编码在代码中，不可通过配置修改

### 可靠性机制
- 发放前创建批次记录（status=RUNNING）
- 逐条发放，每条独立事务
- 发放完成后更新批次状态为 COMPLETED 或 FAILED
- 服务启动时检查是否有 RUNNING 状态的批次，如有则执行补发

### 补发逻辑
- 查询 RUNNING 状态的批次
- 对比已发放的用户（通过 point_transactions 中该批次时间段内的 DISTRIBUTION 记录）
- 为未发放的用户补发
- 更新批次状态

---

## 4. 跨服务通信

### 被调用方（points-service 提供内部接口）
- 协议: HTTP REST
- 网络: Docker 内部网络（awsomeshop-network）
- 基础 URL: `http://points-service:{port}`（端口待基础设施设计阶段确定）
- 认证: 无（服务间信任，Docker 网络隔离）

### 调用方超时建议
- order-service 调用积分扣除/回滚: 建议 3 秒超时（与 auth-service 跨服务调用策略一致）
- 超时和重试策略由调用方（order-service）自行决定

---

## 5. 性能目标

| 指标 | 目标值 | 说明 |
|------|--------|------|
| API P95 响应时间 | ≤ 200ms | 所有接口（含内部接口） |
| 悲观锁超时 | 5 秒 | 快速失败 |
| 单条发放耗时 | < 50ms | UPDATE + INSERT |
| 1000 用户发放总耗时 | < 60 秒 | 逐条处理 |

---

## 6. 依赖关系

| 依赖 | 类型 | 说明 |
|------|------|------|
| MySQL 8.4 | 数据库 | points_db |
| auth-service | 被依赖 | 注册时调用 init 接口 |
| order-service | 被依赖 | 兑换时调用 deduct/rollback/balance 接口 |
| Docker 网络 | 基础设施 | 内部服务通信 |
