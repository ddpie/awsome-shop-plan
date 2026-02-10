# AWSomeShop 工作单元定义

## 分解策略

- **后端**: 微服务架构 — 每个业务模块独立部署为单独的服务
- **前端**: 单页应用（SPA）— 一个前端项目包含所有页面
- **API 网关**: 独立服务 — 统一处理认证、权限校验、请求路由
- **开发模式**: 前端和后端独立开发，后端按业务模块分微服务

---

## 工作单元列表

### Unit 1: 前端应用 (awsomeshop-frontend)
- **类型**: SPA 前端应用
- **职责**: 所有用户界面，包含员工端和管理端
- **包含组件**: FE-AUTH, FE-PRODUCT, FE-POINTS, FE-ORDER, FE-ADMIN, FE-COMMON
- **部署**: Docker 容器（Nginx 静态文件服务）
- **代码结构**:
```
awsomeshop-frontend/
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

### Unit 2: 认证服务 (auth-service)
- **类型**: 微服务
- **职责**: 用户注册、登录、JWT 令牌生成、密码加密、用户信息管理
- **包含组件**: BE-AUTH, BE-USER, DA-USER
- **数据表**: users
- **API 前缀**: /api/auth/*, /api/users/*
- **部署**: Docker 容器
- **说明**: 仅负责令牌生成和用户管理，不负责令牌校验（由 API 网关统一处理）
- **代码结构**:
```
auth-service/
  src/
    controller/     # REST 控制器
    service/        # 业务逻辑
    repository/     # 数据访问
    model/          # 数据模型
    config/         # 配置（JWT 签名密钥）
    dto/            # 数据传输对象
```

### Unit 3: 产品服务 (product-service)
- **类型**: 微服务
- **职责**: 产品 CRUD、分类管理、产品搜索、库存管理
- **包含组件**: BE-PRODUCT, BE-CATEGORY, BE-FILE, DA-PRODUCT, DA-CATEGORY
- **数据表**: products, categories
- **API 前缀**: /api/products/*, /api/categories/*, /api/admin/products/*, /api/admin/categories/*, /api/files/*
- **部署**: Docker 容器 + 本地文件卷挂载（图片存储）
- **代码结构**:
```
product-service/
  src/
    controller/
    service/
    repository/
    model/
    config/
    dto/
  uploads/          # 图片存储目录（Docker 卷挂载）
```

### Unit 4: 积分服务 (points-service)
- **类型**: 微服务
- **职责**: 积分余额管理、积分变动记录、积分自动发放（定时任务）、发放配置
- **包含组件**: BE-POINTS, BE-SCHEDULER, DA-POINTS, DA-CONFIG
- **数据表**: point_balances, point_transactions, system_configs
- **API 前缀**: /api/points/*, /api/admin/points/*
- **部署**: Docker 容器
- **代码结构**:
```
points-service/
  src/
    controller/
    service/
    repository/
    model/
    config/
    dto/
    scheduler/      # 定时任务
```

### Unit 5: 兑换服务 (order-service)
- **类型**: 微服务
- **职责**: 兑换流程处理、兑换记录管理、兑换状态管理
- **包含组件**: BE-ORDER, DA-ORDER
- **数据表**: orders
- **API 前缀**: /api/orders/*, /api/admin/orders/*
- **部署**: Docker 容器
- **跨服务调用**: 调用 product-service（库存校验/扣减）、points-service（积分校验/扣除）
- **代码结构**:
```
order-service/
  src/
    controller/
    service/
    repository/
    model/
    config/
    dto/
    client/         # 跨服务调用客户端
```

### Unit 6: API 网关 (api-gateway)
- **类型**: 微服务（网关）
- **职责**:
  - 统一入口：所有前端请求通过网关转发到后端微服务
  - JWT 令牌校验：对所有受保护端点进行认证检查
  - 角色权限校验：管理员端点（/api/admin/*）校验管理员角色
  - 请求路由：根据 URL 前缀将请求转发到对应微服务
  - 公开端点放行：/api/auth/register、/api/auth/login 无需认证
- **路由规则**:
  - /api/auth/* → auth-service
  - /api/users/* → auth-service
  - /api/products/* → product-service
  - /api/categories/* → product-service
  - /api/files/* → product-service
  - /api/points/* → points-service
  - /api/orders/* → order-service
  - /api/admin/products/* → product-service
  - /api/admin/categories/* → product-service
  - /api/admin/points/* → points-service
  - /api/admin/orders/* → order-service
  - /api/admin/users/* → auth-service
- **权限规则**:
  - 公开端点（无需认证）: POST /api/auth/register, POST /api/auth/login
  - 员工端点（需要认证）: /api/products/*, /api/categories/*, /api/points/*, /api/orders/*
  - 管理员端点（需要管理员角色）: /api/admin/*
- **部署**: Docker 容器
- **代码结构**:
```
api-gateway/
  src/
    filter/         # 认证过滤器、权限过滤器
    config/         # 路由配置、JWT 配置
    model/          # 用户信息模型
    util/           # JWT 工具类
```

### Unit 7: 基础设施 (infrastructure)
- **类型**: 基础设施
- **职责**: Docker Compose 编排、数据库初始化、环境配置
- **包含内容**: docker-compose.yml、MySQL 初始化脚本、环境配置
- **代码结构**:
```
infrastructure/
  docker-compose.yml
  mysql/
    init.sql        # 数据库初始化脚本（所有服务的表）
  .env.example      # 环境变量模板
```

---

## 工作单元摘要

| 单元 | 名称 | 类型 | 组件数 | 数据表 |
|------|------|------|--------|--------|
| Unit 1 | awsomeshop-frontend | SPA 前端 | 6 | — |
| Unit 2 | auth-service | 微服务 | 3 | users |
| Unit 3 | product-service | 微服务 | 5 | products, categories |
| Unit 4 | points-service | 微服务 | 4 | point_balances, point_transactions, system_configs |
| Unit 5 | order-service | 微服务 | 2 | orders |
| Unit 6 | api-gateway | 微服务（网关） | — | — |
| Unit 7 | infrastructure | 基础设施 | — | — |

## 架构优势

- **统一认证**: API 网关集中处理 JWT 校验，业务微服务无需各自实现认证逻辑
- **统一权限**: 管理员权限在网关层统一校验，业务服务只关注业务逻辑
- **单一入口**: 前端只需对接一个地址（网关），简化前端配置
- **安全隔离**: 业务微服务不直接暴露给外部，仅通过网关访问
