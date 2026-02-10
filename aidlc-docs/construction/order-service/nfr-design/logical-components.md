# Unit 5: order-service — 逻辑组件清单

---

## 1. 组件清单

| # | 组件 | 类型 | 职责 | 关联 NFR |
|---|------|------|------|---------|
| 1 | OrderController | REST 控制器 | 员工兑换端点（创建订单、查询历史、查询详情） | NFR-ORD-SEC-001, NFR-ORD-SEC-002 |
| 2 | AdminOrderController | REST 控制器 | 管理员端点（查看所有记录、更新状态） | NFR-ORD-SEC-002 |
| 3 | OrderService | 业务逻辑 | 兑换核心逻辑（预校验、顺序扣除、补偿回滚、取消退还） | NFR-ORD-REL-001, NFR-ORD-REL-003 |
| 4 | OrderRepository | 数据访问 | orders 表 CRUD + 分页查询 + 条件筛选 | NFR-ORD-PERF-003 |
| 5 | ProductServiceClient | 远程调用 | 调用 product-service（查询产品、扣减/恢复库存） | NFR-ORD-REL-001, NFR-ORD-REL-004 |
| 6 | PointsServiceClient | 远程调用 | 调用 points-service（查询余额、扣除/回滚积分） | NFR-ORD-REL-001, NFR-ORD-REL-004 |
| 7 | RetryableHttpClient | 基础设施 | HTTP 客户端封装，支持超时配置和自动重试 | NFR-ORD-REL-001, NFR-ORD-REL-004 |
| 8 | GlobalExceptionHandler | 横切关注点 | 统一异常捕获、跨服务错误转换、错误响应格式化 | NFR-ORD-MAINT-001 |

---

## 2. 目录结构

```
order-service/
  src/
    controller/
      OrderController           # 员工兑换端点
      AdminOrderController      # 管理员端点
    service/
      OrderService              # 兑换核心业务逻辑
    repository/
      OrderRepository           # 订单数据访问
    client/
      ProductServiceClient      # product-service 远程调用
      PointsServiceClient       # points-service 远程调用
      RetryableHttpClient       # 可重试 HTTP 客户端
    model/
      Order                     # 订单实体
      OrderStatus               # 状态枚举
    dto/
      CreateOrderRequest        # 创建兑换请求
      UpdateOrderStatusRequest  # 更新状态请求
      OrderResponse             # 订单响应
      PageResponse              # 分页响应
    config/                     # 数据库配置、HTTP 客户端配置
    exception/
      GlobalExceptionHandler    # 统一异常处理
      OrderException            # 业务异常类
```

---

## 3. 组件交互图

```
┌──────────────────────────────────────────────────────────────────┐
│                       order-service                               │
│                                                                   │
│  ┌─────────────────┐  ┌────────────────────┐                    │
│  │ OrderController  │  │AdminOrderController │                    │
│  │  (员工端点)       │  │  (管理员端点)        │                    │
│  │  POST /api/orders│  │  GET /api/admin/... │                    │
│  │  GET /api/orders │  │  PUT /api/admin/... │                    │
│  └────────┬────────┘  └─────────┬───────────┘                    │
│           │                      │                                │
│  ┌────────┴──────────────────────┴──────────┐                    │
│  │              OrderService                 │                    │
│  │  (预校验/顺序扣除/补偿回滚/取消退还)        │                    │
│  └──┬──────────────┬──────────────┬─────────┘                    │
│     │              │              │                                │
│     ▼              ▼              ▼                                │
│  ┌──────────┐ ┌──────────────┐ ┌──────────────┐                 │
│  │OrderRepo │ │ProductService│ │PointsService │                 │
│  │(数据访问) │ │   Client     │ │   Client     │                 │
│  └──────────┘ └──────┬───────┘ └──────┬───────┘                 │
│                       │                │                          │
│                       └────────┬───────┘                          │
│                                ▼                                  │
│                    ┌──────────────────────┐                       │
│                    │ RetryableHttpClient   │                       │
│                    │ (超时3s + 重试1次)     │                       │
│                    └──────────────────────┘                       │
│                                                                   │
│  ┌──────────────────────┐                                        │
│  │GlobalExceptionHandler │  (横切：统一错误处理 + 跨服务错误转换)    │
│  └──────────────────────┘                                        │
└──────────────────────────────────────────────────────────────────┘
         │                              │
         ▼                              ▼
  ┌──────────────┐            ┌──────────────────┐
  │product-service│            │ points-service    │
  │  :8002        │            │  :8003            │
  └──────────────┘            └──────────────────┘
```

