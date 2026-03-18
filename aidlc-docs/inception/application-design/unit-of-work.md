# AWSomeShop 工作单元定义

## 分解策略

- **后端**: 微服务架构 — 每个业务模块独立部署为单独的服务
- **前端**: 单页应用（SPA）— 一个前端项目包含所有页面
- **API 网关**: 独立服务 — 统一处理认证、权限校验、请求路由
- **开发模式**: 前端和后端独立开发，后端按业务模块分微服务

---

## 工作单元列表

### Unit 1: 前端应用 (awsome-shop-frontend)
- **类型**: SPA 前端应用
- **职责**: 所有用户界面，包含员工端和管理端
- **包含组件**: FE-AUTH, FE-PRODUCT, FE-POINTS, FE-ORDER, FE-ADMIN, FE-COMMON
- **部署**: Docker 容器（Nginx 静态文件服务）
- **API 调用**: 所有请求通过 API 网关统一入口，使用 `/api/v1/` 前缀
- **代码结构**:
```
awsome-shop-frontend/
  src/
    components/     # 公共UI组件
    pages/          # 页面组件
      auth/         # 登录、注册
      products/     # 产品列表、详情
      points/       # 积分余额、历史
      orders/       # 兑换、历史
      admin/        # 管理后台页面
    services/       # API 调用封装
    store/          # 状态管理
    router/         # 路由配置
    utils/          # 工具函数
```

### Unit 2: 认证服务 (awsome-shop-auth-service)
- **类型**: 微服务
- **职责**: 用户注册、登录、JWT 令牌生成、密码加密、用户信息管理、令牌验证服务（供 API 网关调用）
- **包含组件**: BE-AUTH, BE-USER, DA-USER
- **数据表**: users
- **API 前缀**: `/api/v1/public/auth/*`（公开），`/api/v1/auth/*`（受保护），`/api/v1/internal/auth/*`（内部）
- **部署**: Docker 容器
- **说明**: 提供 `/api/v1/internal/auth/validate` 接口供 API 网关远程校验令牌；注册时调用积分服务内部接口初始化积分
- **代码结构**（DDD 六边形架构 + Maven 多模块）:
```
awsome-shop-auth-service/
  bootstrap/                # 启动模块
  common/                   # 通用模块
  domain/
    domain-api/             # 领域服务接口
    domain-impl/            # 领域服务实现
    domain-model/           # 领域模型
    repository-api/         # 仓储接口
    security-api/           # 安全接口
  application/
    application-api/        # 应用服务接口
    application-impl/       # 应用服务实现
  interface/
    interface-http/         # HTTP 接口（REST 控制器）
  infrastructure/
    repository/
      mysql-impl/           # MySQL 仓储实现
    cache/
      redis-impl/           # Redis 缓存实现
    security/
      jwt-impl/             # JWT 安全实现
```

### Unit 3: 产品服务 (awsome-shop-product-service)
- **类型**: 微服务
- **职责**: 产品 CRUD、产品搜索、库存管理、文件上传
- **包含组件**: BE-PRODUCT, BE-FILE, DA-PRODUCT
- **数据表**: product
- **API 前缀**: `/api/v1/product/**`（产品、文件上传统一前缀）
- **部署**: Docker 容器 + 本地文件卷挂载（图片存储）
- **说明**: 服务内部根据 `X-Operator-Id` 请求头校验管理员权限；category 为产品的字符串字段，无独立分类表
- **代码结构**（DDD 六边形架构 + Maven 多模块）:
```
awsome-shop-product-service/
  bootstrap/
  common/
  domain/
    domain-api/
    domain-impl/
    domain-model/
    repository-api/
  application/
    application-api/
    application-impl/
  interface/
    interface-http/
  infrastructure/
    repository/
      mysql-impl/
    cache/
      redis-impl/
  uploads/                  # 图片存储目录（Docker 卷挂载）
```

### Unit 4: 积分服务 (awsome-shop-points-service)
- **类型**: 微服务
- **职责**: 积分余额管理、积分变动记录、积分自动发放（定时任务）、发放配置、新用户积分初始化
- **包含组件**: BE-POINTS, BE-SCHEDULER, DA-POINTS, DA-CONFIG
- **数据表**: point_balances, point_transactions, system_configs
- **API 前缀**: `/api/v1/points/**`（受保护），`/api/v1/internal/points/**`（内部）
- **部署**: Docker 容器
- **说明**: 提供 `/api/v1/internal/points/init` 接口供认证服务在用户注册时初始化积分；服务内部根据 `X-Operator-Id` 请求头校验管理员权限
- **代码结构**（DDD 六边形架构 + Maven 多模块）:
```
awsome-shop-points-service/
  bootstrap/
  common/
  domain/
    domain-api/
    domain-impl/
    domain-model/
    repository-api/
  application/
    application-api/
    application-impl/
  interface/
    interface-http/
    interface-consumer/     # 定时任务调度
  infrastructure/
    repository/
      mysql-impl/
    cache/
      redis-impl/
```

