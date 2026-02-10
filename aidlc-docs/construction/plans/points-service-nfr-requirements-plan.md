# Unit 4: points-service — NFR 需求计划

---

## 前置条件
- [x] 功能设计已完成
- [x] Unit 7 NFR 需求已完成（基础设施层 NFR 已定义）
- [x] Unit 2 NFR 需求已完成（可参考微服务 NFR 模式）
- [x] Unit 3 NFR 需求已完成（可参考悲观锁超时决策）

---

## NFR 需求问题

> 以下问题用于确认 points-service 特有的非功能性需求。
> 通用决策沿用前序 Unit：技术框架延后、日志遵循框架规范、不设容器资源限制。

### Q1: 悲观锁超时
积分扣除/调整使用悲观锁（SELECT FOR UPDATE），锁等待超时时间：

- A) 与 product-service 一致 — 5 秒超时，快速失败
- B) 使用数据库默认超时 — MySQL 默认 innodb_lock_wait_timeout = 50 秒
- C) 其他 — 请指定

[Answer]: A

### Q2: 定时任务失败处理
每月积分自动发放定时任务，如果执行过程中服务重启或异常中断：

- A) 不做补偿 — MVP 阶段由管理员发现后手动补发（简单）
- B) 记录发放批次状态 — 增加发放批次表，记录每次发放的开始/完成状态，重启后可检查并补发未完成的用户

[Answer]: B

### Q3: 内部接口响应时间目标
points-service 内部接口（积分扣除、回滚等，被 order-service 调用）的响应时间目标（P95）：

- A) 200ms 以内（与 auth-service 一致）
- B) 100ms 以内（积分操作为简单数据库操作，应更快）
- C) 不设目标 — MVP 阶段不关注

[Answer]: A

---

## 执行步骤

- [ ] 收集用户回答
- [ ] 分析回答，确认无歧义
- [ ] 生成 nfr-requirements.md（NFR 需求清单）
- [ ] 生成 tech-stack-decisions.md（技术栈决策）
- [ ] 提交用户审批
