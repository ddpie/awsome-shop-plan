# Unit 5: order-service — 部署架构

---

## 1. 部署拓扑

```
┌─────────────────────────────────────────────────────────────────┐
│                    Docker Host (开发机)                           │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │              awsomeshop-net (bridge network)              │   │
│  │                                                           │   │
│  │  ┌─────────────┐    ┌──────────────┐                     │   │
│  │  │  nginx       │    │ api-gateway  │                     │   │
│  │  │  :80 → :8080 │───→│  :8080       │                     │   │
│  │  └─────────────┘    └──────┬───────┘                     │   │
│  │                            │                              │   │
│  │      ┌─────────────────────┼─────────────────────┐       │   │
│  │      │          │          │          │           │       │   │
│  │      ▼          ▼          ▼          ▼           ▼       │   │
│  │  ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐           │   │
│  │  │auth    │ │product │ │points  │ │order   │           │   │
│  │  │:8001   │ │:8002   │ │:8003   │ │:8004   │           │   │
│  │  └───┬────┘ └───┬────┘ └───┬────┘ └───┬────┘           │   │
│  │      │          │          │          │                  │   │
│  │      │          │          │     ┌────┤                  │   │
│  │      │          │          │     │    │                  │   │
│  │      │          │◄─────────┼─────┘    │ (HTTP 调用)      │   │
│  │      │          │          │◄─────────┘                  │   │
│  │      │          │          │                              │   │
│  │      └──────────┴──────────┴──────────┐                  │   │
│  │                                       ▼                  │   │
│  │                              ┌──────────────┐            │   │
│  │                              │    mysql      │            │   │
│  │                              │  :3306        │            │   │
│  │                              │  ├─ auth_db   │            │   │
│  │                              │  ├─ product_db│            │   │
│  │                              │  ├─ points_db │            │   │
│  │                              │  └─ order_db  │            │   │
│  │                              └──────────────┘            │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                  │
│  端口映射: 宿主机:80 → nginx:80                                   │
│           宿主机:3306 → mysql:3306                                │
└─────────────────────────────────────────────────────────────────┘
```

---

## 2. 端口分配汇总（全部确定）

| 服务 | 内部端口 | 对外暴露 | 说明 |
|------|---------|---------|------|
| nginx | 80 | 是（:80） | 前端静态文件 + 反向代理 |
| api-gateway | 8080 | 否 | 统一 API 入口 |
| auth-service | 8001 | 否 | 认证服务 |
| product-service | 8002 | 否 | 产品服务 |
| points-service | 8003 | 否 | 积分服务 |
| order-service | 8004 | 否 | 兑换服务 |
| mysql | 3306 | 是（:3306） | 数据库（开发调试用） |

> ✅ 所有后端微服务端口已全部确定。

---

## 3. 启动流程

```
1. mysql 启动
   └── healthcheck: mysqladmin ping（通过后标记 healthy）

2. 微服务并行启动（depends_on mysql: service_healthy）
   ├── auth-service (:8001)
   ├── product-service (:8002)
   ├── points-service (:8003)
   └── order-service (:8004)
       └── healthcheck: curl http://localhost:8004/actuator/health

3. api-gateway 启动（depends_on 各微服务: service_healthy）

4. nginx 启动（depends_on api-gateway）
```

---

## 4. 请求流转路径

### 路径 1: 员工创建兑换订单（核心流程）
```
浏览器 → nginx:80
  → /api/orders
  → api-gateway:8080（JWT 校验，注入 X-User-Id）
  → order-service:8004 POST /api/orders
  │
  ├── 预校验:
  │   ├── → product-service:8002 GET /api/internal/products/{id}
  │   └── → points-service:8003 GET /api/internal/points/balance/{userId}
  │
  ├── 创建订单记录（order_db.orders, status=PENDING）
  │
  ├── 扣除积分:
  │   └── → points-service:8003 POST /api/internal/points/deduct
  │
  ├── 扣减库存:
  │   └── → product-service:8002 POST /api/internal/products/deduct-stock
  │         └── 失败 → points-service:8003 POST /api/internal/points/rollback
  │
  └── 返回 OrderResponse
```

### 路径 2: 员工查询兑换历史
```
浏览器 → nginx:80
  → /api/orders?page=0&size=20
  → api-gateway:8080（JWT 校验，注入 X-User-Id）
  → order-service:8004 GET /api/orders
  → mysql:3306 (order_db.orders WHERE user_id = ?)
  → 返回 PageResponse<OrderResponse>
```

