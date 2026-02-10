# Unit 3: product-service — 功能设计计划

---

## 前置条件
- [x] 应用设计已完成（组件、方法、服务定义）
- [x] 用户故事已完成（US-004~US-007, US-013~US-016, US-017~US-019）
- [x] Unit 7 数据库 Schema 已定义（product_db: products, categories）

---

## 设计问题

> 以下问题用于确认 product-service 特有的功能设计细节。
> 数据库表结构已在 Unit 7 中定义，本阶段聚焦于业务逻辑和 API 行为。

### Q1: 产品图片处理方式

需求文档中提到"产品图片使用 URL 引用"，但应用设计中有 BE-FILE 文件组件（上传/访问/删除）。请确认图片处理方式：

- A) 仅 URL 引用 — 管理员在创建/编辑产品时直接填写图片 URL，不涉及文件上传
- B) 文件上传 — 管理员上传图片到本地文件系统，系统返回访问 URL 存入 products.image_url
- C) 两者兼容 — 支持直接填写 URL，也支持上传图片

[Answer]:B

### Q2: 产品删除策略

删除产品时，如果该产品已有历史兑换记录（order_db.orders 中有引用），如何处理？

- A) 软删除 — 将 products.status 设为 INACTIVE，产品不再展示但数据保留
- B) 物理删除 — 直接删除记录（orders 表已冗余了 product_name 和 product_image_url）
- C) 条件删除 — 无兑换记录时物理删除，有兑换记录时软删除

[Answer]:A

### Q3: 分类层级限制

多级分类的最大层级深度是多少？

- A) 不限制 — 允许任意深度的分类嵌套
- B) 限制 2 级 — 最多一级分类 + 二级分类（与用户故事 US-004 面包屑一致）
- C) 限制 3 级 — 最多三级分类

[Answer]:B

### Q4: 产品列表默认排序

员工浏览产品列表时的默认排序规则：

- A) 按创建时间倒序 — 最新上架的产品排在前面（与 US-007 验收标准一致）
- B) 按分类排序 + 创建时间倒序 — 先按分类分组，组内按时间排序
- C) 按积分价格升序 — 便宜的排在前面

[Answer]:A

### Q5: 库存扣减并发控制

兑换时扣减库存的并发控制策略（order-service 会调用 product-service 的库存接口）：

- A) 乐观锁 — 使用版本号或 WHERE stock >= quantity 条件更新，失败则提示重试
- B) 悲观锁 — SELECT FOR UPDATE 锁定行，保证串行执行
- C) 不做特殊处理 — MVP 阶段并发量低，依赖数据库默认隔离级别

[Answer]:B

---

## 执行步骤

- [ ] 收集用户回答
- [ ] 分析回答，确认无歧义
- [ ] 生成 domain-entities.md（领域实体、请求/响应 DTO、API 端点定义）
- [ ] 生成 business-logic-model.md（业务流程详细设计）
- [ ] 生成 business-rules.md（校验规则、业务规则、错误码）
- [ ] 提交用户审批
