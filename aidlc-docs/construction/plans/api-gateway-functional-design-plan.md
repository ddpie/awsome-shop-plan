# Unit 6: api-gateway — 功能设计计划

---

## 前置条件
- [x] 工作单元定义已完成（Unit 6 职责、路由规则、权限规则已明确）
- [x] 应用设计已完成（横切关注点、服务编排已定义）
- [x] Unit 2 auth-service 功能设计已完成（JWT 结构、签名算法已确定）
- [x] Unit 2/3/4/5 基础设施设计已完成（所有微服务端口已确定）

---

## 功能设计问题

> 以下问题用于确认 api-gateway 的业务逻辑细节。
> 已知信息：JWT HS256 签名、共享 JWT_SECRET、路由规则和权限规则已在应用设计中定义。

### Q1: JWT 校验失败的处理方式
当 JWT 令牌校验失败（过期、签名无效、格式错误）时，网关的响应策略：

- A) 统一返回 401 Unauthorized，响应体遵循统一错误格式 `{ code: "GW_001", message: "..." }`
- B) 区分不同失败原因返回不同错误码（过期 GW_001、签名无效 GW_002、格式错误 GW_003）

[Answer]: A

### Q2: 请求头注入策略
网关校验 JWT 通过后，向下游微服务转发请求时注入的用户信息：

- A) 仅注入 X-User-Id 和 X-User-Role（最小信息，微服务按需查询）
- B) 注入 X-User-Id、X-User-Role、X-Username（减少微服务查询用户信息的需要）

[Answer]: A

### Q3: 文件上传端点的权限
文件上传接口 POST /api/files/upload 的权限要求：

- A) 仅管理员可上传（文件上传仅用于产品图片管理）
- B) 所有已认证用户可上传

[Answer]: A

### Q4: 管理员端点路由细分
/api/admin/* 路由到不同微服务的匹配策略：

- A) 精确前缀匹配（/api/admin/products/* → product-service, /api/admin/orders/* → order-service 等）
- B) 统一路由到一个管理服务，由管理服务再分发

[Answer]: A

---

## 执行步骤

- [x] 收集用户回答
- [x] 分析回答，确认无歧义
- [x] 生成 domain-entities.md（领域实体与配置定义）
- [x] 生成 business-logic-model.md（业务逻辑模型）
- [x] 生成 business-rules.md（业务规则）
- [ ] 提交用户审批
