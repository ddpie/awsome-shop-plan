# Unit 2: auth-service — 基础设施设计计划

---

## 前置条件
- [x] 功能设计已完成
- [x] NFR 需求已完成
- [x] NFR 设计已完成
- [x] Unit 7 基础设施设计已完成（Docker Compose、网络、数据库配置已定义）

---

## 设计问题

> 以下问题用于确认 auth-service 特有的基础设施细节。
> Unit 7 已定义了整体 Docker Compose 编排、MySQL 配置、网络拓扑。
> 本阶段聚焦于 auth-service 容器自身的运行配置。

### Q1: 服务端口配置

auth-service 容器内部监听端口已在 Docker Compose 中定义为 8080，且不对外暴露（仅通过 Docker 网络内部访问）。是否需要调整？

- A) 保持现状 — 内部端口 8080，不对外暴露，仅 api-gateway 和其他微服务通过 Docker DNS 访问
- B) 开发阶段额外暴露端口 — 映射到宿主机某端口，方便本地调试（生产不暴露）

[Answer]: A，但是端口改用8001

### Q2: 容器健康检查

auth-service 是否需要配置 Docker 健康检查端点？

- A) 是 — 提供 `/actuator/health` 或类似端点，Docker Compose 配置 healthcheck
- B) 否 — MVP 阶段不需要，依赖 Docker 默认的进程存活检测

[Answer]:A

### Q3: JVM / 运行时内存限制

auth-service 容器是否需要设置内存限制？（此问题仅在使用 JVM 类语言时相关）

- A) 不设限制 — MVP 阶段不做资源限制（与 Unit 7 NFR 决策一致）
- B) 设置建议值 — 例如 512MB，防止单个服务占用过多资源

[Answer]: A

---

## 执行步骤

- [ ] 收集用户回答
- [ ] 分析回答，确认无歧义
- [ ] 生成 infrastructure-design.md（容器配置、环境变量、网络连接、服务依赖）
- [ ] 生成 deployment-architecture.md（部署拓扑、启动依赖、请求流转路径）
- [ ] 提交用户审批
