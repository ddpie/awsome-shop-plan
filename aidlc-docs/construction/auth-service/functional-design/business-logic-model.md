# Unit 2: auth-service — 业务逻辑模型

---

## 1. 用户注册流程

```
客户端 → POST /api/auth/register (RegisterRequest)
  │
  ├── 1. 参数校验
  │     ├── username: 非空，3-20位，^[a-zA-Z0-9_]{3,20}$
  │     ├── password: 非空，最少6位
  │     ├── name: 非空，1-100位
  │     └── employeeId: 非空，1-50位
  │
  ├── 2. 唯一性校验
  │     ├── 查询 username 是否已存在 → 存在则返回 AUTH_001
  │     └── 查询 employeeId 是否已存在 → 存在则返回 AUTH_002
  │
  ├── 3. 创建用户
  │     ├── 密码 bcrypt 加密（cost factor = 10）
  │     ├── role = EMPLOYEE（注册用户默认为员工）
  │     ├── status = ACTIVE
  │     └── 保存到 auth_db.users
  │
  ├── 4. 初始化积分余额
  │     └── 同步调用 points-service: POST /api/internal/points/init
  │         ├── 请求体: { userId: <新用户ID> }
  │         ├── 成功 → 继续
  │         └── 失败 → 记录日志，不影响注册结果（降级处理）
  │
  └── 5. 返回 UserResponse
```

### 跨服务调用说明
- auth-service 注册成功后，通过 HTTP 调用 points-service 的内部接口初始化积分
- 内部接口路径：`POST http://points-service:8080/api/internal/points/init`
- 该接口不经过 API 网关，是服务间直接调用
- 如果 points-service 调用失败，注册仍然成功（积分可在首次查询时补偿初始化）

---

## 2. 用户登录流程

```
客户端 → POST /api/auth/login (LoginRequest)
  │
  ├── 1. 参数校验
  │     ├── username: 非空
  │     └── password: 非空
  │
  ├── 2. 查询用户
  │     └── 按 username 查询 → 不存在则返回 AUTH_003
  │
  ├── 3. 账号状态检查
  │     └── status == DISABLED → 返回 AUTH_006
  │
  ├── 4. 密码校验
  │     └── bcrypt 比对 → 不匹配则返回 AUTH_003
  │         （统一返回"用户名或密码错误"，不区分用户不存在和密码错误）
  │
  ├── 5. 生成 JWT 令牌
  │     ├── payload: { userId, username, role }
  │     ├── 签名算法: HS256
  │     ├── 密钥: JWT_SECRET（环境变量）
  │     └── 过期时间: JWT_EXPIRATION（环境变量，默认 86400 秒）
  │
  └── 6. 返回 TokenResponse
        ├── token: JWT 字符串
        ├── userId, username, role
        └── expiresIn: 过期秒数
```

---

## 3. 用户退出流程

```
客户端 → POST /api/auth/logout
  │
  └── 返回成功（HTTP 200）
      说明：采用前端清除令牌策略，后端不做额外处理。
      JWT 令牌在过期前仍然有效，但前端已清除，用户无法继续使用。
```

---

## 4. 获取当前用户信息

```
客户端 → GET /api/users/me
  │
  ├── 1. 从请求头获取用户信息
  │     └── API 网关校验 JWT 后，将 userId 附加到请求头 X-User-Id
  │
  ├── 2. 查询用户
  │     └── 按 userId 查询 → 不存在则返回 AUTH_004
  │
  └── 3. 返回 UserResponse
```

---

## 5. 管理员 — 用户列表查询

```
管理员 → GET /api/admin/users?page=0&size=20&keyword=xxx
  │
  ├── 1. 分页参数处理
  │     ├── page: 默认 0，最小 0
  │     └── size: 默认 20，最小 1，最大 100
  │
  ├── 2. 关键词搜索（可选）
  │     └── keyword 模糊匹配 username、name、employeeId
  │
  └── 3. 返回 PageResponse<UserResponse>
```

---

## 6. 管理员 — 更新用户信息/状态

```
管理员 → PUT /api/admin/users/{id} (UpdateUserRequest)
  │
  ├── 1. 查询目标用户
  │     └── 按 id 查询 → 不存在则返回 AUTH_004
  │
  ├── 2. 权限校验
  │     └── 不允许禁用自己的账号 → 返回 AUTH_007
  │
  ├── 3. 更新字段
  │     ├── name（如果提供）
  │     └── status（如果提供）：ACTIVE ↔ DISABLED
  │
  └── 4. 返回更新后的 UserResponse
```

---

## 7. JWT 令牌结构

### Header
```json
{
  "alg": "HS256",
  "typ": "JWT"
}
```

### Payload
```json
{
  "userId": 1,
  "username": "zhangsan",
  "role": "EMPLOYEE",
  "iat": 1738972800,
  "exp": 1739059200
}
```

### 签名
- 算法：HMAC-SHA256
- 密钥：JWT_SECRET 环境变量
- auth-service 负责生成令牌，API 网关负责校验令牌
- 两者共享同一个 JWT_SECRET