### Unit 5: 兑换服务 (awsome-shop-order-service)
- **类型**: 微服务
- **职责**: 兑换流程处理、兑换记录管理、兑换状态管理
- **包含组件**: BE-ORDER, DA-ORDER
- **数据表**: orders
- **API 前缀**: `/api/v1/order/**`
- **部署**: Docker 容器
- **跨服务调用**: 调用 product-service（库存校验/扣减）、points-service（积分校验/扣除）
- **说明**: 服务内部根据 `X-Operator-Id` 请求头获取操作人信息；管理员查看订单时校验权限
- **代码结构**（DDD 六边形架构 + Maven 多模块）:
```
awsome-shop-order-service/
  bootstrap/
  common/
  domain/
    domain-api/
    domain-impl/
    domain-model/
    repository-api/
  application/
    application-api/
    application-impl/
  interface/
    interface-http/
  infrastructure/
    repository/
      mysql-impl/
    cache/
      redis-impl/
    gateway/
      gateway-impl/         # 跨服务调用客户端
```

### Unit 6: API 网关 (awsome-shop-gateway-service)
- **类型**: 微服务（网关）
- **职责**:
  - 统一入口：所有前端请求通过网关转发到后端微服务
  - 令牌校验：调用 auth-service 的 `/api/v1/internal/auth/validate` 接口远程校验 JWT 令牌
  - 用户信息注入：将 `X-Operator-Id` 请求头注入到下游服务请求中
  - 请求路由：根据 URL 前缀将请求转发到对应微服务
  - 公开端点放行：`/api/v1/public/**` 无需认证
- **路由规则**:
  - `/api/v1/public/auth/**` → auth-service（公开）
  - `/api/v1/auth/**` → auth-service
  - `/api/v1/product/**` → product-service
  - `/api/v1/points/**` → points-service
  - `/api/v1/order/**` → order-service
  - `/api/v1/internal/**` → 内部接口（可配置拒绝外部访问）
- **认证流程**:
  1. 检查路径是否为公开端点（`/api/v1/public/**`），是则直接放行
  2. 提取 JWT 令牌从 `Authorization: Bearer <token>` 请求头
  3. 调用 auth-service 的 `/api/v1/internal/auth/validate` 接口验证令牌
  4. 若验证成功，提取 userId，注入 `X-Operator-Id: <userId>` 请求头
  5. 转发请求到目标微服务
- **部署**: Docker 容器
- **代码结构**（DDD 六边形架构 + Maven 多模块）:
```
awsome-shop-gateway-service/
  bootstrap/
  common/
  infrastructure/
    gateway/
      gateway-impl/         # 网关过滤器、路由配置
```

### Unit 7: 基础设施 (infrastructure)
- **类型**: 基础设施
- **职责**: Docker Compose 编排、数据库初始化、环境配置
- **包含内容**: docker-compose.yml、MySQL 数据库、Redis、环境配置
- **数据库迁移**: 各服务使用 Flyway 管理数据库版本和迁移脚本
- **代码结构**:
```
infrastructure/
  docker-compose.yml
  mysql/
    # 各服务使用 Flyway 管理迁移脚本（位于各服务的 resources/db/migration/）
  .env.example      # 环境变量模板
```

---

## 工作单元摘要

| 单元 | 名称 | 类型 | 组件数 | 数据表 |
|------|------|------|--------|--------|
| Unit 1 | awsome-shop-frontend | SPA 前端 | 6 | — |
| Unit 2 | awsome-shop-auth-service | 微服务 | 3 | users |
| Unit 3 | awsome-shop-product-service | 微服务 | 3 | product |
| Unit 4 | awsome-shop-points-service | 微服务 | 4 | point_balances, point_transactions, system_configs |
| Unit 5 | awsome-shop-order-service | 微服务 | 2 | orders |
| Unit 6 | awsome-shop-gateway-service | 微服务（网关） | — | — |
| Unit 7 | infrastructure | 基础设施 | — | — |

## 架构优势

- **统一认证**: API 网关通过调用认证服务集中处理令牌校验，业务微服务无需各自实现 JWT 解析逻辑
- **职责分离**: 网关负责认证，各业务服务负责自身的授权逻辑，职责清晰
- **单一入口**: 前端只需对接一个地址（网关），简化前端配置
- **安全隔离**: 业务微服务不直接暴露给外部，仅通过网关访问
- **DDD 六边形架构**: 各服务采用领域驱动设计和六边形架构，核心业务逻辑与基础设施解耦
- **数据库版本管理**: 使用 Flyway 管理数据库迁移，版本可追溯