---

## 4. 组件职责详述

### RetryableHttpClient（可重试 HTTP 客户端）
- 封装 HTTP 调用的超时和重试逻辑
- 配置: 连接超时 1s、读取超时 2s、重试 1 次
- 仅对超时和网络异常重试，业务错误（4xx）不重试
- ProductServiceClient 和 PointsServiceClient 共用此组件

### ProductServiceClient
- 封装对 product-service 的所有调用
- 方法:
  - `getProduct(productId)` → GET /api/internal/products/{id}
  - `deductStock(productId, quantity)` → POST /api/internal/products/deduct-stock
  - `restoreStock(productId, quantity)` → POST /api/internal/products/restore-stock
- 基础 URL 通过环境变量 PRODUCT_SERVICE_URL 配置

### PointsServiceClient
- 封装对 points-service 的所有调用
- 方法:
  - `getBalance(userId)` → GET /api/internal/points/balance/{userId}
  - `deductPoints(userId, amount, orderId)` → POST /api/internal/points/deduct
  - `rollbackDeduction(transactionId)` → POST /api/internal/points/rollback
- 基础 URL 通过环境变量 POINTS_SERVICE_URL 配置

### OrderService（核心业务逻辑）
- `createOrder(userId, productId)` — 完整兑换流程（预校验→创建订单→扣积分→扣库存→补偿）
- `getMyOrders(userId, page, size)` — 员工查询自己的订单
- `getOrderDetail(userId, orderId)` — 员工查询订单详情（含归属校验）
- `getAllOrders(page, size, keyword, startDate, endDate)` — 管理员查看所有记录
- `updateOrderStatus(orderId, targetStatus)` — 管理员更新状态（含取消自动退还）

---

## 5. NFR 需求覆盖映射

| NFR 编号 | 描述 | 实现组件 | 设计模式 |
|---------|------|---------|---------|
| NFR-ORD-SEC-001 | 订单归属校验 | OrderController, OrderService | 分层输入校验 |
| NFR-ORD-SEC-002 | 输入校验 | OrderController, AdminOrderController | 分层输入校验 |
| NFR-ORD-SEC-003 | 内部接口依赖安全 | ProductServiceClient, PointsServiceClient | — (Docker 网络隔离) |
| NFR-ORD-PERF-001 | 兑换流程 P95 ≤ 2s | OrderService, RetryableHttpClient | 跨服务调用重试与容错 |
| NFR-ORD-PERF-002 | 查询接口 P95 ≤ 200ms | OrderRepository | 产品快照冗余 |
| NFR-ORD-PERF-003 | 分页查询性能 | OrderRepository | — |
| NFR-ORD-REL-001 | 跨服务调用重试 | RetryableHttpClient | 跨服务调用重试与容错 |
| NFR-ORD-REL-002 | 幂等性依赖 | ProductServiceClient, PointsServiceClient | 跨服务调用重试与容错 |
| NFR-ORD-REL-003 | 补偿一致性 | OrderService | 顺序扣除与补偿回滚, 取消自动退还 |
| NFR-ORD-REL-004 | 跨服务调用超时 | RetryableHttpClient | 跨服务调用重试与容错 |
| NFR-ORD-REL-005 | 产品快照完整性 | OrderService, OrderRepository | 产品快照冗余 |
| NFR-ORD-MAINT-001 | 统一错误响应格式 | GlobalExceptionHandler | 统一错误处理 |
| NFR-ORD-MAINT-002 | 日志规范 | OrderService | 取消自动退还 |
| NFR-ORD-MAINT-003 | 配置外部化 | config/ | 配置外部化 |
| NFR-ORD-TEST-001 | 接口可测试 | 所有 Controller | — |
| NFR-ORD-TEST-002 | 补偿逻辑可测试 | OrderService | — |

**覆盖率**: 16/16 NFR 需求全部覆盖 ✅
