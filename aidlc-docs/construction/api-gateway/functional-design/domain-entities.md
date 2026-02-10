# Unit 6: api-gateway — 领域实体与配置定义

---

## 1. 领域模型

API 网关不拥有数据库，不持久化数据。其领域模型围绕请求处理过程中的临时数据结构。

### UserInfo（用户信息 — 从 JWT 解析）

| 字段 | 类型 | 说明 |
|------|------|------|
| userId | Long | 用户ID |
| username | String | 用户名 |
| role | String | 角色（EMPLOYEE / ADMIN） |

说明：从 JWT payload 中解析，用于权限校验和请求头注入。

### RouteDefinition（路由定义 — 配置）

| 字段 | 类型 | 说明 |
|------|------|------|
| pathPrefix | String | URL 前缀匹配模式 |
| targetService | String | 目标微服务基础 URL |
| stripPrefix | Boolean | 是否去除前缀后转发 |

### AccessRule（访问规则 — 配置）

| 字段 | 类型 | 说明 |
|------|------|------|
| pathPattern | String | URL 匹配模式 |
| method | String? | HTTP 方法（可选，null 表示所有方法） |
| accessLevel | AccessLevel | 访问级别 |

### AccessLevel（访问级别枚举）

| 值 | 说明 |
|----|------|
| PUBLIC | 公开端点，无需认证 |
| AUTHENTICATED | 需要认证（任何已登录用户） |
| ADMIN_ONLY | 需要管理员角色 |

---

## 2. 路由配置

### 路由规则表

| 优先级 | URL 前缀 | 目标服务 | 说明 |
|--------|---------|---------|------|
| 1 | /api/auth/* | http://auth-service:8001 | 认证相关 |
| 2 | /api/admin/users/* | http://auth-service:8001 | 管理员-用户管理 |
| 3 | /api/admin/products/* | http://product-service:8002 | 管理员-产品管理 |
| 4 | /api/admin/categories/* | http://product-service:8002 | 管理员-分类管理 |
| 5 | /api/admin/points/* | http://points-service:8003 | 管理员-积分管理 |
| 6 | /api/admin/orders/* | http://order-service:8004 | 管理员-兑换管理 |
| 7 | /api/users/* | http://auth-service:8001 | 用户信息 |
| 8 | /api/products/* | http://product-service:8002 | 产品查询 |
| 9 | /api/categories/* | http://product-service:8002 | 分类查询 |
| 10 | /api/files/* | http://product-service:8002 | 文件上传/访问 |
| 11 | /api/points/* | http://points-service:8003 | 积分查询 |
| 12 | /api/orders/* | http://order-service:8004 | 兑换操作 |

说明：
- 路由按优先级从高到低匹配，优先匹配更具体的前缀
- /api/admin/* 路由优先于 /api/* 通用路由
- 所有路由目标使用 Docker DNS 服务名

### 目标服务地址（环境变量）

| 环境变量 | 默认值 | 说明 |
|---------|--------|------|
| AUTH_SERVICE_URL | http://auth-service:8001 | 认证服务 |
| PRODUCT_SERVICE_URL | http://product-service:8002 | 产品服务 |
| POINTS_SERVICE_URL | http://points-service:8003 | 积分服务 |
| ORDER_SERVICE_URL | http://order-service:8004 | 兑换服务 |

---

## 3. 权限配置

### 公开端点（PUBLIC — 无需认证）

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | /api/auth/register | 用户注册 |
| POST | /api/auth/login | 用户登录 |

### 管理员端点（ADMIN_ONLY — 需要管理员角色）

| 方法 | 路径 | 说明 |
|------|------|------|
| * | /api/admin/* | 所有管理员端点 |
| POST | /api/files/upload | 文件上传（仅管理员） |

### 已认证端点（AUTHENTICATED — 需要登录）

| 方法 | 路径 | 说明 |
|------|------|------|
| * | /api/* | 除公开端点和管理员端点外的所有端点 |

说明：权限校验顺序为 PUBLIC → ADMIN_ONLY → AUTHENTICATED，优先匹配更具体的规则。

---

## 4. 请求头注入

网关校验 JWT 通过后，向下游微服务转发请求时注入以下请求头：

| 请求头 | 值来源 | 说明 |
|--------|--------|------|
| X-User-Id | JWT payload.userId | 当前用户ID |
| X-User-Role | JWT payload.role | 当前用户角色 |

说明：
- 仅注入最小必要信息，微服务按需查询其他用户信息
- 下游微服务信任网关注入的请求头（Docker 内部网络隔离）
- 网关应清除客户端请求中可能携带的 X-User-Id 和 X-User-Role 头，防止伪造

---

## 5. 错误响应格式

### 网关层错误码

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
