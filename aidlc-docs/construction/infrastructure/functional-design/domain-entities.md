# Unit 7: infrastructure — 数据库 Schema 设计

## 数据库隔离策略

同一个 MySQL 实例，每个微服务使用独立的 database：

| Database | 所属服务 | 数据表 |
|----------|---------|--------|
| auth_db | auth-service | users |
| product_db | product-service | products, categories |
| points_db | points-service | point_balances, point_transactions, system_configs, distribution_batches |
| order_db | order-service | orders |

---

## auth_db

### users 表

| 字段 | 类型 | 约束 | 说明 |
|------|------|------|------|
| id | BIGINT | PK, AUTO_INCREMENT | 用户ID |
| username | VARCHAR(50) | UNIQUE, NOT NULL | 用户名 |
| password | VARCHAR(255) | NOT NULL | 密码（bcrypt 加密） |
| name | VARCHAR(100) | NOT NULL | 姓名 |
| employee_id | VARCHAR(50) | UNIQUE, NOT NULL | 工号 |
| role | ENUM('EMPLOYEE','ADMIN') | NOT NULL, DEFAULT 'EMPLOYEE' | 角色 |
| status | ENUM('ACTIVE','DISABLED') | NOT NULL, DEFAULT 'ACTIVE' | 账号状态 |
| created_at | DATETIME | NOT NULL, DEFAULT CURRENT_TIMESTAMP | 创建时间 |
| updated_at | DATETIME | NOT NULL, DEFAULT CURRENT_TIMESTAMP ON UPDATE | 更新时间 |

索引：
- `idx_users_username` ON (username)
- `idx_users_employee_id` ON (employee_id)

---

## product_db

### categories 表

| 字段 | 类型 | 约束 | 说明 |
|------|------|------|------|
| id | BIGINT | PK, AUTO_INCREMENT | 分类ID |
| name | VARCHAR(100) | NOT NULL | 分类名称 |
| parent_id | BIGINT | NULL, FK → categories(id) | 父分类ID（NULL 为顶级） |
| sort_order | INT | NOT NULL, DEFAULT 0 | 排序序号 |
| created_at | DATETIME | NOT NULL, DEFAULT CURRENT_TIMESTAMP | 创建时间 |
| updated_at | DATETIME | NOT NULL, DEFAULT CURRENT_TIMESTAMP ON UPDATE | 更新时间 |

索引：
- `idx_categories_parent_id` ON (parent_id)

### products 表

| 字段 | 类型 | 约束 | 说明 |
|------|------|------|------|
| id | BIGINT | PK, AUTO_INCREMENT | 产品ID |
| name | VARCHAR(200) | NOT NULL | 产品名称 |
| description | TEXT | NULL | 产品描述 |
| points_price | INT | NOT NULL | 所需积分 |
| stock | INT | NOT NULL, DEFAULT 0 | 库存数量 |
| image_url | VARCHAR(500) | NULL | 产品图片URL |
| category_id | BIGINT | NOT NULL, FK → categories(id) | 所属分类 |
| status | ENUM('ACTIVE','INACTIVE') | NOT NULL, DEFAULT 'ACTIVE' | 产品状态 |
| created_at | DATETIME | NOT NULL, DEFAULT CURRENT_TIMESTAMP | 创建时间 |
| updated_at | DATETIME | NOT NULL, DEFAULT CURRENT_TIMESTAMP ON UPDATE | 更新时间 |

索引：
- `idx_products_category_id` ON (category_id)
- `idx_products_name` ON (name)
- `idx_products_status` ON (status)

---

## points_db

### point_balances 表

| 字段 | 类型 | 约束 | 说明 |
|------|------|------|------|
| id | BIGINT | PK, AUTO_INCREMENT | 记录ID |
| user_id | BIGINT | UNIQUE, NOT NULL | 用户ID（逻辑关联 auth_db.users） |
| balance | INT | NOT NULL, DEFAULT 0 | 当前积分余额 |
| created_at | DATETIME | NOT NULL, DEFAULT CURRENT_TIMESTAMP | 创建时间 |
| updated_at | DATETIME | NOT NULL, DEFAULT CURRENT_TIMESTAMP ON UPDATE | 更新时间 |

索引：
- `idx_point_balances_user_id` ON (user_id)

### point_transactions 表

