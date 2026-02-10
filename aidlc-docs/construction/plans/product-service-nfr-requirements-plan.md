# Unit 3: product-service — NFR 需求计划

---

## 前置条件
- [x] 功能设计已完成
- [x] Unit 7 NFR 需求已完成（基础设施层 NFR 已定义）
- [x] Unit 2 NFR 需求已完成（可参考微服务 NFR 模式）

---

## NFR 需求问题

> 以下问题用于确认 product-service 特有的非功能性需求。
> 通用决策（技术框架延后、日志遵循框架规范、不设资源限制）沿用前序 Unit 的决策。

### Q1: 文件上传大小限制

产品图片上传的最大文件大小：

- A) 5MB — 与 Unit 7 环境变量 MAX_FILE_SIZE 一致
- B) 10MB — 允许更大的高清图片
- C) 其他 — 请指定

[Answer]:A

### Q2: 图片存储磁盘空间

MVP 阶段预估 200+ 产品，每个产品一张图片，是否需要考虑磁盘空间监控或清理策略？

- A) 不需要 — MVP 阶段产品数量有限，磁盘空间充足
- B) 需要 — 设置磁盘空间告警阈值或定期清理未引用图片

[Answer]:A

### Q3: 悲观锁超时

库存扣减使用悲观锁（SELECT FOR UPDATE），锁等待超时时间：

- A) 使用数据库默认超时 — MySQL 默认 innodb_lock_wait_timeout = 50 秒
- B) 缩短超时 — 设置较短的锁等待时间（如 5 秒），快速失败
- C) 不做特殊配置 — MVP 阶段并发量低，默认即可

[Answer]:B

---

## 执行步骤

- [ ] 收集用户回答
- [ ] 分析回答，确认无歧义
- [ ] 生成 nfr-requirements.md（NFR 需求清单）
- [ ] 生成 tech-stack-decisions.md（技术栈决策）
- [ ] 提交用户审批
