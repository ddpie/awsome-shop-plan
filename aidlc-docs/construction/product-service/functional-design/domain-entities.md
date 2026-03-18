# Unit 3: product-service — 领域实体与数据模型

---

## 1. 核心领域实体

### Product（产品）

| 属性 | 类型 | 说明 |
|------|------|------|
| id | Long | 产品唯一标识（自增主键） |
| name | String | 产品名称 |
| subtitle | String | 产品副标题（可选） |
| sku | String | 产品SKU编码 |
| category | String | 产品分类（字符串） |
| brand | String | 品牌（可选） |
| pointsPrice | BigDecimal | 所需积分 |
| marketPrice | BigDecimal | 市场价格（可选） |
| stock | Integer | 库存数量 |
| soldCount | Integer | 已售数量 |
| mainImage | String | 主图片 URL（可选） |
| images | String | 图片列表（JSON 字符串） |
| description | String | 产品描述（可选） |
| deliveryMethod | String | 配送方式（可选） |
| serviceGuarantee | String | 服务保障（可选） |
| promotion | String | 促销信息（可选） |
| colors | String | 颜色选项（可选） |
| specs | String | 规格参数（JSON 字符串） |
| status | Integer | 产品状态（0=上架，1=下架） |
| deleted | Integer | 删除标记（0=未删除，1=已删除） |
| version | Integer | 乐观锁版本号 |
| createdBy | String | 创建人 |
| updatedBy | String | 更新人 |
| createdAt | DateTime | 创建时间 |
| updatedAt | DateTime | 更新时间 |

### 状态定义

```
status:
  - 0: 上架中
  - 1: 已下架

deleted:
  - 0: 未删除
  - 1: 已删除
```

---

## 2. 请求模型（Request DTO）

### CreateProductRequest — 创建产品请求

| 字段 | 类型 | 必填 | 校验规则 |
|------|------|------|---------|
| name | String | 是 | 1-200位，非空 |
| subtitle | String | 否 | 最大 200 字符 |
| sku | String | 是 | 1-100位，非空 |
| category | String | 是 | 1-100位，非空 |
| brand | String | 否 | 最大 100 字符 |
| pointsPrice | BigDecimal | 是 | 正数，≥ 0.01 |
| marketPrice | BigDecimal | 否 | 正数，≥ 0.01 |
| stock | Integer | 是 | 非负整数，≥ 0 |
| mainImage | String | 否 | 最大 500 字符（由文件上传接口返回） |
| images | String | 否 | JSON 字符串，最大 2000 字符 |
| description | String | 否 | 最大 5000 字符 |
| deliveryMethod | String | 否 | 最大 200 字符 |
| serviceGuarantee | String | 否 | 最大 500 字符 |
| promotion | String | 否 | 最大 500 字符 |
| colors | String | 否 | 最大 200 字符 |
| specs | String | 否 | JSON 字符串，最大 2000 字符 |

### UpdateProductRequest — 更新产品请求

| 字段 | 类型 | 必填 | 校验规则 |
|------|------|------|---------|
| name | String | 否 | 1-200位 |
| subtitle | String | 否 | 最大 200 字符 |
| sku | String | 否 | 1-100位 |
| category | String | 否 | 1-100位 |
| brand | String | 否 | 最大 100 字符 |
| pointsPrice | BigDecimal | 否 | 正数，≥ 0.01 |
| marketPrice | BigDecimal | 否 | 正数，≥ 0.01 |
| stock | Integer | 否 | 非负整数，≥ 0 |
| mainImage | String | 否 | 最大 500 字符 |
| images | String | 否 | JSON 字符串，最大 2000 字符 |
| description | String | 否 | 最大 5000 字符 |
| deliveryMethod | String | 否 | 最大 200 字符 |
| serviceGuarantee | String | 否 | 最大 500 字符 |
| promotion | String | 否 | 最大 500 字符 |
| colors | String | 否 | 最大 200 字符 |
| specs | String | 否 | JSON 字符串，最大 2000 字符 |

