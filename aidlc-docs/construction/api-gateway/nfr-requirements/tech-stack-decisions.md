# Unit 6: api-gateway — 技术栈决策

---

## 1. 后端框架
- **决策**: Spring Cloud Gateway（基于 WebFlux 响应式框架）
- **特性**:
  - 响应式非阻塞 I/O
  - 基于 Netty 的高性能网关
  - 支持路由、过滤器、断言等功能
  - 与 Spring Boot 生态无缝集成

---

## 2. 令牌校验

### 校验方式
- **决策**: 远程校验 — 调用 auth-service 的令牌验证接口
- **端点**: `/api/v1/internal/auth/validate`
- **实现**: 使用 WebClient 发起异步 HTTP 调用
- **注意**: api-gateway 不持有 JWT 密钥，通过调用 auth-service 验证令牌

### 校验流程
1. 从请求头 `Authorization: Bearer <token>` 提取令牌
2. 通过 WebClient 调用 auth-service 的 `/api/v1/internal/auth/validate` 接口
3. auth-service 返回验证结果和用户信息（operatorId、role）
4. 验证成功后，网关注入 `X-Operator-Id` 和 `X-User-Role` 请求头转发给下游服务

### 性能特征
- 远程调用超时配置：5 秒
- 每次请求都需要调用 auth-service
- 响应时间取决于 auth-service 性能和网络延迟

---

## 3. 请求转发

### 超时配置
- 连接超时：1 秒
- 读取超时：2 秒
- 总超时：3 秒
- 所有下游服务统一超时配置

### 请求体限制
- 网关层不限制请求体大小
- 由 Nginx（client_max_body_size 10m）和下游微服务各自控制
- 文件上传请求正常透传

### 转发策略
- 保留完整请求路径（不去除前缀）
- 保留查询参数和请求体
- 注入 `X-Operator-Id` 请求头（从令牌验证结果中获取）
- 注入 `X-User-Role` 请求头（从令牌验证结果中获取）
- 清除客户端可能伪造的安全请求头
- **注意**: 网关会检查管理员端点的角色权限（ADMIN_ONLY），但具体业务权限由各业务服务自行验证

---

## 4. 路由配置

### 路由匹配策略
- 精确前缀匹配，按优先级从高到低
- `/api/v1/{service}/**` 路由到对应服务
- 路由规则使用 `metadata: auth-required: true/false` 控制是否需要认证
- 公开路径：`/api/v1/public/**`（如登录、注册等）
- 受保护路径：`/api/v1/{service}/**`（需要令牌验证）

### 目标服务地址

| 环境变量 | 默认值 | 目标服务 |
|---------|--------|---------|
| AUTH_SERVICE_URL | http://auth-service:8001 | 认证服务 |
| PRODUCT_SERVICE_URL | http://product-service:8002 | 产品服务 |
| POINTS_SERVICE_URL | http://points-service:8003 | 积分服务 |
| ORDER_SERVICE_URL | http://order-service:8004 | 兑换服务 |

### 认证配置
- 令牌验证端点：通过 `gateway.auth.validate-url` 配置
- WebClient 超时：5 秒

---

## 5. 性能目标

| 指标 | 目标值 | 说明 |
|------|--------|------|
| 网关自身处理开销 P95 | ≤ 100ms | 令牌远程验证 + 路由匹配 + 请求头处理 |
| 令牌验证超时 | 5s | 调用 auth-service 的超时时间 |
| 转发超时 | 3s | 连接 1s + 读取 2s |
| 端到端响应时间 | 取决于下游 | 网关开销 + 令牌验证 + 下游响应时间 |

---

## 6. 依赖关系

| 依赖 | 类型 | 说明 |
|------|------|------|
| auth-service (8001) | 运行时依赖（关键） | 令牌验证 + 路由转发目标 |
| product-service (8002) | 运行时依赖 | 路由转发目标 |
| points-service (8003) | 运行时依赖 | 路由转发目标 |
| order-service (8004) | 运行时依赖 | 路由转发目标 |
| Docker 网络 | 基础设施 | 内部服务通信 |

说明：
- api-gateway 不依赖数据库，是纯粹的无状态代理服务
- **api-gateway 不持有 JWT 密钥**，通过调用 auth-service 验证令牌
- auth-service 是网关的关键依赖，若 auth-service 不可用，所有需认证的请求都会失败
