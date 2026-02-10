# Unit 3: product-service — NFR 设计模式

---

## 1. 文件上传安全模式

### 模式：白名单校验 + UUID 重命名 + 大小限制

```
上传流程:
  客户端文件 → 大小校验(≤5MB) → 扩展名白名单校验 → UUID重命名 → 保存到卷挂载目录

安全防线:
  第1层: 文件大小限制（5MB）— 防止大文件攻击
  第2层: 扩展名白名单（jpg/jpeg/png/gif/webp）— 仅允许图片
  第3层: UUID 重命名 — 防止路径遍历和文件名冲突
  第4层: 存储目录隔离 — Docker 卷挂载，与应用代码分离
```

设计要点：
- 不信任客户端提供的 Content-Type，根据文件扩展名判断类型
- UUID 格式：`{uuid}.{ext}`（如 `a1b2c3d4-e5f6-7890-abcd-ef1234567890.jpg`）
- 存储路径通过 UPLOAD_DIR 环境变量配置，默认 `/app/uploads`
- Docker 卷挂载到宿主机，容器重启不丢失文件

---

## 2. 悲观锁库存控制模式

### 模式：SELECT FOR UPDATE + 事务内原子操作

```
库存扣减流程:
  BEGIN TRANSACTION
    ├── SELECT * FROM products WHERE id = ? FOR UPDATE  (行锁)
    ├── 校验: stock >= quantity
    │     ├── 是 → UPDATE products SET stock = stock - ? WHERE id = ?
    │     └── 否 → ROLLBACK, 返回 PROD_003
    └── COMMIT

并发场景:
  请求A: SELECT FOR UPDATE → 获得锁 → 扣减 → COMMIT → 释放锁
  请求B: SELECT FOR UPDATE → 等待锁(最长5秒) → 获得锁 → 扣减/失败
  请求C: SELECT FOR UPDATE → 等待超时(5秒) → 快速失败
```

设计要点：
- 锁等待超时：5 秒，超时后返回错误提示用户重试
- 锁粒度：行级锁，仅锁定目标产品行，不影响其他产品操作
- 事务范围最小化：仅包含查询和更新两步操作
- 库存恢复（restore-stock）不使用悲观锁，直接 `stock + quantity`（无超卖风险）

---

## 3. 统一错误处理模式

### 模式：错误码前缀分类 + 统一响应格式

```json
// 成功响应
{
  "code": "SUCCESS",
  "message": "操作成功",
  "data": { ... }
}

// 错误响应
{
  "code": "PROD_003",
  "message": "库存不足",
  "data": null
}
```

错误码前缀分类：

| 前缀 | 模块 | 示例 |
|------|------|------|
| PROD_ | 产品模块 | PROD_001(分类不存在)、PROD_002(产品不存在)、PROD_003(库存不足)、PROD_004(参数校验) |
| CAT_ | 分类模块 | CAT_001(分类不存在)、CAT_002(层级超限)、CAT_003(有子分类)、CAT_004(有产品)、CAT_005(参数校验) |
| FILE_ | 文件模块 | FILE_001(文件为空)、FILE_002(大小超限)、FILE_003(类型不支持) |

设计要点：
- 全局异常处理器捕获业务异常，转换为统一格式
- 未预期异常返回 500 + 通用错误信息，不暴露内部细节
- 与 auth-service 保持相同的响应格式规范

---

## 4. 分层输入校验模式

### 模式：框架层 + 业务层 + 数据库层

```
第1层：框架层参数校验（注解/装饰器）
  ├── 非空校验（name, pointsPrice, stock, categoryId）
  ├── 长度校验（name ≤ 200, description ≤ 5000）
  ├── 范围校验（pointsPrice ≥ 1, stock ≥ 0）
  └── 文件校验（大小 ≤ 5MB, 类型白名单）

第2层：业务层逻辑校验
  ├── 存在性校验（分类是否存在、产品是否存在）
  ├── 层级校验（分类深度不超过2级）
  ├── 前置条件校验（删除分类前检查子分类和产品）
  └── 库存校验（扣减前检查库存是否充足）

第3层：数据库层约束兜底
  ├── NOT NULL 约束
  ├── FOREIGN KEY 约束（categoryId → categories.id）
  └── CHECK 约束（stock ≥ 0）
```

设计要点：
- 尽早失败：框架层校验在进入业务逻辑前拦截无效请求
- 分页参数强制限制：size 最大 100，防止大查询
- 数据库约束作为最后防线，处理并发场景下的边界情况

---

## 5. 图片缓存模式

### 模式：HTTP Cache-Control + Nginx 缓存

```
图片访问流程:
  客户端 → Nginx → api-gateway → product-service → 文件系统
                                       │
                                       ▼
                              响应头: Cache-Control: public, max-age=86400
                              Content-Type: image/jpeg (根据扩展名推断)

缓存层级:
  第1层: 浏览器缓存（Cache-Control: max-age=86400，24小时）
  第2层: Nginx 缓存（可选，未来扩展）
```

设计要点：
- 图片文件通过 HTTP 直接返回文件流，不做 Base64 编码
- Cache-Control 设置 24 小时缓存，减少重复请求
- UUID 文件名天然支持缓存失效（新图片 = 新 URL）
- Content-Type 根据文件扩展名自动推断

---

## 6. 分类树查询模式

### 模式：全量查询 + 内存组装

```
查询流程:
  SELECT * FROM categories ORDER BY sort_order ASC, id ASC
    │
    ├── 筛选 parentId = NULL → 一级分类列表
    ├── 按 parentId 分组 → Map<parentId, List<Category>>
    └── 遍历一级分类，挂载对应的二级子分类 → 树结构

性能说明:
  - 分类总数有限（预计 < 100），全量查询性能可接受
  - 单次 SQL 查询，内存中组装树结构
  - 无需递归查询或多次 SQL
```

设计要点：
- 最大 2 级分类，树结构简单，无需复杂的递归算法
- 排序规则：先按 sort_order ASC，再按 id ASC
- 分类数据变更频率低，未来可考虑缓存优化（MVP 阶段不需要）

---

## 7. 内部接口隔离模式

### 模式：Docker 网络隔离 + 路径前缀区分

```
外部请求路径（经过 API 网关）:
  客户端 → Nginx → api-gateway → product-service
                    (JWT校验)     (/api/products/*, /api/admin/products/*)

内部请求路径（不经过 API 网关）:
  order-service → product-service
                  (/api/internal/products/*)

隔离机制:
  - /api/internal/* 路径不在 api-gateway 路由表中
  - 仅 Docker 内部网络可访问
  - Nginx 不转发 /api/internal/* 请求
```

设计要点：
- 内部接口通过 Docker DNS 直接调用：`http://product-service:{port}/api/internal/...`
- 无需认证令牌，信任 Docker 内部网络
- 路径前缀 `/api/internal/` 明确标识内部接口
- 三个内部端点：查询产品信息、库存扣减、库存恢复
