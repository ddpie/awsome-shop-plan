# AWSomeShop 项目审查发现

> 审查范围：inception + construction 设计文档 vs 已实现代码，共 29 份文档
> 审查日期：2026-03-18

---

## 一、已修复的文档问题

### 1. API 路径不一致

| 位置 | 文档写法 | 代码实际 |
|------|---------|---------|
| 多处 | `/auth/**`, `/products/**` | `/api/v1/auth/**`, `/api/v1/product/**` |
| 积分服务 | `/api/v1/points/**`（复数） | `/api/v1/point/**`（单数） |
| 前端管理 | `/api/v1/admin/*` | 不存在，管理功能在各服务内部鉴权 |

### 2. 网关认证模型错误

- **文档描述**：网关持有 JWT 密钥，本地校验令牌
- **代码实现**：网关通过 WebClient 调用 auth-service `/api/v1/internal/auth/validate` 远程校验
- **文档遗漏**：未提及 `X-User-Role` 请求头注入（代码仅注入了 `X-Operator-Id`，设计决策要求两者都注入）

### 3. 分类管理不存在

- **文档描述**：独立 Category 实体、categories 表、BE-CATEGORY 组件、分类 CRUD API
- **代码实现**：Product 表中 `category VARCHAR(100)` 字符串字段，无独立分类表

### 4. 分布式事务策略错误

- **文档描述**：兑换流程在"同一事务"中完成积分扣除 + 库存扣减 + 订单创建
- **代码实现**：跨服务调用，无法使用本地事务
- **修正为**：Saga 最大努力补偿模式（顺序执行，失败逆序回滚）

### 5. Product 实体字段严重过时

文档仅列出 7 个基础字段，代码实际有 20+ 字段：`sku`, `brand`, `subtitle`, `mainImage`, `images`, `colors`, `specs`, `deliveryMethod`, `serviceGuarantee`, `promotion`, `soldCount`, `version`, `deleted` 等全部缺失。

### 6. 工作单元目录结构过时

- **文档描述**：简单的 `controller/service/mapper` 三层结构
- **代码实现**：DDD 六边形架构 + Maven 多模块（`bootstrap → domain → application → interface → infrastructure`）

### 7. 积分自动发放流程错误

- **文档描述**：查询 DA-USER 获取所有用户
- **代码实现**：直接查询 `point_balances` 表，不依赖 auth-service

### 8. 错误码格式不统一

- **文档各处**：混用 `AUTH_001`、`PRODUCT_NOT_FOUND`、`INSUFFICIENT_POINTS` 等
- **修正为**：统一 `{HTTP_SEMANTIC}_{NUMBER}` 格式（如 `NOT_FOUND_001`、`CONFLICT_001`）

### 9. 基础设施配置缺失

- Docker Compose 中缺少 Redis 服务定义
- 缺少 Flyway 数据库迁移说明
- 服务 build context 路径与实际目录不匹配

### 10. 执行计划状态不准确

- aidlc-state.md 中多个已完成的设计阶段仍标记为未完成

---

## 二、待修复的代码问题

> 用户要求本轮不改代码，以下问题留待代码生成阶段处理。

### 文档-代码对齐

| 项目 | 代码现状 | 文档目标 |
|------|---------|---------|
| JWT 过期时间 | `expiration=7200`（2小时） | 86400s（24小时） |
| 库存锁策略 | `@Version` 乐观锁 | SELECT FOR UPDATE 悲观锁 |
| 网关请求头 | 仅注入 `X-Operator-Id` | 需同时注入 `X-User-Role` |
| Auth validate 响应 | 未包含 `role` 字段 | 需返回 `{ success, operatorId, role, message }` |

### 安全漏洞

| 编号 | 问题 | 风险 |
|------|------|------|
| S1 | 网关未清除客户端伪造的 `X-Operator-Id` 请求头 | 身份伪造 |
| S2 | Swagger 代理路由（`/auth/**` 等）绕过认证过滤器 | 未授权访问 |
| S3 | `/api/v1/internal/*` 内部接口未在网关层拦截 | 内部接口暴露 |
| S4 | `/actuator` 端点对外暴露 | 敏感信息泄露 |

---

## 三、未实现的功能模块

| 服务 | 缺失内容 |
|------|---------|
| auth-service | 完整业务逻辑（仅有框架骨架） |
| points-service | 全部业务实现 |
| order-service | 全部业务实现 + 跨服务调用客户端 |
| product-service | 文件上传、内部 API、category 简化 |
| frontend | 14 个页面、真实 API 对接、Vite 代理配置 |
| infrastructure | docker-compose、SQL 初始化脚本、环境变量模板 |
