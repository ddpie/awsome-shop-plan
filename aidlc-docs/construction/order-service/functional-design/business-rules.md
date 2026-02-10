# Unit 5: order-service — 业务规则

---

## 1. 校验规则

### 创建兑换订单
| 字段 | 规则 | 错误码 |
|------|------|--------|
| productId | 必填，> 0 | 400 Bad Request |

### 更新兑换状态
| 字段 | 规则 | 错误码 |
|------|------|--------|
| status | 必填，合法的 OrderStatus 值 | 400 Bad Request |

### 分页参数
| 参数 | 默认值 | 范围 |
|------|--------|------|
| page | 0 | ≥ 0 |
| size | 20 | 1 ~ 100 |

---

## 2. 业务规则

### BR-ORDER-001: 兑换前置条件
- 产品必须存在且状态为 ACTIVE
- 产品库存 > 0
- 用户积分余额 ≥ 产品所需积分
- 三个条件全部满足才允许兑换

### BR-ORDER-002: 先校验再执行
- 兑换流程先进行预校验（查询产品信息和积分余额，不加锁）
- 预校验通过后再执行扣除操作
- 预校验可快速拦截不满足条件的请求，减少锁竞争

### BR-ORDER-003: 扣除顺序 — 先积分后库存
- 先扣除积分（points-service），再扣减库存（product-service）
- 库存扣减失败时，回滚积分
- 积分是虚拟资产，回滚更安全可靠

### BR-ORDER-004: 补偿回滚策略
- 库存扣减失败 → 回滚积分 + 删除订单记录
- 积分回滚失败 → 记录错误日志，需人工介入
- 库存恢复失败 → 记录错误日志，需人工介入
- 采用"最大努力"补偿策略，适合 MVP 阶段

### BR-ORDER-005: 产品快照
- 创建订单时，将产品名称和图片 URL 冗余存储到订单记录
- 即使产品后续被修改或删除，兑换历史中仍保留原始信息

### BR-ORDER-006: 状态流转规则
- 状态只能前进，不能后退
- 合法流转：
  - PENDING → READY（管理员标记可自取）
  - PENDING → CANCELLED（管理员取消）
  - READY → COMPLETED（管理员标记已完成）
  - READY → CANCELLED（管理员取消）
- 非法流转返回 ORDER_009 错误
- COMPLETED 和 CANCELLED 为终态，不可再变更

### BR-ORDER-007: 取消自动退还
- 管理员将订单状态更新为 CANCELLED 时，自动执行：
  - 回滚积分（调用 points-service 回滚接口）
  - 恢复库存（调用 product-service 恢复接口）
- 退还操作失败不阻塞状态更新
- 失败情况记录日志，由管理员人工处理

### BR-ORDER-008: 订单归属校验
- 员工查看兑换详情时，校验订单的 userId 与当前用户一致
- 不允许查看他人的兑换订单

### BR-ORDER-009: 跨服务调用超时
- 所有跨服务调用超时时间：3 秒
- 超时视为调用失败，执行对应的补偿逻辑

---

## 3. 错误码

| 错误码 | HTTP 状态码 | 消息 | 触发场景 |
|--------|------------|------|---------|
| ORDER_001 | 404 | 产品不存在 | 兑换时产品 ID 无效 |
| ORDER_002 | 400 | 产品已下架 | 兑换时产品 status ≠ ACTIVE |
| ORDER_003 | 400 | 库存不足 | 兑换时产品库存 ≤ 0 |
| ORDER_004 | 400 | 积分账户不存在 | 兑换时用户无积分余额记录 |
| ORDER_005 | 400 | 积分不足，无法兑换 | 兑换时积分余额 < 所需积分 |
| ORDER_006 | 404 | 兑换记录不存在 | 查询/操作时订单 ID 无效 |
| ORDER_007 | 403 | 无权查看此兑换记录 | 员工查看他人订单 |
| ORDER_008 | 500 | 兑换处理失败，请稍后重试 | 跨服务调用超时或异常 |
| ORDER_009 | 400 | 非法状态变更 | 状态流转不符合规则 |
| ORDER_010 | 500 | 取消退还处理异常 | 取消时积分回滚或库存恢复失败（订单仍标记为 CANCELLED） |

### 统一错误响应格式
```json
{
  "code": "ORDER_001",
  "message": "产品不存在",
  "data": null
}
```

---

## 4. 边界条件

### 兑换数量
- 每次兑换固定 1 件产品（quantity = 1）
- 不支持批量兑换

### 并发兑换
- 多个用户同时兑换同一产品：由 product-service 悲观锁保证库存不超卖
- 同一用户同时发起多次兑换：由 points-service 悲观锁保证积分不超扣
- 预校验通过但执行时条件已变：扣除接口返回错误，order-service 执行补偿

### 订单查询
- 员工只能查看自己的订单
- 管理员可查看所有订单
- 管理员按产品名称搜索使用订单中的冗余字段（productName），不跨服务查询

### 取消场景
- 仅管理员可取消订单（员工不可自行取消）
- PENDING 和 READY 状态的订单可取消
- COMPLETED 状态的订单不可取消
- 取消后积分和库存自动退还

### 时间范围筛选
- startDate 和 endDate 为可选参数
- 仅提供 startDate：查询该日期之后的记录
- 仅提供 endDate：查询该日期之前的记录
- 两者都提供：查询该时间范围内的记录

---

## 5. 跨服务交互约定

### order-service → product-service
- 查询产品：`GET http://product-service:8002/api/internal/products/{id}`
- 扣减库存：`POST http://product-service:8002/api/internal/products/deduct-stock`
- 恢复库存：`POST http://product-service:8002/api/internal/products/restore-stock`
- 超时：3 秒

### order-service → points-service
- 查询余额：`GET http://points-service:8003/api/internal/points/balance/{userId}`
- 扣除积分：`POST http://points-service:8003/api/internal/points/deduct`
- 回滚积分：`POST http://points-service:8003/api/internal/points/rollback`
- 超时：3 秒

### 内部接口安全
- 所有内部接口（/api/internal/*）不经过 API 网关
- 仅在 Docker 内部网络中可访问
- 不需要 JWT 认证（服务间信任）
