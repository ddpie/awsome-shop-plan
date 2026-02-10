# Unit 7: infrastructure — 功能设计计划

## 计划概述

Unit 7 (infrastructure) 是基础设施单元，不包含业务逻辑。其功能设计聚焦于：
- 数据库 Schema 设计（所有微服务共享的 MySQL 实例）
- Docker Compose 服务编排
- 网络拓扑与端口规划
- 环境变量与配置管理
- 数据库初始化与种子数据

---

## 第一部分：设计问题

### Question 1
微服务的数据库隔离策略是什么？

A) 共享数据库 — 所有微服务连接同一个 MySQL 实例和同一个 database，通过表前缀区分
B) 独立 Schema — 同一个 MySQL 实例，每个微服务使用独立的 database（如 auth_db, product_db, points_db, order_db）
C) Other (please describe after [Answer]: tag below)

[Answer]:B

### Question 2
Docker Compose 中各微服务的端口映射策略是什么？

A) 仅暴露 API 网关端口（如 8080），其他微服务仅在 Docker 内部网络通信，不映射宿主机端口
B) 所有服务都映射宿主机端口，便于开发调试（如 auth:8081, product:8082, points:8083, order:8084, gateway:8080）
C) Other (please describe after [Answer]: tag below)

[Answer]:A

### Question 3
MySQL 数据库是否需要初始化种子数据？

A) 仅建表，不插入种子数据
B) 建表 + 插入基础种子数据（如默认管理员账号、默认积分发放配置、示例产品分类）
C) Other (please describe after [Answer]: tag below)

[Answer]:B

---

## 第二部分：生成执行步骤

以下步骤将在问题回答并批准后执行：

- [x] 步骤 1：设计数据库 Schema
  - [x] 定义所有数据表结构（字段、类型、约束、索引）
  - [x] 定义表间外键关系
  - [x] 设计数据库初始化脚本（init.sql）

- [x] 步骤 2：设计 Docker Compose 编排
  - [x] 定义所有服务（MySQL、auth、product、points、order、gateway、frontend）
  - [x] 定义网络拓扑和服务间通信
  - [x] 定义端口映射和卷挂载

- [x] 步骤 3：设计环境配置
  - [x] 定义环境变量模板（.env.example）
  - [x] 定义各服务的配置项（数据库连接、JWT 密钥、服务发现地址等）

- [x] 步骤 4：验证
  - [x] 验证 Schema 覆盖所有业务需求
  - [x] 验证服务编排完整性
  - [x] 验证配置一致性
