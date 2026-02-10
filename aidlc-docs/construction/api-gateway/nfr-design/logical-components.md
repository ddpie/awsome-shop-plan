# Unit 6: api-gateway — 逻辑组件

---

## 1. 组件清单

| 组件名称 | 职责 | 依赖 |
|---------|------|------|
| GatewayApplication | 应用入口，启动配置校验 | 配置加载器 |
| AuthenticationFilter | JWT 校验、用户信息提取 | JwtValidator |
| AuthorizationFilter | 权限级别判定、角色校验 | AccessRuleConfig |
| RequestHeaderProcessor | 请求头清除与注入 | - |
| RouteResolver | 路由匹配、目标服务解析 | RouteConfig |
| ProxyForwarder | 请求转发、超时处理 | HttpClient |
| ErrorHandler | 统一错误响应生成 | - |
| ConfigLoader | 环境变量加载、配置校验 | - |

---

## 2. 组件详细说明

### 2.1 GatewayApplication
**职责**: 应用启动入口，执行配置校验

**启动流程**:
1. 加载环境变量配置
2. 校验 JWT_SECRET 非空（失败则启动失败）
3. 初始化路由规则和权限规则
4. 启动 HTTP 服务监听 8080 端口

**依赖**:
- ConfigLoader: 配置加载
- RouteConfig: 路由规则初始化
- AccessRuleConfig: 权限规则初始化

---

### 2.2 AuthenticationFilter
**职责**: JWT 认证校验，提取用户信息

**处理流程**:
1. 检查请求是否需要认证（由 AuthorizationFilter 判定）
2. 从 Authorization 请求头提取 Bearer token
3. 调用 JwtValidator 校验 token
4. 提取 UserInfo 并存入请求上下文
5. 校验失败返回 401 + GW_001

**输入**:
- HTTP 请求
- 权限级别（PUBLIC 跳过认证）

**输出**:
- UserInfo（userId, username, role）或认证失败响应

**依赖**:
- JwtValidator: JWT 校验

---

### 2.3 JwtValidator
**职责**: JWT 签名校验、过期校验、payload 解析

**校验内容**:
1. 签名有效性（HS256 + JWT_SECRET）
2. 过期时间（exp 字段）
3. payload 必要字段（userId, username, role）
4. role 值合法性（EMPLOYEE 或 ADMIN）

**输入**:
- JWT token 字符串

**输出**:
- UserInfo 或抛出 UnauthorizedException

**配置依赖**:
- JWT_SECRET 环境变量

---

### 2.4 AuthorizationFilter
**职责**: 权限级别判定、角色校验

**处理流程**:
1. 根据请求路径和方法匹配权限规则
2. 判定访问级别（PUBLIC / AUTHENTICATED / ADMIN_ONLY）
3. ADMIN_ONLY 端点校验用户角色
4. 权限不足返回 403 + GW_002

**输入**:
- HTTP 请求（方法、路径）
- UserInfo（已认证请求）

**输出**:
- 通过或权限不足响应

**依赖**:
- AccessRuleConfig: 权限规则配置

---

### 2.5 AccessRuleConfig
**职责**: 权限规则集中配置

**规则结构**:
```
PUBLIC:
  - POST /api/auth/register
  - POST /api/auth/login

ADMIN_ONLY:
  - * /api/admin/*
  - POST /api/files/upload
  - DELETE /api/files/*

AUTHENTICATED:
  - * /api/*
```

**匹配优先级**: PUBLIC > ADMIN_ONLY > AUTHENTICATED

---

### 2.6 RequestHeaderProcessor
**职责**: 请求头安全处理

**处理流程**:
1. 清除客户端请求中的 X-User-Id 和 X-User-Role（防伪造）
2. 已认证请求注入 X-User-Id 和 X-User-Role
3. 保留其他业务请求头（Content-Type 等）

**输入**:
- HTTP 请求
- UserInfo（可为空）

**输出**:
- 处理后的请求

---

### 2.7 RouteResolver
**职责**: 路由匹配、目标服务解析

**处理流程**:
1. 根据请求路径匹配路由规则
2. 解析目标服务地址
3. 无匹配返回 null（触发 404）

**输入**:
- 请求路径

**输出**:
- 目标服务 URL 或 null

**依赖**:
- RouteConfig: 路由规则配置

---

### 2.8 RouteConfig
**职责**: 路由规则集中配置

