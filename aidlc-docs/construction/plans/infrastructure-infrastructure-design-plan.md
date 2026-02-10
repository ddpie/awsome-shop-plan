# Unit 7: infrastructure — 基础设施设计计划

## 目标
将 Unit 7 的逻辑组件（Docker Compose 编排、MySQL 初始化脚本、环境配置）映射到实际的部署基础设施和具体实现细节。

---

## 设计问题

### Q1: Docker Compose 文件版本与项目名称
Docker Compose V2 不再需要 `version` 字段。项目名称（project name）会影响容器名、网络名、卷名的前缀。

- A) 使用目录名作为项目名（默认行为）
- B) 在 docker-compose.yml 中显式指定 `name: awsomeshop`

[Answer]: B

### Q2: MySQL 端口暴露策略
前序设计中 MySQL 3306 暴露到宿主机用于开发调试。是否需要提供一个生产配置（不暴露 MySQL 端口）？

- A) 只提供一份 docker-compose.yml，MySQL 暴露 3306（开发用）
- B) 提供两份：docker-compose.yml（开发，暴露 3306）+ docker-compose.prod.yml（生产，不暴露）

[Answer]: A

### Q3: 前端 Nginx 配置
前端 SPA 需要 Nginx 配置来处理静态文件服务和 API 反向代理。API 反向代理的路径规则：

- A) 前端容器内 Nginx 将 `/api/*` 反向代理到 api-gateway，前端和网关在同一个 Docker 网络
- B) 前端直接通过浏览器访问 api-gateway 的宿主机端口（需要处理 CORS）

[Answer]: A

---

## 执行步骤

- [ ] 收集用户回答
- [ ] 分析回答，确认无歧义
- [ ] 生成基础设施设计文档 `infrastructure-design.md`（Docker Compose 完整配置、Nginx 配置、目录结构）
- [ ] 生成部署架构文档 `deployment-architecture.md`（部署拓扑图、端口映射、卷映射、启动流程）
- [ ] 提交用户审批
