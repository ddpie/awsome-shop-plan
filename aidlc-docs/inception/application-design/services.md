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
客户端 → BE-AUTH
  1. 校验注册信息（用户名唯一性、密码强度）
  2. 密码加密
  3. 创建用户记录（DA-USER）
  4. 初始化积分余额为 0（DA-POINTS）
  5. 返回注册结果
```

**参与组件**: BE-AUTH → DA-USER, DA-POINTS

### 流程 2：用户登录

```
客户端 → BE-AUTH
  1. 查询用户（DA-USER）
  2. 校验密码
  3. 检查账号锁定状态
  4. 生成 JWT 令牌（含用户ID、角色）
  5. 返回令牌
```

**参与组件**: BE-AUTH → DA-USER

### 流程 3：产品兑换（核心流程）

```
客户端 → BE-ORDER
  1. 校验用户身份
  2. 查询产品信息和库存（BE-PRODUCT）
  3. 查询用户积分余额（BE-POINTS）
  4. 校验：积分充足 AND 库存充足
  5. 开启事务：
     a. 扣除积分（BE-POINTS → DA-POINTS）
     b. 减少库存（BE-PRODUCT → DA-PRODUCT）
     c. 创建兑换记录（DA-ORDER）
  6. 事务提交
  7. 返回兑换结果
  
  异常处理：
  - 积分不足 → 返回错误，不执行任何操作
  - 库存不足 → 返回错误，不执行任何操作
  - 并发冲突 → 事务回滚，提示用户重试
```

**参与组件**: BE-ORDER → BE-PRODUCT, BE-POINTS, DA-ORDER
**事务边界**: 积分扣除 + 库存减少 + 订单创建 在同一事务中

### 流程 4：积分自动发放

```
BE-SCHEDULER（定时触发）
  1. 读取发放配置（DA-CONFIG）
  2. 查询所有活跃员工（DA-USER）
  3. 批量发放积分：
     对每位员工：
     a. 增加积分余额（DA-POINTS）
     b. 创建积分变动记录（DA-POINTS）
  4. 记录发放结果日志
```

**参与组件**: BE-SCHEDULER → DA-CONFIG, DA-USER, DA-POINTS
**触发方式**: Cron 定时任务

### 流程 5：积分手动调整

```
管理员 → BE-POINTS
  1. 校验管理员权限
  2. 查询目标员工当前余额（DA-POINTS）
  3. 校验：扣除时余额是否充足
  4. 更新积分余额（DA-POINTS）
  5. 创建积分变动记录（含操作人、备注）（DA-POINTS）
  6. 返回调整结果
```

**参与组件**: BE-POINTS → DA-POINTS

### 流程 6：产品管理

```
管理员 → BE-PRODUCT
  创建：校验信息 → 保存产品（DA-PRODUCT）→ 关联分类
  编辑：校验信息 → 更新产品（DA-PRODUCT）
  删除：检查关联 → 删除产品（DA-PRODUCT）→ 删除图片（BE-FILE）
```

**参与组件**: BE-PRODUCT → DA-PRODUCT, BE-FILE

### 流程 7：分类管理

```
管理员 → BE-CATEGORY
  创建：校验名称 → 设置父分类 → 保存（DA-CATEGORY）
  编辑：校验名称 → 更新（DA-CATEGORY）
  删除：检查子分类 → 检查关联产品 → 删除（DA-CATEGORY）
```

**参与组件**: BE-CATEGORY → DA-CATEGORY, DA-PRODUCT

---

## 横切关注点

### 认证与授权（API 网关统一处理）
- 所有前端请求通过 API 网关统一入口
- API 网关负责 JWT 令牌校验，业务微服务无需各自实现认证逻辑
- API 网关负责管理员角色权限校验（/api/admin/* 端点）
- 公开端点（注册、登录）在网关层配置白名单放行
- 令牌过期由网关统一拒绝请求
- 网关校验通过后，将用户信息（userId、role）附加到请求头转发给后端微服务

### 请求路由（API 网关）
- API 网关根据 URL 前缀将请求路由到对应微服务
- /api/auth/*, /api/users/* → auth-service
- /api/products/*, /api/categories/*, /api/files/* → product-service
- /api/points/* → points-service
- /api/orders/* → order-service
- /api/admin/* 按业务模块路由到对应服务

### 错误处理
- 统一错误响应格式：`{ code, message, data }`
- 业务异常返回 4xx 状态码
- 系统异常返回 5xx 状态码
- API 网关认证失败返回 401，权限不足返回 403

### 分页
- 统一分页参数：`page`（页码）、`size`（每页数量）
- 统一分页响应：`{ content, totalElements, totalPages, currentPage }`
