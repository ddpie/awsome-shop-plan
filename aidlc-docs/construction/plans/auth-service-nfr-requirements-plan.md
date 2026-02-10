# Unit 2: auth-service — NFR 需求计划

## 目标
确定认证服务的非功能性需求和技术栈选择，覆盖安全性、性能、可靠性、可维护性等方面。

---

## NFR 问题

### Q1: 后端技术框架
认证服务的后端技术框架选择（此前约定在实现阶段确认）：

- A) Spring Boot (Java)
- B) Express.js (Node.js)
- C) Gin (Go)
- D) 其他（请说明）

[Answer]: 后端会提供统一的技术框架

### Q2: bcrypt 性能考量
bcrypt 加密是 CPU 密集型操作（cost factor=10 约需 100ms）。MVP 阶段是否需要考虑注册/登录的并发性能：

- A) 不需要 — MVP 阶段用户量小，单线程处理即可
- B) 需要 — 使用异步/线程池处理 bcrypt 操作，避免阻塞

[Answer]: A

### Q3: 跨服务调用超时
注册时同步调用 points-service 初始化积分，调用超时时间设置：

- A) 3 秒超时，失败降级（推荐，避免长时间阻塞）
- B) 5 秒超时，失败降级
- C) 不设超时，等待 points-service 响应

[Answer]: A

### Q4: API 响应时间目标
认证服务的 API 响应时间目标（P95）：

- A) 宽松 — 500ms 以内（MVP 足够）
- B) 中等 — 200ms 以内（不含 bcrypt 操作）
- C) 不设目标 — MVP 阶段不关注性能指标

[Answer]: B

---

## 执行步骤

- [ ] 收集用户回答
- [ ] 分析回答，确认无歧义
- [ ] 生成 NFR 需求文档 `nfr-requirements.md`
- [ ] 生成技术栈决策文档 `tech-stack-decisions.md`
- [ ] 提交用户审批
