# Unit 6: api-gateway — NFR 需求计划

---

## 前置条件
- [x] 功能设计已完成
- [x] Unit 7 NFR 需求已完成（基础设施层 NFR 已定义）
- [x] Unit 2/3/4/5 NFR 需求已完成（可参考微服务 NFR 模式）

---

## NFR 需求问题

> 以下问题用于确认 api-gateway 特有的非功能性需求。
> 通用决策沿用前序 Unit：技术框架延后、日志遵循框架规范、不设容器资源限制。
> api-gateway 作为所有请求的统一入口，其 NFR 需求侧重于性能、安全和可靠性。

### Q1: 网关转发超时配置
api-gateway 转发请求到下游微服务的超时时间：

- A) 与 order-service 跨服务调用一致（连接 1s + 读取 2s = 总计 3s）
- B) 更宽松（连接 1s + 读取 5s = 总计 6s），考虑兑换流程下游可能耗时较长
- C) 按下游服务区分（查询类 3s，写入类 6s）

[Answer]: A

### Q2: 网关层请求体大小限制
api-gateway 是否需要限制请求体大小（文件上传由 Nginx 的 client_max_body_size 控制，网关层是否额外限制）：

- A) 不限制 — 由 Nginx 和下游微服务各自控制
- B) 限制 — 网关层统一限制（请指定大小）

[Answer]: A

### Q3: 网关响应时间目标
api-gateway 自身处理开销（JWT 校验 + 路由匹配 + 请求头处理，不含下游响应时间）的 P95 目标：

- A) ≤ 10ms（JWT 校验为纯计算操作，应极快）
- B) ≤ 50ms（留有余量）
- C) 不设目标 — MVP 阶段不关注

[Answer]: B

---

## 执行步骤

- [x] 收集用户回答
- [x] 分析回答，确认无歧义
- [ ] 生成 nfr-requirements.md（NFR 需求清单）
- [ ] 生成 tech-stack-decisions.md（技术栈决策）
- [ ] 提交用户审批
