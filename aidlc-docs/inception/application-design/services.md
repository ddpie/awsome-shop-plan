# AWSomeShop 服务层定义

> 后端架构分层将在实现阶段根据用户提供的框架确定。
> 此处定义服务编排模式和跨组件业务流程。

---

## 服务编排模式

采用服务层编排模式，每个业务流程由对应的服务协调多个组件完成。

---

## 核心业务流程

### 流程 1：用户注册

```
客户端 → API 网关 → BE-AUTH (POST /api/v1/public/auth/register)
  1. 校验注册信息（用户名唯一性、密码强度）
  2. 密码加密
  3. 创建用户记录（DA-USER）
  4. 调用积分服务内部接口初始化积分余额为 0（POST /api/v1/internal/points/init）
  5. 返回注册结果
```

**参与组件**: BE-AUTH → DA-USER, BE-POINTS（跨服务调用）

### 流程 2：用户登录

```
客户端 → API 网关 → BE-AUTH (POST /api/v1/public/auth/login)
  1. 查询用户（DA-USER）
  2. 校验密码
  3. 检查账号锁定状态
  4. 生成 JWT 令牌（含用户ID、角色）
  5. 返回令牌
```

**参与组件**: BE-AUTH → DA-USER

### 流程 3：产品兑换（核心流程）

```
客户端 → API 网关 → BE-ORDER (POST /api/v1/order/**)
  1. 从请求头 X-Operator-Id 获取用户身份
  2. 查询产品信息和库存（跨服务调用 BE-PRODUCT）
  3. 查询用户积分余额（跨服务调用 BE-POINTS）
  4. 校验：积分充足 AND 库存充足
  5. Saga 编排执行：
     a. 扣除积分（跨服务调用 BE-POINTS → DA-POINTS）
     b. 减少库存（跨服务调用 BE-PRODUCT → DA-PRODUCT）
        - 失败时逆序补偿：回滚积分
     c. 创建兑换记录（DA-ORDER）
        - 失败时逆序补偿：回滚库存 + 回滚积分
  6. 返回兑换结果

  异常处理：
  - 积分不足 → 返回错误，不执行任何操作
  - 库存不足 → 返回错误，不执行任何操作
  - 并发冲突 → Saga 补偿回滚
  - 补偿失败 → 记录日志 + 人工介入（最大努力补偿模式）
```

**参与组件**: BE-ORDER → BE-PRODUCT, BE-POINTS, DA-ORDER
**分布式事务策略**: Saga 最大努力补偿模式：顺序执行积分扣除→库存扣减→订单创建，失败时逆序补偿回滚

### 流程 4：积分自动发放

```
BE-SCHEDULER（定时触发）
  1. 读取发放配置（DA-CONFIG）
  2. 查询 point_balances 表中所有记录（DA-POINTS）
  3. 批量发放积分：
     对每位员工：
     a. 增加积分余额（DA-POINTS）
     b. 创建积分变动记录（DA-POINTS）
  4. 记录发放结果日志
```

**参与组件**: BE-SCHEDULER → DA-CONFIG, DA-POINTS
**触发方式**: Cron 定时任务

### 流程 5：积分手动调整

```
管理员 → API 网关 → BE-POINTS (POST /api/v1/points/adjust)
  1. 从请求头 X-Operator-Id 获取管理员身份，服务内部校验管理员权限
  2. 查询目标员工当前余额（DA-POINTS）
  3. 校验：扣除时余额是否充足
  4. 更新积分余额（DA-POINTS）
  5. 创建积分变动记录（含操作人、备注）（DA-POINTS）
  6. 返回调整结果
```

**参与组件**: BE-POINTS → DA-POINTS

### 流程 6：产品管理

```
管理员 → API 网关 → BE-PRODUCT (POST/PUT/DELETE /api/v1/product/**)
  创建：校验信息 → 保存产品（DA-PRODUCT）→ 关联分类
  编辑：校验信息 → 更新产品（DA-PRODUCT）
  删除：检查关联 → 删除产品（DA-PRODUCT）→ 删除图片（BE-FILE）
  服务内部校验管理员权限（从 X-Operator-Id 请求头获取操作人信息）
```

**参与组件**: BE-PRODUCT → DA-PRODUCT, BE-FILE

### 流程 7：分类管理

```
管理员 → API 网关 → BE-CATEGORY (POST/PUT/DELETE /api/v1/product/categories/**)
  创建：校验名称 → 设置父分类 → 保存（DA-CATEGORY）
  编辑：校验名称 → 更新（DA-CATEGORY）
  删除：检查子分类 → 检查关联产品 → 删除（DA-CATEGORY）
  服务内部校验管理员权限（从 X-Operator-Id 请求头获取操作人信息）
```

**参与组件**: BE-CATEGORY → DA-CATEGORY, DA-PRODUCT

---

## 横切关注点

### 认证与授权（API 网关统一处理）
- **所有前端请求通过 API 网关统一入口**
- **公开端点放行**: `/api/v1/public/**` 路径（如 `/api/v1/public/auth/login`、`/api/v1/public/auth/register`）在网关层直接放行，无需认证
- **受保护端点认证**: 其他端点需要 JWT 令牌
  - API 网关从请求头 `Authorization: Bearer <token>` 提取 JWT 令牌
  - **网关不做本地 JWT 校验**，而是调用认证服务的内部接口 `POST /api/v1/internal/auth/validate` 进行远程校验
  - 认证服务返回用户信息（userId、role）或校验失败错误
- **用户信息传递**: 网关校验通过后，将 `X-Operator-Id: <userId>` 请求头注入到转发给下游微服务的请求中
- **角色授权**: API 网关不做角色检查，各业务微服务根据 `X-Operator-Id` 和自身业务逻辑内部处理管理员权限校验
- **令牌过期**: 由认证服务在 `/api/v1/internal/auth/validate` 接口中检查令牌有效性，网关根据返回结果决定是否放行

### 请求路由（API 网关）
- API 网关根据 URL 前缀将请求路由到对应微服务
- `/api/v1/public/auth/**` → auth-service（公开端点，无需认证）
- `/api/v1/auth/**` → auth-service（受保护端点）
- `/api/v1/product/**` → product-service（产品、分类、文件上传）
- `/api/v1/point/**` → points-service
- `/api/v1/order/**` → order-service
- `/api/v1/internal/**` → 内部服务间调用（网关可配置拒绝外部访问）

### 错误处理
- 统一错误响应格式：`{ code, message, data }`
- 业务异常返回 4xx 状态码
- 系统异常返回 5xx 状态码
- API 网关认证失败返回 401
- 业务服务权限不足返回 403

### 分页
- 统一分页参数：`page`（页码）、`size`（每页数量）
- 统一分页响应：`{ content, totalElements, totalPages, currentPage }`
