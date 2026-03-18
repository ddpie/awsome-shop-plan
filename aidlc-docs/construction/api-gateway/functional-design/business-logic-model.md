# Unit 6: api-gateway — 业务逻辑模型

---

## 1. 请求处理主流程

```
客户端请求 → api-gateway:8080
  │
  ├── 1. 路由匹配
  │     └── 根据 URL 前缀匹配目标微服务
  │         └── 无匹配 → 返回 404
  │
  ├── 2. 权限级别判定
  │     └── 根据 URL + HTTP 方法确定访问级别
  │         ├── PUBLIC → 跳过认证，直接转发（步骤 5）
  │         ├── AUTHENTICATED → 执行令牌验证（步骤 3）
  │         └── ADMIN_ONLY → 执行令牌验证 + 角色校验（步骤 3-4）
  │
  ├── 3. 令牌认证校验（远程验证）
  │     ├── 从请求头 Authorization: Bearer <token> 提取令牌
  │     │     └── 缺失 → 返回 AUTHZ_001 (401)
  │     ├── 调用 auth-service 验证接口
  │     │     POST /api/v1/internal/auth/validate
  │     │     ├── 验证成功 → 获取 operatorId 和 role
  │     │     ├── 验证失败 → 返回 AUTHZ_001 (401)
  │     │     ├── auth-service 不可达 → 返回 BAD_GATEWAY_001 (502)
  │     │     └── 验证超时 → 返回 GATEWAY_TIMEOUT_001 (504)
  │     └── 提取用户信息: { operatorId, role }
  │
  ├── 4. 角色权限校验（仅 ADMIN_ONLY 端点）
  │     └── role ≠ ADMIN → 返回 FORBIDDEN_001 (403)
  │
  ├── 5. 请求头处理
  │     ├── 清除客户端可能携带的 X-Operator-Id、X-User-Role（防伪造）
  │     ├── 注入 X-Operator-Id: operatorId（仅已认证请求）
  │     └── 注入 X-User-Role: role（仅已认证请求）
  │
  ├── 6. 请求转发
  │     └── 将请求转发到目标微服务
  │         ├── 保留原始请求方法、路径、查询参数、请求体
  │         ├── 保留客户端 Content-Type 等必要请求头
  │         └── 超时 → 返回 GATEWAY_TIMEOUT_001 (504)
  │
  └── 7. 响应返回
        ├── 下游正常响应 → 透传给客户端
        └── 下游不可达 → 返回 BAD_GATEWAY_001 (502)
```

---

## 2. 令牌验证详细流程（远程校验）

```
提取 Authorization 请求头
  │
  ├── 缺失 → 返回 AUTHZ_001 (401)
  │
  ├── 不以 "Bearer " 开头 → 返回 AUTHZ_001 (401)
  │
  └── 提取 token 字符串
        │
        └── 调用 auth-service 验证接口
              POST /api/v1/internal/auth/validate
              请求体: { "token": "<token字符串>" }
              │
              ├── 调用成功 → 解析响应
              │     ├── success = true → 提取 operatorId 和 role
              │     └── success = false → 返回 AUTHZ_001 (401)
              │
              ├── 调用超时（>5秒）→ 返回 GATEWAY_TIMEOUT_001 (504)
              │
              └── auth-service 不可达 → 返回 BAD_GATEWAY_001 (502)
```

### 验证响应格式

**成功响应：**
```json
{
  "success": true,
  "operatorId": 1,
  "role": "EMPLOYEE",
  "message": "验证成功"
}
```

**失败响应：**
```json
{
  "success": false,
  "operatorId": null,
  "role": null,
  "message": "令牌已过期"
}
```

- 网关通过调用 auth-service 的内部接口验证令牌
- 不在网关层面解析 JWT，由 auth-service 负责所有令牌逻辑

---

## 3. 路由匹配流程

```
请求 URL: /api/v1/admin/products/1
  │
  ├── 遍历路由规则（按优先级从高到低）
  │     ├── /api/v1/auth/* → 不匹配
  │     ├── /api/admin/users/* → 不匹配
  │     ├── /api/admin/products/* → ✅ 匹配
  │     │     └── 目标: http://product-service:8002
  │     └── 停止匹配
  │
  └── 转发: http://product-service:8002/api/v1/admin/products/1
```

### 路由转发规则
- 保留完整的请求路径（不去除前缀）
- 下游微服务接收到的路径与客户端请求路径一致
- 例：`GET /api/v1/orders?page=0` → `GET http://order-service:8004/api/v1/orders?page=0`

---

## 4. 权限判定流程

```
请求: POST /api/v1/public/auth/login
  │
  ├── 匹配公开端点规则
  │     ├── POST /api/v1/public/auth/register → 不匹配
  │     └── POST /api/v1/public/auth/login → ✅ 匹配 PUBLIC
  │
  └── 结果: 跳过认证，直接转发
```

```
请求: GET /api/v1/admin/orders?page=0
  │
  ├── 匹配公开端点规则 → 不匹配
  ├── 匹配管理员端点规则
  │     └── * /api/v1/admin/* → ✅ 匹配 ADMIN_ONLY
  │
  └── 结果: 需要令牌验证 + 管理员角色校验
```

