# Unit 6: api-gateway — NFR 设计模式

---

## 1. JWT 认证安全模式

### 模式描述
统一的 JWT 校验机制，确保所有受保护端点的认证安全。

### 设计要点
- **签名算法**: HS256（HMAC-SHA256），与 auth-service 共享密钥
- **密钥管理**: JWT_SECRET 通过环境变量注入，启动时校验非空
- **统一失败响应**: 所有校验失败场景返回相同的 401 + GW_001，不泄露具体原因
- **校验内容**: 签名有效性 → 过期时间 → payload 字段完整性 → role 值合法性

### 实现伪代码
```
function validateJwt(token):
    try:
        payload = jwt.verify(token, JWT_SECRET, algorithm=HS256)
        
        // 校验必要字段
        if not payload.userId or not payload.username or not payload.role:
            throw InvalidTokenException
        
        // 校验 role 合法性
        if payload.role not in ['EMPLOYEE', 'ADMIN']:
            throw InvalidTokenException
        
        return UserInfo(payload.userId, payload.username, payload.role)
    catch any:
        // 统一返回，不区分具体原因
        throw UnauthorizedException(code="GW_001", message="未授权，请先登录")
```

### 覆盖 NFR
- NFR-GW-SEC-001: JWT 签名安全
- NFR-GW-SEC-003: 统一认证失败响应
- NFR-GW-SEC-004: 输入校验
- NFR-GW-REL-003: 启动依赖

---

## 2. 请求头防伪造模式

### 模式描述
防止客户端伪造用户身份请求头，确保下游微服务收到的用户信息可信。

### 设计要点
- **清除阶段**: 转发前无条件清除客户端请求中的 X-User-Id 和 X-User-Role
- **注入阶段**: 仅对已认证请求，从 JWT 解析后注入可信的用户信息
- **执行顺序**: 先清除 → 后注入（确保注入的值覆盖任何残留）

### 实现伪代码
```
function processRequestHeaders(request, userInfo):
    // 1. 无条件清除（防伪造）
    request.headers.remove("X-User-Id")
    request.headers.remove("X-User-Role")
    
    // 2. 仅已认证请求注入
    if userInfo != null:
        request.headers.set("X-User-Id", userInfo.userId)
        request.headers.set("X-User-Role", userInfo.role)
    
    return request
```

### 覆盖 NFR
- NFR-GW-SEC-002: 请求头防伪造

---

## 3. 分层权限控制模式

### 模式描述
三级权限控制（PUBLIC / AUTHENTICATED / ADMIN_ONLY），集中定义，便于维护。

### 设计要点
- **权限规则集中定义**: 所有端点的访问级别在配置中集中管理
- **匹配优先级**: 精确规则优先于通配规则
- **判定流程**: 路由匹配 → 权限级别判定 → 认证校验 → 角色校验

### 权限规则配置结构
```
accessRules:
  PUBLIC:
    - POST /api/auth/register
    - POST /api/auth/login
  
  ADMIN_ONLY:
    - * /api/admin/*
    - POST /api/files/upload
    - DELETE /api/files/*
  
  AUTHENTICATED:
    - * /api/*  # 默认规则，最低优先级
```

### 实现伪代码
```
function determineAccessLevel(method, path):
    // 按优先级从高到低匹配
    for rule in PUBLIC_RULES:
        if matches(method, path, rule):
            return PUBLIC
    
    for rule in ADMIN_ONLY_RULES:
        if matches(method, path, rule):
            return ADMIN_ONLY
    
    for rule in AUTHENTICATED_RULES:
        if matches(method, path, rule):
            return AUTHENTICATED
    
    return NOT_FOUND  // 无匹配路由
```

### 覆盖 NFR
- NFR-GW-SEC-004: 输入校验（role 值校验）
- NFR-GW-MAINT-004: 路由配置可维护
- NFR-GW-TEST-003: 权限逻辑可测试

---

## 4. 精确前缀路由模式

### 模式描述
基于 URL 前缀的路由匹配，将请求转发到对应的下游微服务。

### 设计要点
- **匹配策略**: 精确前缀匹配，按优先级从高到低
- **路径保留**: 转发时保留完整请求路径，不去除前缀
- **配置外部化**: 目标服务地址通过环境变量配置