**规则结构**:
```
routes:
  /api/auth/*         → AUTH_SERVICE_URL
  /api/admin/users/*  → AUTH_SERVICE_URL
  /api/admin/products/* → PRODUCT_SERVICE_URL
  /api/admin/categories/* → PRODUCT_SERVICE_URL
  /api/admin/points/* → POINTS_SERVICE_URL
  /api/admin/orders/* → ORDER_SERVICE_URL
  /api/products/*     → PRODUCT_SERVICE_URL
  /api/categories/*   → PRODUCT_SERVICE_URL
  /api/files/*        → PRODUCT_SERVICE_URL
  /api/points/*       → POINTS_SERVICE_URL
  /api/orders/*       → ORDER_SERVICE_URL
```

**配置来源**: 环境变量（AUTH_SERVICE_URL 等）

---

### 2.9 ProxyForwarder
**职责**: 请求转发、超时处理、错误捕获

**处理流程**:
1. 构建转发请求（保留路径、查询参数、请求体）
2. 设置超时（连接 1s + 读取 2s）
3. 执行转发
4. 连接失败返回 502 + GW_003
5. 超时返回 504 + GW_004
6. 正常响应透传

**输入**:
- 处理后的请求
- 目标服务 URL

**输出**:
- 下游响应或网关错误响应

**配置依赖**:
- CONNECT_TIMEOUT
- READ_TIMEOUT

---

### 2.10 ErrorHandler
**职责**: 统一错误响应生成

**错误码映射**:
| 错误码 | HTTP 状态码 | 消息 |
|--------|------------|------|
| GW_001 | 401 | 未授权，请先登录 |
| GW_002 | 403 | 权限不足 |
| GW_003 | 502 | 服务暂时不可用 |
| GW_004 | 504 | 请求超时 |
| GW_005 | 404 | 资源不存在 |

**响应格式**:
```json
{
  "code": "GW_XXX",
  "message": "错误描述",
  "data": null
}
```

---

### 2.11 ConfigLoader
**职责**: 环境变量加载、配置校验

**加载配置**:
| 变量 | 必填 | 默认值 |
|------|------|--------|
| JWT_SECRET | 是 | - |
| AUTH_SERVICE_URL | 否 | http://auth-service:8001 |
| PRODUCT_SERVICE_URL | 否 | http://product-service:8002 |
| POINTS_SERVICE_URL | 否 | http://points-service:8003 |
| ORDER_SERVICE_URL | 否 | http://order-service:8004 |
| CONNECT_TIMEOUT | 否 | 1000 |
| READ_TIMEOUT | 否 | 2000 |
| SERVER_PORT | 否 | 8080 |

**启动校验**:
- JWT_SECRET 为空 → 启动失败

---

## 3. 目录结构

```
api-gateway/
├── src/
│   └── main/
│       └── [language]/
│           └── com/awsomeshop/gateway/
│               ├── GatewayApplication.[ext]       # 应用入口
│               ├── filter/
│               │   ├── AuthenticationFilter.[ext] # JWT 认证过滤器
│               │   └── AuthorizationFilter.[ext]  # 权限校验过滤器
│               ├── security/
│               │   └── JwtValidator.[ext]         # JWT 校验器
│               ├── routing/
│               │   ├── RouteResolver.[ext]        # 路由解析器
│               │   └── ProxyForwarder.[ext]       # 请求转发器
│               ├── processor/
│               │   └── RequestHeaderProcessor.[ext] # 请求头处理器
│               ├── config/
│               │   ├── ConfigLoader.[ext]         # 配置加载器
│               │   ├── RouteConfig.[ext]          # 路由配置
│               │   └── AccessRuleConfig.[ext]     # 权限规则配置
│               ├── handler/
│               │   └── ErrorHandler.[ext]         # 错误处理器
│               └── model/
│                   └── UserInfo.[ext]             # 用户信息模型
├── src/
│   └── test/
│       └── [language]/
│           └── com/awsomeshop/gateway/
│               ├── security/
│               │   └── JwtValidatorTest.[ext]     # JWT 校验测试
│               ├── routing/
│               │   └── RouteResolverTest.[ext]    # 路由匹配测试
│               └── filter/
│                   └── AuthorizationFilterTest.[ext] # 权限校验测试
└── Dockerfile
```

说明：`[language]` 和 `[ext]` 将在实现阶段根据用户提供的技术框架确定。

---

## 4. 组件交互图

