# Unit 7: infrastructure — NFR 需求计划

## 计划概述

基于 Unit 7 功能设计，确定基础设施层面的非功能性需求和技术选型。

---

## 第一部分：NFR 问题

### Question 1
MySQL 版本偏好？

A) MySQL 8.0（LTS，推荐）
B) MySQL 8.4（最新 LTS）
C) Other (please describe after [Answer]: tag below)

[Answer]:B

### Question 2
MySQL 数据备份策略（MVP 阶段）？

A) 不需要自动备份，手动管理即可
B) Docker 卷挂载到宿主机，依赖宿主机文件系统备份
C) Other (please describe after [Answer]: tag below)

[Answer]:B

### Question 3
Docker Compose 中是否需要资源限制（CPU/内存）？

A) MVP 阶段不设限制，简化配置
B) 设置基础限制，防止单个服务占用过多资源
C) Other (please describe after [Answer]: tag below)

[Answer]:A

### Question 4
日志管理策略？

A) 各服务输出到 stdout/stderr，由 Docker 统一管理（docker logs）
B) 各服务输出到 stdout/stderr + 配置 Docker 日志驱动限制日志大小
C) Other (please describe after [Answer]: tag below)

[Answer]:后端技术框架有日志规范

---

## 第二部分：生成执行步骤

- [x] 步骤 1：定义基础设施 NFR 需求
  - [x] 数据库可靠性与持久化需求
  - [x] 容器运行环境需求
  - [x] 安全配置需求
  - [x] 日志与可观测性需求

- [x] 步骤 2：确定技术选型
  - [x] MySQL 版本与配置
  - [x] Docker / Docker Compose 版本要求
  - [x] 网络与安全策略

- [x] 步骤 3：验证
  - [x] NFR 需求与功能设计一致性
  - [x] 技术选型可行性