| 字段 | 类型 | 约束 | 说明 |
|------|------|------|------|
| id | BIGINT | PK, AUTO_INCREMENT | 流水ID |
| user_id | BIGINT | NOT NULL | 用户ID |
| type | ENUM('DISTRIBUTION','MANUAL_ADD','MANUAL_DEDUCT','REDEMPTION','ROLLBACK') | NOT NULL | 变动类型 |
| amount | INT | NOT NULL | 变动数量（正数增加，负数减少） |
| balance_after | INT | NOT NULL | 变动后余额 |
| reference_id | BIGINT | NULL | 关联ID（兑换订单ID等） |
| operator_id | BIGINT | NULL | 操作人ID（手动调整时） |
| remark | VARCHAR(500) | NULL | 备注 |
| created_at | DATETIME | NOT NULL, DEFAULT CURRENT_TIMESTAMP | 创建时间 |

索引：
- `idx_point_transactions_user_id` ON (user_id)
- `idx_point_transactions_type` ON (type)
- `idx_point_transactions_created_at` ON (created_at)

### system_configs 表

| 字段 | 类型 | 约束 | 说明 |
|------|------|------|------|
| id | BIGINT | PK, AUTO_INCREMENT | 配置ID |
| config_key | VARCHAR(100) | UNIQUE, NOT NULL | 配置键 |
| config_value | VARCHAR(500) | NOT NULL | 配置值 |
| description | VARCHAR(200) | NULL | 配置说明 |
| updated_at | DATETIME | NOT NULL, DEFAULT CURRENT_TIMESTAMP ON UPDATE | 更新时间 |

### distribution_batches 表

| 字段 | 类型 | 约束 | 说明 |
|------|------|------|------|
| id | BIGINT | PK, AUTO_INCREMENT | 批次ID |
| distribution_amount | INT | NOT NULL | 本次发放额度 |
| total_count | INT | NOT NULL, DEFAULT 0 | 应发放总人数 |
| success_count | INT | NOT NULL, DEFAULT 0 | 成功发放人数 |
| fail_count | INT | NOT NULL, DEFAULT 0 | 失败人数 |
| status | ENUM('RUNNING','COMPLETED','FAILED') | NOT NULL, DEFAULT 'RUNNING' | 批次状态 |
| started_at | DATETIME | NOT NULL, DEFAULT CURRENT_TIMESTAMP | 开始时间 |
| completed_at | DATETIME | NULL | 完成时间 |

索引：
- `idx_distribution_batches_status` ON (status)
- `idx_distribution_batches_started_at` ON (started_at)

---

## order_db

### orders 表

| 字段 | 类型 | 约束 | 说明 |
|------|------|------|------|
| id | BIGINT | PK, AUTO_INCREMENT | 订单ID |
| user_id | BIGINT | NOT NULL | 用户ID |
| product_id | BIGINT | NOT NULL | 产品ID |
| product_name | VARCHAR(200) | NOT NULL | 产品名称（冗余快照） |
| product_image_url | VARCHAR(500) | NULL | 产品图片（冗余快照） |
| points_cost | INT | NOT NULL | 消耗积分 |
| points_transaction_id | BIGINT | NULL | 积分扣除流水ID（取消时用于回滚） |
| status | ENUM('PENDING','READY','COMPLETED','CANCELLED') | NOT NULL, DEFAULT 'PENDING' | 兑换状态 |
| created_at | DATETIME | NOT NULL, DEFAULT CURRENT_TIMESTAMP | 创建时间 |
| updated_at | DATETIME | NOT NULL, DEFAULT CURRENT_TIMESTAMP ON UPDATE | 更新时间 |

索引：
- `idx_orders_user_id` ON (user_id)
- `idx_orders_status` ON (status)
- `idx_orders_created_at` ON (created_at)

---

## 跨库关联说明

由于采用独立 database 策略，跨服务数据关联通过逻辑 ID 引用（非物理外键）：

| 引用方 | 字段 | 引用目标 | 说明 |
|--------|------|---------|------|
| points_db.point_balances | user_id | auth_db.users.id | 积分余额关联用户 |
| points_db.point_transactions | user_id | auth_db.users.id | 积分流水关联用户 |
| points_db.point_transactions | operator_id | auth_db.users.id | 操作人 |
| points_db.point_transactions | reference_id | order_db.orders.id | 兑换扣分关联订单 |
| order_db.orders | user_id | auth_db.users.id | 订单关联用户 |
| order_db.orders | product_id | product_db.products.id | 订单关联产品 |
