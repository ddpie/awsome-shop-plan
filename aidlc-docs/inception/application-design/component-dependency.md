# AWSomeShop 组件依赖关系

---

## 依赖关系矩阵

### 后端组件依赖

| 组件 | 依赖 | 依赖类型 |
|------|------|---------|
| BE-AUTH | DA-USER, DA-POINTS | 数据访问 |
| BE-USER | DA-USER | 数据访问 |
| BE-PRODUCT | DA-PRODUCT, DA-CATEGORY, BE-FILE | 数据访问 + 组件调用 |
| BE-CATEGORY | DA-CATEGORY, DA-PRODUCT | 数据访问（删除时检查关联） |
| BE-POINTS | DA-POINTS, DA-USER | 数据访问 |
| BE-ORDER | BE-PRODUCT, BE-POINTS, DA-ORDER | 组件调用 + 数据访问 |
| BE-FILE | 本地文件系统 | 外部资源 |
| BE-SCHEDULER | DA-CONFIG, DA-USER, DA-POINTS | 数据访问 |

### API 网关依赖

| 组件 | 依赖 | 依赖类型 |
|------|------|---------|
| API-GATEWAY | JWT 签名密钥（与 auth-service 共享） | 配置共享 |
| API-GATEWAY | auth-service, product-service, points-service, order-service | 请求转发目标 |

### 前端组件依赖

| 组件 | 依赖 | 依赖类型 |
|------|------|---------|
| FE-AUTH | FE-COMMON(HTTP客户端) | 公共服务 |
| FE-PRODUCT | FE-COMMON, FE-AUTH(认证状态) | 公共服务 + 认证 |
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
                 |CATEG| +-+--------+
                 |BE-  |   |
                 |FILE |   |
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
  | 1. POST /api/orders {productId} + JWT令牌
  v
API GATEWAY
  | 1a. 校验 JWT 令牌有效性
  | 1b. 提取用户信息（userId, role）
  | 1c. 转发请求到 order-service（附带用户信息）
  v
BE-ORDER (兑换组件)
  |
  | 2. 查询产品信息和库存
  +-------> BE-PRODUCT --> DA-PRODUCT --> MySQL(products)
  |
  | 3. 查询用户积分余额
  +-------> BE-POINTS --> DA-POINTS --> MySQL(point_balances)
  |
  | 4. 事务开始
  | 4a. 扣除积分
  +-------> DA-POINTS --> MySQL(point_balances, point_transactions)
  | 4b. 减少库存
  +-------> DA-PRODUCT --> MySQL(products)
  | 4c. 创建兑换记录
  +-------> DA-ORDER --> MySQL(orders)
  | 4d. 事务提交
  |
  | 5. 返回兑换结果
  v
API GATEWAY → 员工浏览器
```

### 管理员操作数据流（经 API 网关权限校验）

```
管理员浏览器
  |
  | 1. POST /api/admin/* + JWT令牌
  v
API GATEWAY
  | 1a. 校验 JWT 令牌有效性
  | 1b. 提取用户角色
  | 1c. 校验角色 == ADMIN
  | 1d. 转发请求到对应微服务
  v
对应微服务（product-service / points-service / order-service / auth-service）
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
- BE-ORDER → BE-PRODUCT, BE-POINTS （兑换依赖产品和积分）
- BE-PRODUCT → BE-FILE （产品依赖文件）
- BE-SCHEDULER → DA-* （调度器依赖数据访问）
- BE-AUTH → DA-USER, DA-POINTS （认证依赖用户和积分数据）
- BE-CATEGORY ↔ DA-PRODUCT （分类删除时检查产品关联，通过数据层查询，非组件循环依赖）
- API-GATEWAY → auth-service（JWT 密钥共享，配置级依赖，非运行时循环）

**结论**: 无组件级循环依赖 ✅
