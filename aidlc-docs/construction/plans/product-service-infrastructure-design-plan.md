# Unit 3: product-service — 基础设施设计计划

---

## 执行步骤

- [ ] 分析 Unit 3 功能设计、NFR 需求、NFR 设计
- [ ] 收集用户回答
- [ ] 生成基础设施设计文档（infrastructure-design.md）
- [ ] 生成部署架构文档（deployment-architecture.md）
- [ ] 更新执行计划

---

## 设计问题

### Q1: 容器内部端口

product-service 容器内应用监听端口选择：

- A) 8002（与 auth-service:8001 顺序递增）
- B) 8080（使用默认端口，与 Unit 7 原始定义一致）
- C) 其他端口（请指定）

[Answer]: A

### Q2: 健康检查端点

是否为 product-service 配置健康检查端点（与 auth-service 一致）？

- A) 是，使用 /actuator/health（与 auth-service 保持一致）
- B) 否，MVP 阶段不需要

[Answer]: A

### Q3: 图片上传卷挂载路径

图片文件的宿主机存储路径选择：

- A) ../uploads（工作区根目录下的 uploads/，与 Unit 7 docker-compose.yml 定义一致）
- B) ../product-service/uploads（放在 product-service 项目目录下）
- C) 其他路径（请指定）

[Answer]: A
