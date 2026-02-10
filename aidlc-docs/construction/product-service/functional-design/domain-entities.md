# Unit 3: product-service — 领域实体与数据模型

---

## 1. 核心领域实体

### Product（产品）

| 属性 | 类型 | 说明 |
|------|------|------|
| id | Long | 产品唯一标识（自增主键） |
| name | String | 产品名称 |
| description | String | 产品描述（可选） |
| pointsPrice | Int | 所需积分 |
| stock | Int | 库存数量 |
| imageUrl | String | 产品图片 URL（可选） |
| categoryId | Long | 所属分类 ID |
| status | ProductStatus | 产品状态枚举 |
| createdAt | DateTime | 创建时间 |
| updatedAt | DateTime | 更新时间 |

### Category（分类）

| 属性 | 类型 | 说明 |
|------|------|------|
| id | Long | 分类唯一标识（自增主键） |
| name | String | 分类名称 |
| parentId | Long | 父分类 ID（NULL 为顶级分类） |
| sortOrder | Int | 排序序号 |
| createdAt | DateTime | 创建时间 |
| updatedAt | DateTime | 更新时间 |

### 枚举定义

```
ProductStatus:
  - ACTIVE      # 上架中
  - INACTIVE    # 已下架（软删除）
```

### 分类层级规则
- 最大层级深度：2 级（一级分类 + 二级分类）
- parentId = NULL → 一级分类
- parentId = 一级分类ID → 二级分类
- 不允许创建三级及更深层级的分类

---

## 2. 请求模型（Request DTO）

### CreateProductRequest — 创建产品请求

| 字段 | 类型 | 必填 | 校验规则 |
|------|------|------|---------|
| name | String | 是 | 1-200位，非空 |
| description | String | 否 | 最大 5000 字符 |
| pointsPrice | Int | 是 | 正整数，≥ 1 |
| stock | Int | 是 | 非负整数，≥ 0 |
| imageUrl | String | 否 | 最大 500 字符（由文件上传接口返回） |
| categoryId | Long | 是 | 必须为已存在的分类 ID |

### UpdateProductRequest — 更新产品请求

| 字段 | 类型 | 必填 | 校验规则 |
|------|------|------|---------|
| name | String | 否 | 1-200位 |
| description | String | 否 | 最大 5000 字符 |
| pointsPrice | Int | 否 | 正整数，≥ 1 |
| stock | Int | 否 | 非负整数，≥ 0 |
| imageUrl | String | 否 | 最大 500 字符 |
| categoryId | Long | 否 | 必须为已存在的分类 ID |

### CreateCategoryRequest — 创建分类请求

| 字段 | 类型 | 必填 | 校验规则 |
|------|------|------|---------|
| name | String | 是 | 1-100位，非空 |
| parentId | Long | 否 | NULL 为顶级分类，非 NULL 必须为已存在的一级分类 ID |
| sortOrder | Int | 否 | 默认 0 |

### UpdateCategoryRequest — 更新分类请求

| 字段 | 类型 | 必填 | 校验规则 |
|------|------|------|---------|
| name | String | 否 | 1-100位 |
| parentId | Long | 否 | NULL 或已存在的一级分类 ID |
| sortOrder | Int | 否 | 非负整数 |

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
| description | String | 产品描述 |
| pointsPrice | Int | 所需积分 |
| stock | Int | 库存数量 |
| imageUrl | String | 产品图片 URL |
| categoryId | Long | 分类 ID |
| categoryName | String | 分类名称（冗余，方便前端展示） |
| status | String | 产品状态 |
| createdAt | String | 创建时间（ISO 8601） |

### CategoryResponse — 分类信息响应

| 字段 | 类型 | 说明 |
|------|------|------|
| id | Long | 分类 ID |
| name | String | 分类名称 |
| parentId | Long | 父分类 ID |
| sortOrder | Int | 排序序号 |

### CategoryTreeNode — 分类树节点

| 字段 | 类型 | 说明 |
|------|------|------|
| id | Long | 分类 ID |
| name | String | 分类名称 |
| sortOrder | Int | 排序序号 |
| children | List\<CategoryTreeNode\> | 子分类列表 |

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
| GET | /api/products | — | PageResponse\<ProductResponse\> | 产品列表（分页、搜索、分类筛选） |
| GET | /api/products/{id} | — | ProductResponse | 产品详情 |
| GET | /api/categories/tree | — | List\<CategoryTreeNode\> | 分类树 |

查询参数（产品列表）：
- `page`: 页码（默认 0）
- `size`: 每页数量（默认 20）
- `categoryId`: 分类 ID（可选，筛选该分类及其子分类下的产品）
- `keyword`: 搜索关键词（匹配产品名称）

### 管理员端点（需管理员角色）

| 方法 | 路径 | 请求体 | 响应体 | 说明 |
|------|------|--------|--------|------|
| POST | /api/admin/products | CreateProductRequest | ProductResponse | 创建产品 |
| PUT | /api/admin/products/{id} | UpdateProductRequest | ProductResponse | 更新产品 |
| DELETE | /api/admin/products/{id} | — | void | 删除产品（软删除） |
| GET | /api/admin/products | — | PageResponse\<ProductResponse\> | 管理员产品列表（含 INACTIVE） |
| POST | /api/admin/categories | CreateCategoryRequest | CategoryResponse | 创建分类 |
| PUT | /api/admin/categories/{id} | UpdateCategoryRequest | CategoryResponse | 更新分类 |
| DELETE | /api/admin/categories/{id} | — | void | 删除分类 |

管理员产品列表查询参数：
- `page`, `size`, `categoryId`, `keyword`（同员工端点）
- `status`: 产品状态筛选（ACTIVE / INACTIVE / 全部）

### 文件端点（需认证）

| 方法 | 路径 | 请求体 | 响应体 | 说明 |
|------|------|--------|--------|------|
| POST | /api/files/upload | MultipartFile | FileResponse | 上传图片 |
| GET | /api/files/{filename} | — | 文件流 | 获取图片 |

### 内部端点（服务间调用，不经过 API 网关）

| 方法 | 路径 | 请求体 | 响应体 | 说明 |
|------|------|--------|--------|------|
| GET | /api/internal/products/{id} | — | ProductResponse | 获取产品信息（含库存） |
| POST | /api/internal/products/deduct-stock | StockDeductRequest | void | 扣减库存（悲观锁） |
| POST | /api/internal/products/restore-stock | StockDeductRequest | void | 恢复库存（回滚用） |
