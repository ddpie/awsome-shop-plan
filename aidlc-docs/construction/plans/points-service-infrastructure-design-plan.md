# Unit 4: points-service — 基础设施设计计划

---

## 前置条件
- [x] 功能设计已完成
- [x] NFR 需求已完成
- [x] NFR 设计已完成
- [x] Unit 7 基础设施设计已完成（Docker Compose、网络、数据库配置已定义）
- [x] Unit 2 基础设施设计已完成（端口 8001，可参考模式）
- [x] Unit 3 基础设施设计已完成（端口 8002，可参考模式）

---

## 设计问题

> 以下问题用于确认 points-service 特有的基础设施细节。
> Unit 7 已定义了整体 Docker Compose 编排、MySQL 配置、网络拓扑。
> 本阶段聚焦于 points-service 容器自身的运行配置。

### Q1: 服务端口配置

auth-service 使用 8001，product-service 使用 8002。points-service 的容器内部监听端口：

- A) 8003 — 按序递增
- B) 其他 — 请指定

[Answer]: A

### Q2: 容器健康检查

points-service 是否配置 Docker 健康检查端点（与 auth-service、product-service 一致）？

- A) 是 — 提供 `/actuator/health` 端点，Docker Compose 配置 healthcheck
- B) 否 — MVP 阶段不需要

[Answer]: A

### Q3: 容器内存限制

points-service 容器是否需要设置内存限制？

- A) 不设限制 — 与其他微服务一致（MVP 阶段不做资源限制）
- B) 设置建议值 — 请指定

[Answer]: A

---

## 执行步骤

- [ ] 收集用户回答
- [ ] 分析回答，确认无歧义
- [ ] 生成 infrastructure-design.md（容器配置、环境变量、网络连接、服务依赖）
- [ ] 生成 deployment-architecture.md（部署拓扑、启动依赖、请求流转路径）
- [ ] 提交用户审批
