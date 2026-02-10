# Unit 6: api-gateway — 业务规则

---

## 1. 认证规则

### BR-GW-001: JWT 令牌提取
- 从请求头 `Authorization: Bearer <token>` 提取令牌
- Authorization 头缺失 → 返回 GW_001 (401)
- 不以 "Bearer " 开头 → 返回 GW_001 (401)
- Bearer 后无内容 → 返回 GW_001 (401)

### BR-GW-002: JWT 签名校验
- 使用 HS256 算法 + JWT_SECRET 环境变量校验签名
- 签名不匹配 → 返回 GW_001 (401)
- JWT_SECRET 必须与 auth-service 使用的密钥一致

### BR-GW-003: JWT 过期校验
- 检查 JWT payload 中的 exp 字段
- exp < 当前时间戳 → 返回 GW_001 (401)
- exp 字段缺失 → 返回 GW_001 (401)

### BR-GW-004: JWT payload 完整性
- 必须包含 userId（Long 类型）
- 必须包含 username（String 类型）
- 必须包含 role（String 类型，值为 EMPLOYEE 或 ADMIN）
- 任一字段缺失或类型不匹配 → 返回 GW_001 (401)

### BR-GW-005: 统一认证失败响应
- 所有 JWT 校验失败场景统一返回 401 + GW_001
- 不区分具体失败原因（防止信息泄露）
- 错误消息统一为"未授权，请先登录"

---

## 2. 权限规则

### BR-GW-006: 公开端点白名单
- 以下端点无需认证，直接放行：
  - `POST /api/auth/register`
  - `POST /api/auth/login`
- 白名单匹配需同时匹配 HTTP 方法和路径
- 例：`GET /api/auth/register` 不在白名单中，需要认证

### BR-GW-007: 管理员端点权限
- 以下端点需要管理员角色：
  - `* /api/admin/*`（所有管理员端点）
  - `POST /api/files/upload`（文件上传）
- 非管理员访问 → 返回 GW_002 (403)

### BR-GW-008: 已认证端点
- 除公开端点和管理员端点外的所有 /api/* 端点
- 需要有效的 JWT 令牌
- 不限制角色（EMPLOYEE 和 ADMIN 均可访问）

### BR-GW-009: 权限校验优先级
- 校验顺序：PUBLIC → ADMIN_ONLY → AUTHENTICATED
- 优先匹配更具体的规则
- 未匹配任何规则的 /api/* 请求默认需要认证

---

## 3. 路由规则

### BR-GW-010: 精确前缀匹配
- 路由按优先级从高到低匹配
- /api/admin/* 路由优先于 /api/* 通用路由
- 匹配到第一个规则后停止

### BR-GW-011: 路径透传
- 转发时保留完整的请求路径（不去除前缀）
- 保留查询参数
- 保留请求体
- 例：`/api/orders?page=0` → `http://order-service:8004/api/orders?page=0`

### BR-GW-012: 服务地址配置
- 所有目标服务地址通过环境变量配置
- 使用 Docker DNS 服务名作为默认值
- 运行时可通过环境变量覆盖

---

## 4. 请求头规则

### BR-GW-013: 安全清除
- 转发前必须清除客户端请求中的以下请求头：
  - X-User-Id
  - X-User-Role
- 防止客户端伪造用户身份
- 无论请求是否需要认证，都执行清除

### BR-GW-014: 用户信息注入
- 仅对已认证的请求注入用户信息
- 注入 X-User-Id: JWT payload 中的 userId
- 注入 X-User-Role: JWT payload 中的 role
- 公开端点请求不注入用户信息

---

## 5. 错误处理规则

### BR-GW-015: 网关层错误
- 网关自身产生的错误使用 GW_ 前缀错误码
- 遵循统一错误响应格式 `{ code, message, data }`

### BR-GW-016: 下游错误透传
- 下游微服务返回的错误响应原样透传给客户端
- 不修改下游的 HTTP 状态码
- 不修改下游的响应体
- 网关不解析下游的业务错误

### BR-GW-017: 下游不可达处理
- 连接失败 → 返回 GW_003 (502)
- 响应超时 → 返回 GW_004 (504)

---

## 6. 错误码

| 错误码 | HTTP 状态码 | 消息 | 触发场景 |
|--------|------------|------|---------|
| GW_001 | 401 | 未授权，请先登录 | JWT 缺失、过期、签名无效、格式错误 |
| GW_002 | 403 | 权限不足 | 非管理员访问管理员端点 |
| GW_003 | 502 | 服务暂时不可用 | 下游微服务不可达 |
| GW_004 | 504 | 请求超时 | 下游微服务响应超时 |

### 统一错误响应格式
```json
{
  "code": "GW_001",
  "message": "未授权，请先登录",
  "data": null
}
```

---

## 7. 边界条件

### JWT 相关
- JWT_SECRET 为空或未配置 → 网关启动失败
- JWT payload 中 role 值不是 EMPLOYEE 或 ADMIN → 返回 GW_001
- JWT 令牌长度超过合理范围（如 > 4KB）→ 返回 GW_001

### 路由相关
- 请求路径不以 /api/ 开头 → 返回 404（网关不处理非 API 请求）
- 请求路径匹配 /api/ 但无具体路由 → 返回 404
- 目标服务环境变量未配置 → 使用默认值（Docker DNS 服务名）

### 并发相关
- 网关为无状态服务，不存在并发数据竞争
- 每个请求独立处理，互不影响

### 文件上传
- 文件上传请求（multipart/form-data）正常转发到 product-service
- 网关不解析或限制文件大小（由 Nginx 和 product-service 控制）
