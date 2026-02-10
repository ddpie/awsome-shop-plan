# Unit 3: product-service — 业务逻辑模型

---

## 1. 创建产品流程

```
管理员 → POST /api/admin/products (CreateProductRequest)
  │
  ├── 1. 参数校验
  │     ├── name: 非空，1-200位
  │     ├── pointsPrice: 正整数 ≥ 1
  │     ├── stock: 非负整数 ≥ 0
  │     └── categoryId: 非空
  │
  ├── 2. 分类存在性校验
  │     └── 按 categoryId 查询分类 → 不存在则返回 PROD_001
  │
  ├── 3. 创建产品
  │     ├── status = ACTIVE
  │     └── 保存到 product_db.products
  │
  └── 4. 返回 ProductResponse（含 categoryName）
```

---

## 2. 更新产品流程

```
管理员 → PUT /api/admin/products/{id} (UpdateProductRequest)
  │
  ├── 1. 查询产品
  │     └── 按 id 查询 → 不存在则返回 PROD_002
  │
  ├── 2. 分类存在性校验（如果提供了 categoryId）
  │     └── 按 categoryId 查询分类 → 不存在则返回 PROD_001
  │
  ├── 3. 更新字段（仅更新非 null 字段）
  │     ├── name, description, pointsPrice, stock, imageUrl, categoryId
  │     └── 保存到 product_db.products
  │
  └── 4. 返回更新后的 ProductResponse
```

---

## 3. 删除产品流程（软删除）

```
管理员 → DELETE /api/admin/products/{id}
  │
  ├── 1. 查询产品
  │     └── 按 id 查询 → 不存在则返回 PROD_002
  │
  ├── 2. 软删除
  │     └── 将 status 设为 INACTIVE
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
员工 → GET /api/products?page=0&size=20&categoryId=1&keyword=耳机
  │
  ├── 1. 分页参数处理
  │     ├── page: 默认 0，最小 0
  │     └── size: 默认 20，最小 1，最大 100
  │
  ├── 2. 构建查询条件
  │     ├── status = ACTIVE（仅展示上架产品）
  │     ├── categoryId（可选）→ 筛选该分类及其子分类下的产品
  │     │     └── 如果 categoryId 是一级分类，查询该分类 + 所有二级子分类的产品
  │     └── keyword（可选）→ 模糊匹配 name
  │
  ├── 3. 排序
  │     └── 按 created_at DESC（最新上架在前）
  │
  └── 4. 返回 PageResponse<ProductResponse>
        └── 每个 ProductResponse 包含 categoryName
```

### 分类筛选逻辑
- 如果 `categoryId` 指向一级分类：查询该一级分类 + 其所有二级子分类下的产品
- 如果 `categoryId` 指向二级分类：仅查询该二级分类下的产品
- 如果不传 `categoryId`：查询所有 ACTIVE 产品

---

## 5. 管理员产品列表

```
管理员 → GET /api/admin/products?page=0&size=20&status=ACTIVE
  │
  ├── 1. 分页参数处理（同员工端点）
  │
  ├── 2. 构建查询条件
  │     ├── status（可选）→ ACTIVE / INACTIVE / 不传则查全部
  │     ├── categoryId（可选）→ 同员工端点逻辑
  │     └── keyword（可选）→ 模糊匹配 name
  │
  ├── 3. 排序
  │     └── 按 created_at DESC
  │
  └── 4. 返回 PageResponse<ProductResponse>
```

---

## 6. 产品详情

```
员工 → GET /api/products/{id}
  │
  ├── 1. 查询产品
  │     └── 按 id 查询，且 status = ACTIVE → 不存在则返回 PROD_002
  │
  └── 2. 返回 ProductResponse（含 categoryName）
```

---

## 7. 分类树查询

```
员工 → GET /api/categories/tree
  │
  ├── 1. 查询所有分类
  │     └── SELECT * FROM categories ORDER BY sort_order ASC, id ASC
  │
  ├── 2. 构建树结构
  │     ├── 筛选 parentId = NULL 的为一级分类
  │     └── 将 parentId 非 NULL 的挂载到对应父分类的 children 列表
  │
  └── 3. 返回 List<CategoryTreeNode>
```