### 路由规则配置结构
```
routes:
  - prefix: /api/auth
    target: ${AUTH_SERVICE_URL}      # http://auth-service:8001
    priority: 100
  
  - prefix: /api/admin/users
    target: ${AUTH_SERVICE_URL}
    priority: 90
  
  - prefix: /api/admin/products
    target: ${PRODUCT_SERVICE_URL}   # http://product-service:8002
    priority: 90
  
  - prefix: /api/admin/categories
    target: ${PRODUCT_SERVICE_URL}
    priority: 90
  
  - prefix: /api/admin/points
    target: ${POINTS_SERVICE_URL}    # http://points-service:8003
    priority: 90
  
  - prefix: /api/admin/orders
    target: ${ORDER_SERVICE_URL}     # http://order-service:8004
    priority: 90
  
  - prefix: /api/products
    target: ${PRODUCT_SERVICE_URL}
    priority: 80
  
  - prefix: /api/categories
    target: ${PRODUCT_SERVICE_URL}
    priority: 80
  
  - prefix: /api/files
    target: ${PRODUCT_SERVICE_URL}
    priority: 80
  
  - prefix: /api/points
    target: ${POINTS_SERVICE_URL}
    priority: 80
  
  - prefix: /api/orders
    target: ${ORDER_SERVICE_URL}
    priority: 80
```

### 实现伪代码
```
function matchRoute(path):
    // 按优先级排序后匹配
    for route in sortedRoutes:
        if path.startsWith(route.prefix):
            return route.target
    
    return null  // 无匹配，返回 404
```

### 覆盖 NFR
- NFR-GW-MAINT-004: 路由配置可维护
- NFR-GW-TEST-002: 路由逻辑可测试

---

## 5. 下游容错与错误透传模式

### 模式描述
区分网关层错误和下游业务错误，网关层错误使用 GW_ 错误码，下游错误原样透传。

### 设计要点
- **连接失败**: 返回 502 + GW_003（服务暂时不可用）
- **响应超时**: 返回 504 + GW_004（请求超时）
- **下游错误**: 原样透传（不修改状态码和响应体）
- **不重试**: 网关层不做自动重试，由调用方或下游服务处理

### 超时配置
```
timeout:
  connect: 1000ms   # 连接超时
  read: 2000ms      # 读取超时
  total: 3000ms     # 总超时
```

### 实现伪代码
```
function forwardRequest(request, targetUrl):
    try:
        response = httpClient.forward(request, targetUrl, timeout=3s)
        return response  // 透传，包括 4xx/5xx
    catch ConnectionException:
        return ErrorResponse(502, code="GW_003", message="服务暂时不可用")
    catch TimeoutException:
        return ErrorResponse(504, code="GW_004", message="请求超时")
```

### 覆盖 NFR
- NFR-GW-PERF-002: 转发超时
- NFR-GW-REL-001: 下游不可达处理
- NFR-GW-REL-002: 下游错误透传

---

## 6. 无状态设计模式

### 模式描述
网关不维护任何会话状态，每个请求独立处理，支持水平扩展。

### 设计要点
- **无会话存储**: 不使用 Session、不存储用户状态
- **无本地缓存**: 不缓存 JWT 校验结果或路由信息
- **请求独立**: 每个请求携带完整的认证信息（JWT）
- **可扩展性**: 支持多实例部署（虽然 MVP 阶段单实例）

### 实现约束
```
禁止:
  - 使用 HttpSession
  - 使用本地缓存存储用户信息
  - 依赖前序请求的状态
  - 使用 static 变量存储请求相关数据

允许:
  - 启动时加载的配置（路由规则、权限规则）
  - 环境变量读取的配置值
```

### 覆盖 NFR
- NFR-GW-PERF-003: 无状态设计

---

## 7. 内部接口隔离模式

### 模式描述
阻止外部请求访问微服务间的内部接口，确保内部接口仅在 Docker 网络内可用。