### StockDeductRequest — 库存扣减请求（内部接口）

| 字段 | 类型 | 必填 | 校验规则 |
|------|------|------|---------|
| productId | Long | 是 | 必须为已存在的产品 ID |
| quantity | Int | 是 | 正整数，≥ 1 |

---

## 3. 响应模型（Response DTO）

### ProductResponse — 产品信息响应

| 字段 | 类型 | 说明 |
|------|------|------|
| id | Long | 产品 ID |
| name | String | 产品名称 |
| subtitle | String | 产品副标题 |
| sku | String | 产品SKU编码 |
| category | String | 产品分类 |
| brand | String | 品牌 |
| pointsPrice | BigDecimal | 所需积分 |
| marketPrice | BigDecimal | 市场价格 |
| stock | Integer | 库存数量 |
| soldCount | Integer | 已售数量 |
| mainImage | String | 主图片 URL |
| images | String | 图片列表（JSON 字符串） |
| description | String | 产品描述 |
| deliveryMethod | String | 配送方式 |
| serviceGuarantee | String | 服务保障 |
| promotion | String | 促销信息 |
| colors | String | 颜色选项 |
| specs | String | 规格参数（JSON 字符串） |
| status | Integer | 产品状态（0=上架，1=下架） |
| createdAt | String | 创建时间（ISO 8601） |
| updatedAt | String | 更新时间（ISO 8601） |

### FileResponse — 文件上传响应

| 字段 | 类型 | 说明 |
|------|------|------|
| url | String | 文件访问 URL |
| filename | String | 文件名 |

### PageResponse\<T\> — 分页响应

| 字段 | 类型 | 说明 |
|------|------|------|
| content | List\<T\> | 数据列表 |
| totalElements | Long | 总记录数 |
| totalPages | Int | 总页数 |
| currentPage | Int | 当前页码 |

---

## 4. API 端点定义

### 员工端点（需认证）

| 方法 | 路径 | 请求体 | 响应体 | 说明 |
|------|------|--------|--------|------|
| GET | /api/v1/products | — | PageResponse\<ProductResponse\> | 产品列表（分页、搜索、分类筛选） |
| GET | /api/v1/products/{id} | — | ProductResponse | 产品详情 |

查询参数（产品列表）：
- `page`: 页码（默认 0）
- `size`: 每页数量（默认 20）
- `category`: 分类名称（可选，筛选该分类下的产品）
- `keyword`: 搜索关键词（匹配产品名称）

### 管理员端点（需管理员角色）

| 方法 | 路径 | 请求体 | 响应体 | 说明 |
|------|------|--------|--------|------|
| POST | /api/v1/admin/products | CreateProductRequest | ProductResponse | 创建产品 |
| PUT | /api/v1/admin/products/{id} | UpdateProductRequest | ProductResponse | 更新产品 |
| DELETE | /api/v1/admin/products/{id} | — | void | 删除产品（软删除） |
| GET | /api/v1/admin/products | — | PageResponse\<ProductResponse\> | 管理员产品列表（含已下架） |

管理员产品列表查询参数：
- `page`, `size`, `category`, `keyword`（同员工端点）
- `status`: 产品状态筛选（0=上架 / 1=下架 / 全部）

### 文件端点（需认证）

| 方法 | 路径 | 请求体 | 响应体 | 说明 |
|------|------|--------|--------|------|
| POST | /api/v1/files/upload | MultipartFile | FileResponse | 上传图片 |
| GET | /api/v1/files/{filename} | — | 文件流 | 获取图片 |

### 内部端点（服务间调用，不经过 API 网关）

| 方法 | 路径 | 请求体 | 响应体 | 说明 |
|------|------|--------|--------|------|
| GET | /api/v1/internal/products/{id} | — | ProductResponse | 获取产品信息（含库存） |
| POST | /api/v1/internal/products/deduct-stock | StockDeductRequest | void | 扣减库存（悲观锁） |
| POST | /api/v1/internal/products/restore-stock | StockDeductRequest | void | 恢复库存（回滚用） |