---

## 8. 创建分类流程

```
管理员 → POST /api/admin/categories (CreateCategoryRequest)
  │
  ├── 1. 参数校验
  │     └── name: 非空，1-100位
  │
  ├── 2. 层级校验
  │     ├── parentId = NULL → 创建一级分类（允许）
  │     ├── parentId 非 NULL → 查询父分类
  │     │     ├── 父分类不存在 → 返回 CAT_001
  │     │     ├── 父分类是一级分类（parentId = NULL）→ 创建二级分类（允许）
  │     │     └── 父分类是二级分类（parentId 非 NULL）→ 返回 CAT_002（超过2级限制）
  │
  ├── 3. 创建分类
  │     └── 保存到 product_db.categories
  │
  └── 4. 返回 CategoryResponse
```

---

## 9. 更新分类流程

```
管理员 → PUT /api/admin/categories/{id} (UpdateCategoryRequest)
  │
  ├── 1. 查询分类
  │     └── 按 id 查询 → 不存在则返回 CAT_001
  │
  ├── 2. 层级校验（如果修改了 parentId）
  │     ├── 不允许将一级分类移动到另一个分类下（如果该分类有子分类）
  │     └── 不允许创建超过 2 级的嵌套
  │
  ├── 3. 更新字段（仅更新非 null 字段）
  │     ├── name, parentId, sortOrder
  │     └── 保存到 product_db.categories
  │
  └── 4. 返回更新后的 CategoryResponse
```

---

## 10. 删除分类流程

```
管理员 → DELETE /api/admin/categories/{id}
  │
  ├── 1. 查询分类
  │     └── 按 id 查询 → 不存在则返回 CAT_001
  │
  ├── 2. 子分类检查
  │     └── 查询是否有子分类 → 有则返回 CAT_003
  │
  ├── 3. 关联产品检查
  │     └── 查询该分类下是否有 ACTIVE 产品 → 有则返回 CAT_004
  │
  ├── 4. 删除分类（物理删除）
  │     └── DELETE FROM categories WHERE id = ?
  │
  └── 5. 返回成功（HTTP 204）
```

---

## 11. 文件上传流程

```
管理员 → POST /api/files/upload (MultipartFile)
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
        ├── url: /api/files/{生成的文件名}
        └── filename: 生成的文件名
```

---

## 12. 文件访问流程

```
客户端 → GET /api/files/{filename}
  │
  ├── 1. 查找文件
  │     └── 在 UPLOAD_DIR 目录中查找 → 不存在则返回 404
  │
  └── 2. 返回文件流
        ├── Content-Type: 根据扩展名自动推断
        └── Cache-Control: public, max-age=86400
```

---

## 13. 库存扣减流程（内部接口）

```
order-service → POST /api/internal/products/deduct-stock (StockDeductRequest)
  │
  ├── 1. 查询产品（悲观锁）
  │     └── SELECT * FROM products WHERE id = ? FOR UPDATE
  │         └── 不存在则返回 PROD_002
  │
  ├── 2. 库存校验
  │     └── stock < quantity → 返回 PROD_003
  │
  ├── 3. 扣减库存
  │     └── UPDATE products SET stock = stock - ? WHERE id = ?
  │
  └── 4. 返回成功（HTTP 200）
```

### 悲观锁说明
- 使用 `SELECT ... FOR UPDATE` 锁定产品行
- 在同一事务中完成查询和更新，保证库存不会超卖
- 锁持有时间短（仅查询+更新），对并发影响小
- order-service 调用此接口时，应在自己的事务中处理

---

## 14. 库存恢复流程（内部接口）

```
order-service → POST /api/internal/products/restore-stock (StockDeductRequest)
  │
  ├── 1. 查询产品
  │     └── 按 id 查询 → 不存在则返回 PROD_002
  │
  ├── 2. 恢复库存
  │     └── UPDATE products SET stock = stock + ? WHERE id = ?
  │
  └── 3. 返回成功（HTTP 200）
```

说明：用于兑换失败时回滚库存。