### 设计要点
- **路径识别**: /api/internal/* 路径为内部接口
- **网关拦截**: 网关不路由内部接口请求，直接返回 404
- **网络隔离**: 内部接口仅通过 Docker 内部网络服务间直接调用

### 实现伪代码
```
function handleRequest(request):
    path = request.path
    
    // 内部接口隔离
    if path.startsWith("/api/internal/"):
        return ErrorResponse(404, code="GW_005", message="资源不存在")
    
    // 正常路由处理
    return routeAndForward(request)
```

### 覆盖 NFR
- NFR-GW-SEC-005: 内部接口隔离

---

## 8. 统一错误响应模式

### 模式描述
网关层错误遵循统一的响应格式，与其他微服务保持一致。

### 错误响应格式
```json
{
  "code": "GW_XXX",
  "message": "错误描述",
  "data": null
}
```

### 网关错误码汇总

| 错误码 | HTTP 状态码 | 描述 | 触发场景 |
|--------|------------|------|---------|
| GW_001 | 401 | 未授权，请先登录 | JWT 缺失/无效/过期/格式错误 |
| GW_002 | 403 | 权限不足 | 非管理员访问 ADMIN_ONLY 端点 |
| GW_003 | 502 | 服务暂时不可用 | 下游微服务连接失败 |
| GW_004 | 504 | 请求超时 | 下游微服务响应超时 |
| GW_005 | 404 | 资源不存在 | 请求内部接口或无匹配路由 |

### 覆盖 NFR
- NFR-GW-MAINT-001: 统一错误响应格式

---

## 9. 日志记录模式

### 模式描述
关键操作记录日志，便于问题排查和安全审计。

### 日志记录点

| 事件 | 日志级别 | 记录内容 |
|------|---------|---------|
| 认证失败 | WARN | 请求路径、客户端 IP、失败原因（内部） |
| 权限校验失败 | WARN | 请求路径、用户 ID、用户角色、所需角色 |
| 下游连接失败 | WARN | 目标服务 URL、错误信息 |
| 下游响应超时 | WARN | 目标服务 URL、超时时间 |
| 请求转发成功 | DEBUG | 请求路径、目标服务、响应状态码、耗时 |

### 实现伪代码
```
function logAuthFailure(request, reason):
    logger.warn("认证失败: path={}, clientIp={}, reason={}",
        request.path, request.clientIp, reason)

function logPermissionDenied(request, userInfo, requiredRole):
    logger.warn("权限不足: path={}, userId={}, userRole={}, requiredRole={}",
        request.path, userInfo.userId, userInfo.role, requiredRole)

function logDownstreamError(targetUrl, error):
    logger.warn("下游服务错误: target={}, error={}",
        targetUrl, error.message)
```

### 覆盖 NFR
- NFR-GW-MAINT-002: 日志规范

---

## 10. 配置外部化模式

### 模式描述
所有可变配置通过环境变量注入，支持不同环境部署。

### 环境变量清单

| 变量名 | 必填 | 默认值 | 说明 |
|--------|------|--------|------|
| JWT_SECRET | 是 | - | JWT 签名密钥，启动时校验非空 |
| AUTH_SERVICE_URL | 否 | http://auth-service:8001 | 认证服务地址 |
| PRODUCT_SERVICE_URL | 否 | http://product-service:8002 | 产品服务地址 |
| POINTS_SERVICE_URL | 否 | http://points-service:8003 | 积分服务地址 |
| ORDER_SERVICE_URL | 否 | http://order-service:8004 | 兑换服务地址 |
| CONNECT_TIMEOUT | 否 | 1000 | 连接超时（毫秒） |
| READ_TIMEOUT | 否 | 2000 | 读取超时（毫秒） |
| SERVER_PORT | 否 | 8080 | 服务端口 |

### 启动校验
```
function validateConfig():
    if JWT_SECRET is empty:
        throw StartupException("JWT_SECRET 环境变量未配置")
    
    logger.info("配置加载完成: authService={}, productService={}, ...",
        AUTH_SERVICE_URL, PRODUCT_SERVICE_URL, ...)
```

### 覆盖 NFR
- NFR-GW-MAINT-003: 配置外部化
- NFR-GW-REL-003: 启动依赖

---

## 设计模式覆盖映射

| NFR 需求 | 覆盖设计模式 |
|---------|-------------|
| NFR-GW-SEC-001 | JWT 认证安全模式 |
| NFR-GW-SEC-002 | 请求头防伪造模式 |
| NFR-GW-SEC-003 | JWT 认证安全模式 |
| NFR-GW-SEC-004 | JWT 认证安全模式、分层权限控制模式 |
| NFR-GW-SEC-005 | 内部接口隔离模式 |
| NFR-GW-PERF-001 | （实现层面优化，无特定模式） |
| NFR-GW-PERF-002 | 下游容错与错误透传模式 |
| NFR-GW-PERF-003 | 无状态设计模式 |
| NFR-GW-REL-001 | 下游容错与错误透传模式 |
| NFR-GW-REL-002 | 下游容错与错误透传模式 |
| NFR-GW-REL-003 | JWT 认证安全模式、配置外部化模式 |
| NFR-GW-MAINT-001 | 统一错误响应模式 |
| NFR-GW-MAINT-002 | 日志记录模式 |
| NFR-GW-MAINT-003 | 配置外部化模式 |
| NFR-GW-MAINT-004 | 精确前缀路由模式、分层权限控制模式 |
| NFR-GW-TEST-001 | JWT 认证安全模式 |
| NFR-GW-TEST-002 | 精确前缀路由模式 |
| NFR-GW-TEST-003 | 分层权限控制模式 |

**覆盖率**: 18/18 (100%)