```
                                    ┌─────────────────┐
                                    │  ConfigLoader   │
                                    │  (启动时加载)    │
                                    └────────┬────────┘
                                             │
                                             ▼
┌──────────┐    ┌─────────────────────────────────────────────────────────────┐
│  客户端   │───▶│                    GatewayApplication                       │
└──────────┘    │                         :8080                               │
                └─────────────────────────────────────────────────────────────┘
                                             │
                                             ▼
                ┌─────────────────────────────────────────────────────────────┐
                │                     请求处理管道                              │
                │  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐   │
                │  │RouteResolver │─▶│Authorization │─▶│Authentication    │   │
                │  │(路由匹配)     │  │Filter        │  │Filter            │   │
                │  │              │  │(权限判定)     │  │(JWT校验)         │   │
                │  └──────────────┘  └──────────────┘  └──────────────────┘   │
                │         │                │                    │             │
                │         ▼                ▼                    ▼             │
                │  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐   │
                │  │ RouteConfig  │  │AccessRule    │  │  JwtValidator    │   │
                │  │              │  │Config        │  │                  │   │
                │  └──────────────┘  └──────────────┘  └──────────────────┘   │
                │                                                             │
                │  ┌──────────────────────────────────────────────────────┐   │
                │  │              RequestHeaderProcessor                  │   │
                │  │              (清除伪造头 + 注入用户信息)               │   │
                │  └──────────────────────────────────────────────────────┘   │
                │                            │                                │
                │                            ▼                                │
                │  ┌──────────────────────────────────────────────────────┐   │
                │  │                   ProxyForwarder                     │   │
                │  │                   (请求转发)                          │   │
                │  └──────────────────────────────────────────────────────┘   │
                │                            │                                │
                └────────────────────────────┼────────────────────────────────┘
                                             │
                    ┌────────────────────────┼────────────────────────┐
                    ▼                        ▼                        ▼
           ┌──────────────┐        ┌──────────────┐        ┌──────────────┐
           │auth-service  │        │product-service│       │points-service│
           │   :8001      │        │    :8002      │        │   :8003      │
           └──────────────┘        └──────────────┘        └──────────────┘
                                                                  │
                                             ┌────────────────────┘
                                             ▼
                                   ┌──────────────┐
                                   │order-service │
                                   │   :8004      │
                                   └──────────────┘
```

---

## 5. 请求处理时序

```
客户端                Gateway                  下游服务
  │                     │                        │
  │  HTTP Request       │                        │
  │────────────────────▶│                        │
  │                     │                        │
  │                     │ 1. RouteResolver       │
  │                     │    匹配路由            │
  │                     │                        │
  │                     │ 2. AuthorizationFilter │
  │                     │    判定权限级别        │
  │                     │                        │
  │                     │ 3. AuthenticationFilter│
  │                     │    JWT 校验            │
  │                     │                        │
  │                     │ 4. AuthorizationFilter │
  │                     │    角色校验(ADMIN_ONLY)│
  │                     │                        │
  │                     │ 5. RequestHeaderProcessor
  │                     │    清除+注入请求头     │
  │                     │                        │
  │                     │ 6. ProxyForwarder      │
  │                     │────────────────────────▶
  │                     │                        │
  │                     │◀────────────────────────
  │                     │    下游响应            │
  │                     │                        │
  │◀────────────────────│ 7. 透传响应           │
  │    HTTP Response    │                        │
```

---

## 6. NFR 需求覆盖映射

| NFR 需求 | 覆盖组件 |
|---------|---------|
| NFR-GW-SEC-001 | JwtValidator, ConfigLoader |
| NFR-GW-SEC-002 | RequestHeaderProcessor |
| NFR-GW-SEC-003 | JwtValidator, ErrorHandler |
| NFR-GW-SEC-004 | JwtValidator, AuthorizationFilter |
| NFR-GW-SEC-005 | RouteResolver |
| NFR-GW-PERF-001 | 全组件（实现层面优化） |
| NFR-GW-PERF-002 | ProxyForwarder |
| NFR-GW-PERF-003 | 全组件（无状态设计） |
| NFR-GW-REL-001 | ProxyForwarder, ErrorHandler |
| NFR-GW-REL-002 | ProxyForwarder |
| NFR-GW-REL-003 | GatewayApplication, ConfigLoader |
| NFR-GW-MAINT-001 | ErrorHandler |
| NFR-GW-MAINT-002 | 全组件（日志记录） |
| NFR-GW-MAINT-003 | ConfigLoader |
| NFR-GW-MAINT-004 | RouteConfig, AccessRuleConfig |
| NFR-GW-TEST-001 | JwtValidator（可测试设计） |
| NFR-GW-TEST-002 | RouteResolver（可测试设计） |
| NFR-GW-TEST-003 | AuthorizationFilter（可测试设计） |

**覆盖率**: 18/18 (100%)