```
请求: POST /api/v1/files/upload
  │
  ├── 匹配公开端点规则 → 不匹配
  ├── 匹配管理员端点规则
  │     └── POST /api/v1/files/upload → ✅ 匹配 ADMIN_ONLY
  │
  └── 结果: 需要令牌验证 + 管理员角色校验
```

```
请求: GET /api/v1/products?page=0
  │
  ├── 匹配公开端点规则 → 不匹配
  ├── 匹配管理员端点规则 → 不匹配
  ├── 匹配已认证端点规则
  │     └── * /api/v1/* → ✅ 匹配 AUTHENTICATED
  │
  └── 结果: 需要令牌验证（无角色要求）
```

---

## 5. 请求头处理详细流程

```
已认证请求转发前:
  │
  ├── 1. 安全清除（防伪造）
  │     ├── 移除客户端请求中的 X-Operator-Id（如果存在）
  │     └── 移除客户端请求中的 X-User-Role（如果存在）
  │
  ├── 2. 注入用户信息
  │     ├── X-Operator-Id: <从验证响应中的 operatorId>
  │     └── X-User-Role: <从验证响应中的 role>
  │
  └── 3. 保留原始请求头
        ├── Content-Type
        ├── Accept
        └── 其他业务无关请求头
```

```
公开端点请求转发前:
  │
  ├── 1. 安全清除
  │     ├── 移除 X-Operator-Id（如果存在）
  │     └── 移除 X-User-Role（如果存在）
  │
  └── 2. 不注入用户信息（未认证）
```

---

## 6. 下游服务错误处理

```
转发请求到下游微服务
  │
  ├── 连接失败（服务不可达）
  │     └── 返回 BAD_GATEWAY_001 (502) { code: "BAD_GATEWAY_001", message: "服务暂时不可用" }
  │
  ├── 响应超时
  │     └── 返回 GATEWAY_TIMEOUT_001 (504) { code: "GATEWAY_TIMEOUT_001", message: "请求超时" }
  │
  └── 正常响应（包括下游的 4xx/5xx）
        └── 透传给客户端（不修改响应状态码和响应体）
```

说明：
- 网关不解析或修改下游微服务的业务错误响应
- 下游返回 400/404/500 等，网关原样透传给客户端
- 仅在网关自身层面产生的错误（连接失败、超时）使用网关错误码

---

## 7. 完整请求流转示例

### 示例 1: 员工创建兑换订单

```
浏览器 → POST /api/v1/orders { productId: 1 }
         Authorization: Bearer eyJhbGciOiJIUzI1NiJ9...
  │
  ├── 路由匹配: /api/v1/orders/* → order-service:8004
  ├── 权限判定: AUTHENTICATED
  ├── 令牌验证: 调用 auth-service，通过，获得 operatorId=1, role=EMPLOYEE
  ├── 请求头处理:
  │     ├── 清除 X-Operator-Id, X-User-Role
  │     ├── 注入 X-Operator-Id: 1
  │     └── 注入 X-User-Role: EMPLOYEE
  ├── 转发: POST http://order-service:8004/api/v1/orders
  │         X-Operator-Id: 1
  │         X-User-Role: EMPLOYEE
  │         Content-Type: application/json
  │         Body: { productId: 1 }
  └── 透传 order-service 响应给客户端
```

### 示例 2: 管理员更新兑换状态

```
浏览器 → PUT /api/v1/admin/orders/1/status { status: "READY" }
         Authorization: Bearer eyJhbGciOiJIUzI1NiJ9...
  │
  ├── 路由匹配: /api/v1/admin/orders/* → order-service:8004
  ├── 权限判定: ADMIN_ONLY
  ├── 令牌验证: 调用 auth-service，通过，获得 operatorId=2, role=ADMIN
  ├── 角色校验: role=ADMIN ✅
  ├── 请求头处理:
  │     ├── 注入 X-Operator-Id: 2
  │     └── 注入 X-User-Role: ADMIN
  ├── 转发: PUT http://order-service:8004/api/v1/admin/orders/1/status
  └── 透传响应
```

### 示例 3: 未登录用户访问受保护端点

```
浏览器 → GET /api/v1/products
         （无 Authorization 头）
  │
  ├── 路由匹配: /api/v1/products/* → product-service:8002
  ├── 权限判定: AUTHENTICATED
  ├── 令牌验证: Authorization 头缺失
  └── 返回 401 { code: "AUTHZ_001", message: "未授权，请先登录" }
```

### 示例 4: 普通员工访问管理员端点

```
浏览器 → GET /api/v1/admin/orders
         Authorization: Bearer eyJhbGciOiJIUzI1NiJ9...
  │
  ├── 路由匹配: /api/v1/admin/orders/* → order-service:8004
  ├── 权限判定: ADMIN_ONLY
  ├── 令牌验证: 调用 auth-service，通过，获得 operatorId=1, role=EMPLOYEE
  ├── 角色校验: role=EMPLOYEE ≠ ADMIN
  └── 返回 403 { code: "FORBIDDEN_001", message: "权限不足" }
```
