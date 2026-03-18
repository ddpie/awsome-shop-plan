# AWSomeShop 组件依赖关系

---

## 关键设计更新

1. **BE-CATEGORY 组件已移除**：分类不再是独立组件，现在作为产品的字符串字段
2. **DA-CATEGORY 已移除**：不再有独立的分类数据访问层
3. **API网关角色**：
   - 验证JWT令牌（调用 auth-service 的 `/api/v1/internal/auth/validate`）
   - 注入请求头：`X-Operator-Id` (用户ID) 和 `X-User-Role` (用户角色)
   - 转发请求到对应微服务

---

## 依赖关系矩阵

### 后端组件依赖

| 组件 | 依赖 | 依赖类型 |
|------|------|---------|
| BE-AUTH | DA-USER, DA-POINTS | 数据访问 |
| BE-USER | DA-USER | 数据访问 |
| BE-PRODUCT | DA-PRODUCT, BE-FILE | 数据访问 + 组件调用（分类作为字符串字段，无需独立管理） |
| BE-POINTS | DA-POINTS, DA-USER | 数据访问 |
| BE-ORDER | BE-PRODUCT, BE-POINTS, DA-ORDER | 组件调用 + 数据访问 |
| BE-FILE | 本地文件系统 | 外部资源 |
| BE-SCHEDULER | DA-CONFIG, DA-USER, DA-POINTS | 数据访问 |

### API 网关依赖

| 组件 | 依赖 | 依赖类型 |
|------|------|---------|
| API-GATEWAY | auth-service（令牌验证接口 /api/v1/internal/auth/validate） | 远程服务调用 |
| API-GATEWAY | auth-service, product-service, points-service, order-service | 请求转发目标 |

### 前端组件依赖

| 组件 | 依赖 | 依赖类型 |
|------|------|---------|
| FE-AUTH | FE-COMMON(HTTP客户端) | 公共服务 |
| FE-PRODUCT | FE-COMMON, FE-AUTH(认证状态) | 公共服务 + 认证（分类从产品数据中提取） |
| FE-POINTS | FE-COMMON, FE-AUTH | 公共服务 + 认证 |
| FE-ORDER | FE-COMMON, FE-AUTH, FE-POINTS(余额显示) | 公共服务 + 认证 + 数据 |
| FE-ADMIN | FE-COMMON, FE-AUTH(角色校验) | 公共服务 + 认证 |

---

## 组件依赖图

```
+----------+     +----------+     +-----------+
| FE-AUTH  |     | FE-PROD  |     | FE-POINTS |
+----+-----+     +----+-----+     +-----+-----+
     |                |                  |
     +-------+--------+--------+---------+
             |                 |
        +----v-----+     +----v----+
        | FE-ORDER |     | FE-ADMIN|
        +----+-----+     +----+----+
             |                 |
     ========|=================|======== HTTP 请求
             |                 |
        +----v-----------------v----+
        |      API GATEWAY          |
        |  (JWT校验/权限/路由)       |
        +----+-----+-----+----+----+
             |     |     |    |
     ========|=====|=====|====|======== 内部网络
             |     |     |    |
     +-------v-+ +-v---+ +v--v------+
     | BE-AUTH | |BE-  | | BE-      |
     | BE-USER | |PROD | | POINTS   |
     +---------+ |BE-  | | BE-SCHED |
                 |FILE | +-+--------+
                 +--+--+   |
                    |      |
               +----v------v----+
               |   BE-ORDER     |
               +-------+--------+
                       |
                +------v-------+
                |    MySQL     |
                +--------------+
```

---

## 数据流

### 员工兑换产品数据流（经 API 网关）

```
员工浏览器
  |
  | 1. POST /api/v1/order/** {productId} + JWT令牌
  v
API GATEWAY
  | 1a. 调用 auth-service 验证令牌：POST /api/v1/internal/auth/validate
  | 1b. auth-service 返回用户信息（userId, role）
  | 1c. 网关注入请求头 X-Operator-Id: <userId>
  | 1d. 转发请求到 order-service
  v
BE-ORDER (兑换组件)
  |
  | 2. 从 X-Operator-Id 请求头获取用户ID
  | 3. 查询产品信息和库存（跨服务调用 product-service）
  +-------> BE-PRODUCT --> DA-PRODUCT --> MySQL(product)
  |
  | 4. 查询用户积分余额（跨服务调用 points-service）
  +-------> BE-POINTS --> DA-POINTS --> MySQL(point_balances)
  |
  | 5. 事务开始
  | 5a. 扣除积分（跨服务调用 points-service）
  +-------> DA-POINTS --> MySQL(point_balances, point_transactions)
  | 5b. 减少库存（跨服务调用 product-service）
  +-------> DA-PRODUCT --> MySQL(product)
  | 5c. 创建兑换记录
  +-------> DA-ORDER --> MySQL(orders)
  | 5d. 事务提交
  |
  | 6. 返回兑换结果
  v
API GATEWAY → 员工浏览器
```

### 管理员操作数据流（服务内部权限校验）

```
管理员浏览器
  |
  | 1. POST /api/v1/{service}/** + JWT令牌
  v
API GATEWAY
  | 1a. 调用 auth-service 验证令牌：POST /api/v1/internal/auth/validate
  | 1b. auth-service 返回用户信息（userId, role）
  | 1c. 网关注入请求头 X-Operator-Id: <userId>
  | 1d. 转发请求到对应微服务
  v
对应微服务（product-service / points-service / order-service / auth-service）
  | 从 X-Operator-Id 获取操作人ID
  | 查询用户角色，内部校验是否为管理员
  | 根据角色决定是否允许操作
```

### 积分自动发放数据流

```
Cron 定时触发
  |
  v
BE-SCHEDULER (调度组件)
  |
  | 1. 读取发放配置
  +-------> DA-CONFIG --> MySQL(system_configs)
  |
  | 2. 查询所有活跃员工
  +-------> DA-USER --> MySQL(users)
  |
  | 3. 批量发放（循环每位员工）
  +-------> DA-POINTS --> MySQL(point_balances, point_transactions)
  |
  v
完成，记录日志
```

---

## 通信模式

| 通信类型 | 描述 | 使用场景 |
|---------|------|---------|
| 前端 → API 网关 | HTTP/JSON | 所有前端请求统一入口 |
| API 网关 → 微服务 | HTTP/JSON（内部网络） | 请求转发 |
| 微服务 → 微服务 | HTTP/JSON（内部网络） | 跨服务调用（如 order → product/points） |
| 组件 → 数据库 | 数据访问层 | 所有数据持久化 |
| 调度器 → 组件 | 定时触发 | 积分自动发放 |

---

## 无循环依赖验证

依赖方向：
- FE-* → API-GATEWAY → BE-* （前端通过网关调用后端，单向）
- API-GATEWAY → auth-service（令牌验证，远程服务调用，单向）
- BE-ORDER → BE-PRODUCT, BE-POINTS （兑换依赖产品和积分，跨服务调用）
- BE-PRODUCT → BE-FILE （产品依赖文件）
- BE-SCHEDULER → DA-* （调度器依赖数据访问）
- BE-AUTH → BE-POINTS（注册时初始化积分，跨服务调用 /api/v1/internal/points/init）
- BE-AUTH → DA-USER（认证依赖用户数据）

**注意**：BE-CATEGORY 组件已移除，分类现在作为产品的字符串字段，不需要独立管理。

**结论**: 无组件级循环依赖 ✅
