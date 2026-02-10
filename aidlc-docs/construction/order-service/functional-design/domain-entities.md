# Unit 5: order-service — 领域实体与 API 定义

---

## 1. 领域实体

### Order（兑换订单）

| 字段 | 类型 | 说明 |
|------|------|------|
| id | Long | 订单ID |
| userId | Long | 用户ID（逻辑关联 auth_db.users） |
| productId | Long | 产品ID（逻辑关联 product_db.products） |
| productName | String | 产品名称（冗余快照） |
| productImageUrl | String? | 产品图片（冗余快照） |
| pointsCost | Integer | 消耗积分 |
| status | OrderStatus | 兑换状态 |
| createdAt | DateTime | 创建时间 |
| updatedAt | DateTime | 更新时间 |

### OrderStatus（兑换状态枚举）

| 值 | 说明 | 可流转到 |
|----|------|---------|
| PENDING | 已兑换，等待自取 | READY, CANCELLED |
| READY | 可自取 | COMPLETED, CANCELLED |
| COMPLETED | 已完成 | （终态） |
| CANCELLED | 已取消 | （终态） |

### 状态流转图

```
PENDING → READY → COMPLETED
  │         │
  └─────────┴──→ CANCELLED
```

---

## 2. 请求 DTO

### CreateOrderRequest（创建兑换订单）

| 字段 | 类型 | 必填 | 校验 |
|------|------|------|------|
| productId | Long | 是 | > 0 |

说明：userId 从请求头 X-User-Id 获取，不在请求体中传递。

### UpdateOrderStatusRequest（更新兑换状态）

| 字段 | 类型 | 必填 | 校验 |
|------|------|------|------|
| status | String | 是 | 必须为合法的目标状态 |

---

## 3. 响应 DTO

### OrderResponse

| 字段 | 类型 | 说明 |
|------|------|------|
| id | Long | 订单ID |
| userId | Long | 用户ID |
| productId | Long | 产品ID |
| productName | String | 产品名称 |
| productImageUrl | String? | 产品图片 |
| pointsCost | Integer | 消耗积分 |
| status | String | 兑换状态 |
| createdAt | DateTime | 创建时间 |
| updatedAt | DateTime | 更新时间 |

### PageResponse\<T\>

| 字段 | 类型 | 说明 |
|------|------|------|
| content | List\<T\> | 数据列表 |
| totalElements | Long | 总记录数 |
| totalPages | Integer | 总页数 |
| currentPage | Integer | 当前页码 |

---

## 4. API 端点定义

### 员工端点（需要认证）

| 方法 | 路径 | 请求体 | 响应体 | 说明 |
|------|------|--------|--------|------|
| POST | /api/orders | CreateOrderRequest | OrderResponse | 创建兑换订单 |
| GET | /api/orders?page=&size= | — | PageResponse\<OrderResponse\> | 查询当前用户兑换历史 |
| GET | /api/orders/{id} | — | OrderResponse | 查询兑换详情 |

说明：当前用户 ID 从请求头 `X-User-Id`（API 网关注入）获取。

### 管理员端点（需要管理员角色）

| 方法 | 路径 | 请求体 | 响应体 | 说明 |
|------|------|--------|--------|------|
| GET | /api/admin/orders?page=&size=&keyword=&startDate=&endDate= | — | PageResponse\<OrderResponse\> | 查看所有兑换记录 |
| PUT | /api/admin/orders/{id}/status | UpdateOrderStatusRequest | OrderResponse | 更新兑换状态 |

管理员查询参数：
- `page`, `size`: 分页参数
- `keyword`: 按产品名称搜索（匹配 productName 冗余字段）
- `startDate`, `endDate`: 时间范围筛选（ISO 8601 格式）
