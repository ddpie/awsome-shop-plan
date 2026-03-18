# Unit 3: product-service — 业务逻辑模型

---

## 1. 创建产品流程

```
管理员 → POST /api/v1/admin/products (CreateProductRequest)
  │
  ├── 1. 参数校验
  │     ├── name: 非空，1-200位
  │     ├── sku: 非空，1-100位
  │     ├── category: 非空，1-100位
  │     ├── pointsPrice: 正数 ≥ 0.01
  │     └── stock: 非负整数 ≥ 0
  │
  ├── 2. 创建产品
  │     ├── status = 0（上架）
  │     ├── deleted = 0（未删除）
  │     ├── soldCount = 0
  │     ├── version = 0
  │     ├── createdBy = 当前用户ID（从请求头 X-Operator-Id 获取）
  │     └── 保存到 product_db.product
  │
  └── 3. 返回 ProductResponse
```

---

## 2. 更新产品流程

```
管理员 → PUT /api/v1/admin/products/{id} (UpdateProductRequest)
  │
  ├── 1. 查询产品
  │     └── 按 id 查询 → 不存在或已删除则返回 NOT_FOUND_001
  │
  ├── 2. 更新字段（仅更新非 null 字段）
  │     ├── name, subtitle, sku, category, brand, pointsPrice, marketPrice
  │     ├── stock, mainImage, images, description, deliveryMethod
  │     ├── serviceGuarantee, promotion, colors, specs
  │     ├── updatedBy = 当前用户ID（从请求头 X-Operator-Id 获取）
  │     └── 保存到 product_db.product（乐观锁自动处理 version）
  │
  └── 3. 返回更新后的 ProductResponse
```

---

## 3. 删除产品流程（软删除）

```
管理员 → DELETE /api/v1/admin/products/{id}
  │
  ├── 1. 查询产品
  │     └── 按 id 查询 → 不存在或已删除则返回 NOT_FOUND_001
  │
  ├── 2. 软删除
  │     ├── 将 status 设为 1（下架）
  │     ├── 将 deleted 设为 1（已删除）
  │     └── updatedBy = 当前用户ID
  │
  └── 3. 返回成功（HTTP 204）
```

说明：
- 采用软删除策略，产品数据保留但不再对员工展示
- 管理员产品列表可通过 status 筛选查看已下架产品
- 产品图片文件不删除（可能被兑换历史引用）

---

## 4. 员工浏览产品列表

```
员工 → GET /api/v1/products?page=0&size=20&category=数码产品&keyword=耳机
  │
  ├── 1. 分页参数处理
  │     ├── page: 默认 0，最小 0
  │     └── size: 默认 20，最小 1，最大 100
  │
  ├── 2. 构建查询条件
  │     ├── status = 0（仅展示上架产品）
  │     ├── deleted = 0（仅展示未删除产品）
  │     ├── category（可选）→ 精确匹配 category 字段
  │     └── keyword（可选）→ 模糊匹配 name 或 subtitle
  │
  ├── 3. 排序
  │     └── 按 created_at DESC（最新上架在前）
  │
  └── 4. 返回 PageResponse<ProductResponse>
```

---

## 5. 管理员产品列表

```
管理员 → GET /api/v1/admin/products?page=0&size=20&status=0
  │
  ├── 1. 分页参数处理（同员工端点）
  │
  ├── 2. 构建查询条件
  │     ├── deleted = 0（仅查未删除产品）
  │     ├── status（可选）→ 0=上架 / 1=下架 / 不传则查全部
  │     ├── category（可选）→ 精确匹配 category 字段
  │     └── keyword（可选）→ 模糊匹配 name 或 subtitle
  │
  ├── 3. 排序
  │     └── 按 created_at DESC
  │
  └── 4. 返回 PageResponse<ProductResponse>
```

---

## 6. 产品详情

```
员工 → GET /api/v1/products/{id}
  │
  ├── 1. 查询产品
  │     └── 按 id 查询，且 status = 0 且 deleted = 0 → 不存在则返回 NOT_FOUND_001
  │
  └── 2. 返回 ProductResponse
```

---

## 7. 文件上传流程

```
管理员 → POST /api/v1/files/upload (MultipartFile)
  │
  ├── 1. 文件校验
  │     ├── 文件非空
  │     ├── 文件大小 ≤ 5MB（MAX_FILE_SIZE 环境变量）
  │     └── 文件类型：仅允许 jpg, jpeg, png, gif, webp
  │
  ├── 2. 生成文件名
  │     └── UUID + 原始扩展名（如 a1b2c3d4.jpg）
  │
  ├── 3. 保存文件
  │     └── 保存到 UPLOAD_DIR 目录（Docker 卷挂载）
  │
  └── 4. 返回 FileResponse
        ├── url: /api/v1/files/{生成的文件名}
        └── filename: 生成的文件名
```

---

## 8. 文件访问流程

```
客户端 → GET /api/v1/files/{filename}
  │
  ├── 1. 查找文件
  │     └── 在 UPLOAD_DIR 目录中查找 → 不存在则返回 404
  │
  └── 2. 返回文件流
        ├── Content-Type: 根据扩展名自动推断
        └── Cache-Control: public, max-age=86400
```

---

## 9. 库存扣减流程（内部接口）

```
order-service → POST /api/v1/internal/products/deduct-stock (StockDeductRequest)
  │
  ├── 1. 查询产品（悲观锁）
  │     └── SELECT * FROM product WHERE id = ? FOR UPDATE
  │         └── 不存在或已删除则返回 NOT_FOUND_001
  │
  ├── 2. 库存校验
  │     └── stock < quantity → 返回 CONFLICT_001
  │
  ├── 3. 扣减库存并增加销量
  │     ├── UPDATE product SET stock = stock - ?, sold_count = sold_count + ? WHERE id = ?
  │     └── 更新 updatedBy 和 updatedAt
  │
  └── 4. 返回成功（HTTP 200）
```

### 悲观锁说明
- 使用 `SELECT ... FOR UPDATE` 锁定产品行
- 在同一事务中完成查询和更新，保证库存不会超卖
- 锁持有时间短（仅查询+更新），对并发影响小
- order-service 调用此接口时，应在自己的事务中处理

---

## 10. 库存恢复流程（内部接口）

```
order-service → POST /api/v1/internal/products/restore-stock (StockDeductRequest)
  │
  ├── 1. 查询产品
  │     └── 按 id 查询 → 不存在或已删除则返回 NOT_FOUND_001
  │
  ├── 2. 恢复库存并减少销量
  │     ├── UPDATE product SET stock = stock + ?, sold_count = sold_count - ? WHERE id = ?
  │     └── 更新 updatedBy 和 updatedAt
  │
  └── 3. 返回成功（HTTP 200）
```

说明：用于兑换失败时回滚库存。
