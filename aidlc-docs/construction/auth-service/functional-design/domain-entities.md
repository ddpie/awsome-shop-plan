# Unit 2: auth-service — 领域实体与数据模型

---

## 1. 核心领域实体

### User（用户）

| 属性 | 类型 | 说明 |
|------|------|------|
| id | Long | 用户唯一标识（自增主键） |
| username | String | 用户名（唯一，3-20位，字母数字下划线） |
| password | String | 密码（bcrypt 加密存储） |
| name | String | 姓名 |
| employeeId | String | 工号（唯一） |
| role | Role | 角色枚举 |
| status | UserStatus | 账号状态枚举 |
| createdAt | DateTime | 创建时间 |
| updatedAt | DateTime | 更新时间 |

### 枚举定义

```
Role:
  - EMPLOYEE    # 普通员工
  - ADMIN       # 管理员

UserStatus:
  - ACTIVE      # 正常
  - DISABLED    # 已禁用
```

---

## 2. 请求模型（Request DTO）

### RegisterRequest — 注册请求

| 字段 | 类型 | 必填 | 校验规则 |
|------|------|------|---------|
| username | String | 是 | 3-20位，仅字母、数字、下划线，正则：`^[a-zA-Z0-9_]{3,20}$` |
| password | String | 是 | 最少6位 |
| name | String | 是 | 1-100位，非空 |
| employeeId | String | 是 | 1-50位，非空，唯一 |

### LoginRequest — 登录请求

| 字段 | 类型 | 必填 | 校验规则 |
|------|------|------|---------|
| username | String | 是 | 非空 |
| password | String | 是 | 非空 |

### UpdateUserRequest — 更新用户请求（管理员）

| 字段 | 类型 | 必填 | 校验规则 |
|------|------|------|---------|
| name | String | 否 | 1-100位 |
| status | UserStatus | 否 | ACTIVE 或 DISABLED |

---

## 3. 响应模型（Response DTO）

### UserResponse — 用户信息响应

| 字段 | 类型 | 说明 |
|------|------|------|
| id | Long | 用户ID |
| username | String | 用户名 |
| name | String | 姓名 |
| employeeId | String | 工号 |
| role | String | 角色 |
| status | String | 账号状态 |
| createdAt | String | 创建时间（ISO 8601） |

### TokenResponse — 登录令牌响应

| 字段 | 类型 | 说明 |
|------|------|------|
| token | String | JWT 令牌 |
| userId | Long | 用户ID |
| username | String | 用户名 |
| role | String | 角色 |
| expiresIn | Long | 过期时间（秒） |

### PageResponse\<T\> — 分页响应

| 字段 | 类型 | 说明 |
|------|------|------|
| content | List\<T\> | 数据列表 |
| totalElements | Long | 总记录数 |
| totalPages | Int | 总页数 |
| currentPage | Int | 当前页码 |

---

## 4. API 端点定义

### 公开端点

| 方法 | 路径 | 请求体 | 响应体 | 说明 |
|------|------|--------|--------|------|
| POST | /api/auth/register | RegisterRequest | UserResponse | 用户注册 |
| POST | /api/auth/login | LoginRequest | TokenResponse | 用户登录 |

### 认证端点

| 方法 | 路径 | 请求体 | 响应体 | 说明 |
|------|------|--------|--------|------|
| POST | /api/auth/logout | — | void | 退出登录 |
| GET | /api/users/me | — | UserResponse | 获取当前用户信息 |

### 管理员端点

| 方法 | 路径 | 请求体 | 响应体 | 说明 |
|------|------|--------|--------|------|
| GET | /api/admin/users | — | PageResponse\<UserResponse\> | 用户列表（分页、搜索） |
| GET | /api/admin/users/{id} | — | UserResponse | 获取用户详情 |
| PUT | /api/admin/users/{id} | UpdateUserRequest | UserResponse | 更新用户信息/状态 |

查询参数（用户列表）：
- `page`: 页码（默认 0）
- `size`: 每页数量（默认 20）
- `keyword`: 搜索关键词（匹配用户名、姓名、工号）
