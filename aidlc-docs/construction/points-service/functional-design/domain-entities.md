# Unit 4: points-service — 领域实体与 API 定义

---

## 1. 领域实体

### PointBalance（积分余额）

| 字段 | 类型 | 说明 |
|------|------|------|
| id | Long | 记录ID |
| userId | Long | 用户ID（逻辑关联 auth_db.users） |
| balance | Integer | 当前积分余额（≥ 0） |
| createdAt | DateTime | 创建时间 |
| updatedAt | DateTime | 更新时间 |

### PointTransaction（积分变动流水）

| 字段 | 类型 | 说明 |
|------|------|------|
| id | Long | 流水ID |
| userId | Long | 用户ID |
| type | TransactionType | 变动类型 |
| amount | Integer | 变动数量（正数增加，负数减少） |
| balanceAfter | Integer | 变动后余额 |
| referenceId | Long? | 关联ID（兑换订单ID等） |
| operatorId | Long? | 操作人ID（手动调整时） |
| remark | String? | 备注 |
| createdAt | DateTime | 创建时间 |

### TransactionType（变动类型枚举）

| 值 | 说明 | amount 符号 |
|----|------|-------------|
| DISTRIBUTION | 系统自动发放 | 正数 |
| MANUAL_ADD | 管理员手动增加 | 正数 |
| MANUAL_DEDUCT | 管理员手动扣除 | 负数 |
| REDEMPTION | 兑换扣除 | 负数 |
| ROLLBACK | 兑换回滚 | 正数 |

### SystemConfig（系统配置）

| 字段 | 类型 | 说明 |
|------|------|------|
| id | Long | 配置ID |
| configKey | String | 配置键（唯一） |
| configValue | String | 配置值 |
| description | String? | 配置说明 |
| updatedAt | DateTime | 更新时间 |

#### 预置配置项

| configKey | 默认值 | 说明 |
|-----------|--------|------|
| points.distribution.amount | 100 | 每月自动发放积分额度 |

---

## 2. 请求 DTO

### InitPointsRequest（积分初始化 — 内部接口）

| 字段 | 类型 | 必填 | 校验 |
|------|------|------|------|
| userId | Long | 是 | > 0 |

### AdjustPointsRequest（管理员手动调整）

| 字段 | 类型 | 必填 | 校验 |
|------|------|------|------|
| userId | Long | 是 | > 0 |
| amount | Integer | 是 | ≠ 0 |
| remark | String | 是 | 非空，最长 500 字符 |

说明：amount 正数为增加，负数为扣除。

### DeductPointsRequest（兑换扣除 — 内部接口）

| 字段 | 类型 | 必填 | 校验 |
|------|------|------|------|
| userId | Long | 是 | > 0 |
| amount | Integer | 是 | > 0（扣除数量，正数表示） |
| orderId | Long | 是 | > 0 |

### RollbackDeductionRequest（兑换回滚 — 内部接口）

| 字段 | 类型 | 必填 | 校验 |
|------|------|------|------|
| transactionId | Long | 是 | > 0 |

### UpdateDistributionConfigRequest（更新发放配置）

| 字段 | 类型 | 必填 | 校验 |
|------|------|------|------|
| amount | Integer | 是 | > 0 |

---

## 3. 响应 DTO

### PointBalanceResponse

| 字段 | 类型 | 说明 |
|------|------|------|
| userId | Long | 用户ID |
| balance | Integer | 当前积分余额 |

### PointTransactionResponse

| 字段 | 类型 | 说明 |
|------|------|------|
| id | Long | 流水ID |
| userId | Long | 用户ID |
| type | String | 变动类型 |
| amount | Integer | 变动数量 |
| balanceAfter | Integer | 变动后余额 |
| referenceId | Long? | 关联ID |
| operatorId | Long? | 操作人ID |
| remark | String? | 备注 |
| createdAt | DateTime | 创建时间 |

### UserPointResponse（管理员视角 — 员工积分列表）

| 字段 | 类型 | 说明 |
|------|------|------|
| userId | Long | 用户ID |
| balance | Integer | 当前积分余额 |

说明：员工姓名、工号等信息由前端根据 userId 从 auth-service 获取，或由 API 网关/BFF 层聚合。points-service 仅返回积分数据。

### DistributionConfigResponse

| 字段 | 类型 | 说明 |
|------|------|------|
| amount | Integer | 每月发放额度 |
| updatedAt | DateTime | 最后更新时间 |

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
| GET | /api/points/balance | — | PointBalanceResponse | 查询当前用户积分余额 |
| GET | /api/points/transactions?page=&size= | — | PageResponse\<PointTransactionResponse\> | 查询当前用户积分变动历史 |

说明：当前用户 ID 从请求头 `X-User-Id`（API 网关注入）获取。

### 管理员端点（需要管理员角色）

| 方法 | 路径 | 请求体 | 响应体 | 说明 |
|------|------|--------|--------|------|
| GET | /api/admin/points/balances?page=&size=&keyword= | — | PageResponse\<UserPointResponse\> | 查看所有员工积分余额 |
| GET | /api/admin/points/transactions/{userId}?page=&size=&type= | — | PageResponse\<PointTransactionResponse\> | 查看指定员工积分变动明细 |
| POST | /api/admin/points/adjust | AdjustPointsRequest | PointTransactionResponse | 手动调整员工积分 |
| GET | /api/admin/points/config | — | DistributionConfigResponse | 获取发放配置 |
| PUT | /api/admin/points/config | UpdateDistributionConfigRequest | DistributionConfigResponse | 更新发放配置 |

### 内部端点（服务间调用，不经过 API 网关）

| 方法 | 路径 | 请求体 | 响应体 | 说明 |
|------|------|--------|--------|------|
| POST | /api/internal/points/init | InitPointsRequest | PointBalanceResponse | 初始化用户积分余额（auth-service 调用） |
| POST | /api/internal/points/deduct | DeductPointsRequest | PointTransactionResponse | 兑换扣除积分（order-service 调用） |
| POST | /api/internal/points/rollback | RollbackDeductionRequest | void | 回滚积分扣除（order-service 调用） |
| GET | /api/internal/points/balance/{userId} | — | PointBalanceResponse | 查询指定用户积分余额（order-service 调用） |