### 路径 3: 员工查询兑换详情
```
浏览器 → nginx:80
  → /api/orders/{id}
  → api-gateway:8080（JWT 校验，注入 X-User-Id）
  → order-service:8004 GET /api/orders/{id}
  → mysql:3306 (order_db.orders WHERE id = ? AND user_id = ?)
  → 返回 OrderResponse
```

### 路径 4: 管理员查看所有兑换记录
```
浏览器 → nginx:80
  → /api/admin/orders?page=0&size=20&keyword=xxx
  → api-gateway:8080（JWT 校验 + 管理员角色校验）
  → order-service:8004 GET /api/admin/orders
  → mysql:3306 (order_db.orders 条件查询)
  → 返回 PageResponse<OrderResponse>
```

### 路径 5: 管理员更新兑换状态
```
浏览器 → nginx:80
  → /api/admin/orders/{id}/status
  → api-gateway:8080（JWT 校验 + 管理员角色校验）
  → order-service:8004 PUT /api/admin/orders/{id}/status
  │
  ├── 校验状态流转合法性
  │
  ├── 如果目标状态为 CANCELLED:
  │   ├── 更新订单状态为 CANCELLED
  │   ├── → points-service:8003 POST /api/internal/points/rollback（回滚积分）
  │   └── → product-service:8002 POST /api/internal/products/restore-stock（恢复库存）
  │
  ├── 其他状态: 直接更新
  │
  └── 返回 OrderResponse
```

### 路径 6: order-service 跨服务调用汇总
```
order-service:8004
  │
  ├── → product-service:8002
  │     ├── GET  /api/internal/products/{id}          (预校验-查询产品)
  │     ├── POST /api/internal/products/deduct-stock   (扣减库存)
  │     └── POST /api/internal/products/restore-stock  (恢复库存-取消时)
  │
  └── → points-service:8003
        ├── GET  /api/internal/points/balance/{userId} (预校验-查询余额)
        ├── POST /api/internal/points/deduct           (扣除积分)
        └── POST /api/internal/points/rollback         (回滚积分-补偿/取消时)

所有跨服务调用: 超时 3s，重试 1 次，仅对超时/网络异常重试
```

---

## 5. 故障恢复

### order-service 容器重启
- 重启后 healthcheck 通过前，api-gateway 路由到该服务的请求会失败
- 已创建但未完成的兑换流程：
  - 如果积分已扣但库存未扣：积分已扣除，订单记录为 PENDING（需管理员取消退还）
  - 如果积分和库存都已扣：订单正常，状态为 PENDING
- 数据库连接池自动重连（依赖后端框架实现）

### product-service 或 points-service 不可用
- 兑换流程中跨服务调用失败 → 重试 1 次 → 仍失败则补偿回滚
- 查询类接口不受影响（仅查询本地 order_db）
- 取消退还失败 → 记录 ERROR 日志，订单仍标记为 CANCELLED

### MySQL 重启
- order-service 依赖 MySQL 健康检查
- 数据库连接池自动重连

---

## 6. 开发调试

### 查看订单数据
```bash
# 连接 MySQL 查看订单
mysql -h 127.0.0.1 -P 3306 -u order_user -p order_db

# 查看所有订单
SELECT * FROM orders ORDER BY created_at DESC LIMIT 20;

# 查看特定用户的订单
SELECT * FROM orders WHERE user_id = 1 ORDER BY created_at DESC;

# 查看特定状态的订单
SELECT * FROM orders WHERE status = 'PENDING';

# 查看取消的订单（检查退还是否成功）
SELECT id, user_id, product_name, points_cost, points_transaction_id, status
FROM orders WHERE status = 'CANCELLED';
```

### 测试 API
```bash
# 创建兑换订单（需要通过 api-gateway，携带 JWT）
curl -X POST http://localhost/api/orders \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <token>" \
  -d '{"productId": 1}'

# 查询兑换历史
curl http://localhost/api/orders?page=0&size=10 \
  -H "Authorization: Bearer <token>"

# 管理员查看所有记录
curl "http://localhost/api/admin/orders?page=0&size=10" \
  -H "Authorization: Bearer <admin-token>"

# 管理员更新状态
curl -X PUT http://localhost/api/admin/orders/1/status \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <admin-token>" \
  -d '{"status": "READY"}'
```

> 注意：order-service 不对外暴露端口，所有请求必须通过 nginx → api-gateway 路由。如需直接测试，可使用 `docker exec` 进入容器或临时暴露端口。
