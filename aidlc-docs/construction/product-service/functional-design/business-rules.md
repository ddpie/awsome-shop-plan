# Unit 3: product-service — 业务规则

---

## 1. 校验规则

### 产品校验

| 字段 | 规则 | 错误码 |
|------|------|--------|
| name | 非空，1-200 字符 | BAD_REQUEST_001 |
| subtitle | 最大 200 字符 | BAD_REQUEST_001 |
| sku | 非空，1-100 字符 | BAD_REQUEST_001 |
| category | 非空，1-100 字符 | BAD_REQUEST_001 |
| brand | 最大 100 字符 | BAD_REQUEST_001 |
| pointsPrice | 正数，≥ 0.01 | BAD_REQUEST_001 |
| marketPrice | 正数，≥ 0.01 | BAD_REQUEST_001 |
| stock | 非负整数，≥ 0 | BAD_REQUEST_001 |
| mainImage | 最大 500 字符 | BAD_REQUEST_001 |
| images | JSON 字符串，最大 2000 字符 | BAD_REQUEST_001 |
| description | 最大 5000 字符 | BAD_REQUEST_001 |
| deliveryMethod | 最大 200 字符 | BAD_REQUEST_001 |
| serviceGuarantee | 最大 500 字符 | BAD_REQUEST_001 |
| promotion | 最大 500 字符 | BAD_REQUEST_001 |
| colors | 最大 200 字符 | BAD_REQUEST_001 |
| specs | JSON 字符串，最大 2000 字符 | BAD_REQUEST_001 |

### 文件校验

| 字段 | 规则 | 错误码 |
|------|------|--------|
| 文件 | 非空 | BAD_REQUEST_001 |
| 文件大小 | ≤ 5MB | BAD_REQUEST_001 |
| 文件类型 | jpg, jpeg, png, gif, webp | BAD_REQUEST_001 |

---

## 2. 业务规则

### BR-PROD-001: 产品软删除
- 删除产品时将 status 设为 1（下架），deleted 设为 1（已删除），不物理删除数据
- 已删除产品不在员工端展示
- 管理员可通过 status 筛选查看已下架产品
- 产品图片文件不随软删除而删除

### BR-PROD-002: 产品状态过滤
- 员工端 API（/api/v1/products/*）仅返回 status = 0 且 deleted = 0 的产品
- 管理员端 API（/api/v1/admin/products/*）可查看所有状态的产品（但仅查询 deleted = 0）

### BR-PROD-003: 产品分类
- category 字段为字符串类型，直接存储分类名称
- 不存在独立的分类表和分类管理功能
- 分类名称可以重复使用

### BR-PROD-004: 产品列表排序
- 默认按 created_at DESC 排序（最新上架在前）

### BR-PROD-005: 库存并发控制
- 库存扣减使用悲观锁（SELECT FOR UPDATE）
- 在同一事务中完成查询和更新
- 库存不足时返回错误，不执行扣减
- 扣减库存时同时增加 soldCount（已售数量）

### BR-PROD-006: 文件命名规则
- 上传文件使用 UUID + 原始扩展名重命名
- 避免文件名冲突和中文文件名问题

### BR-PROD-007: 产品名称允许重复
- 不同产品可以使用相同名称
- SKU 作为产品唯一标识码

### BR-PROD-008: 乐观锁版本控制
- 使用 version 字段实现乐观锁
- 更新产品时自动检查版本号，防止并发更新冲突

---

## 3. 错误码定义

### 产品错误码

| 错误码 | HTTP 状态码 | 场景 |
|--------|-----------|------|
| NOT_FOUND_001 | 404 | 产品不存在或已删除 |
| CONFLICT_001 | 409 | 库存不足 |
| BAD_REQUEST_001 | 400 | 参数校验失败 |

---

## 4. 统一响应格式

与 auth-service 保持一致：

```json
// 成功响应
{
  "code": "SUCCESS",
  "message": "操作成功",
  "data": { ... }
}

// 错误响应
{
  "code": "CONFLICT_001",
  "message": "库存不足",
  "data": null
}
```

---

## 5. 边界条件

| 场景 | 处理方式 |
|------|---------|
| 库存为 0 的产品 | 员工端正常展示，但前端应显示"已售罄" |
| 搜索关键词为空 | 返回所有 status = 0 且 deleted = 0 的产品 |
| 分类下无产品 | 返回空列表，前端显示"该分类暂无产品" |
| 上传同名文件 | UUID 重命名，不会覆盖 |
| 并发扣减库存 | 悲观锁保证串行，后到的请求可能因库存不足失败 |
| 删除已删除产品 | 已经是 deleted = 1 状态，返回 NOT_FOUND_001 |
| 分页 size 超过 100 | 强制限制为 100 |

---

## 6. 分页参数规则

| 参数 | 默认值 | 最小值 | 最大值 |
|------|--------|--------|--------|
| page | 0 | 0 | — |
| size | 20 | 1 | 100 |
