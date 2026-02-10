# Unit 5: order-service — 基础设施设计计划

---

## 前置条件
- [x] 功能设计已完成
- [x] NFR 需求已完成
- [x] NFR 设计已完成
- [x] Unit 7 基础设施设计已完成（Docker Compose 基础配置已定义）
- [x] Unit 2/3/4 基础设施设计已完成（端口 8001/8002/8003 已分配）

---

## 基础设施设计问题

> 以下问题用于确认 order-service 的容器化部署配置。
> 通用决策沿用前序 Unit：Docker 内部网络、不对外暴露端口、健康检查端点。

### Q1: 端口配置
order-service 的内部端口（容器内应用监听端口）：

- A) 8004（延续 auth:8001, product:8002, points:8003 的递增规则）
- B) 其他端口（请指定）

[Answer]: A

### Q2: 健康检查端点
order-service 的健康检查端点（与其他微服务保持一致）：

- A) /actuator/health（与 auth/product/points 一致）
- B) 其他路径（请指定）

[Answer]: A

### Q3: 容器资源限制
order-service 是否需要设置容器内存限制：

- A) 不设限制（与其他微服务一致，MVP 阶段不限制）
- B) 设置限制（请指定）

[Answer]: A

---

## 执行步骤

- [x] 收集用户回答
- [x] 分析回答，确认无歧义
- [x] 生成 infrastructure-design.md（基础设施设计）
- [x] 生成 deployment-architecture.md（部署架构）
- [x] 同步更新 Unit 7 Docker Compose 中 order-service 的端口配置
- [ ] 提交用户审批
