# AWSomeShop 应用设计计划

## 计划概述

基于需求文档和用户故事，设计 AWSomeShop 的组件结构、服务层和依赖关系。

---

## 第一部分：设计问题

### Question 1
前后端 API 通信风格偏好是什么？

A) RESTful API — 标准的资源导向 HTTP API
B) GraphQL — 灵活的查询语言，客户端按需获取数据
C) RESTful API + WebSocket — REST 为主，WebSocket 用于实时通知
D) Other (please describe after [Answer]: tag below)

[Answer]: A

### Question 2
后端架构分层偏好是什么？

A) 经典三层架构 — Controller → Service → Repository
B) 六边形架构（端口与适配器）— 核心业务逻辑与外部依赖解耦
C) CQRS — 读写分离架构
D) Other (please describe after [Answer]: tag below)

[Answer]: 会提供后端架构分层的框架

### Question 3
积分自动发放的实现方式偏好是什么？

A) 定时任务（Cron Job）— 后端服务内置定时调度器
B) 消息队列 — 使用消息中间件触发定时任务
C) 数据库触发器 + 存储过程 — 数据库层面实现
D) MVP 阶段使用简单的定时任务，后续可升级
E) Other (please describe after [Answer]: tag below)

[Answer]: A

### Question 4
文件/图片存储方案偏好是什么？

A) 产品图片使用外部 URL 引用（不涉及文件上传）
B) 本地文件系统存储（Docker 卷挂载）
C) 对象存储服务（如 MinIO，Docker 部署）
D) Other (please describe after [Answer]: tag below)

[Answer]: B

---

## 第二部分：设计执行步骤

以下步骤将在问题回答并批准后执行：

- [x] 步骤 1：生成组件定义文档（components.md）
  - [x] 定义前端组件模块
  - [x] 定义后端组件模块
  - [x] 定义数据访问层组件
  - [x] 描述每个组件的职责和接口

- [x] 步骤 2：生成组件方法文档（component-methods.md）
  - [x] 定义各组件的方法签名
  - [x] 描述方法的输入/输出类型
  - [x] 标注方法的高层用途

- [x] 步骤 3：生成服务层文档（services.md）
  - [x] 定义服务编排模式
  - [x] 描述服务间的交互流程
  - [x] 定义跨组件的业务流程编排

- [x] 步骤 4：生成组件依赖文档（component-dependency.md）
  - [x] 创建依赖关系矩阵
  - [x] 描述组件间通信模式
  - [x] 绘制数据流图

- [x] 步骤 5：设计验证
  - [x] 验证设计覆盖所有功能需求
  - [x] 检查组件职责无重叠
  - [x] 确认依赖关系无循环
