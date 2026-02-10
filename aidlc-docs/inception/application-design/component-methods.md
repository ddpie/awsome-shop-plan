# AWSomeShop 组件方法定义

> 注：此处定义方法签名和高层用途。详细业务规则将在构建阶段的功能设计中定义。
> 后端架构分层将在实现阶段根据用户提供的框架确定。

---

## 后端组件方法

### BE-AUTH: 认证组件

| 方法 | 输入 | 输出 | 用途 |
|------|------|------|------|
| register | RegisterRequest(username, password, name, employeeId) | UserResponse | 注册新用户 |
| login | LoginRequest(username, password) | TokenResponse(token, role) | 用户登录，返回JWT |
| logout | token: String | void | 用户退出，令牌失效 |
| validateToken | token: String | UserInfo | 校验令牌有效性 |

### BE-USER: 用户组件

| 方法 | 输入 | 输出 | 用途 |
|------|------|------|------|
| getUserById | userId: Long | UserResponse | 获取用户信息 |
| getUserByUsername | username: String | UserResponse | 按用户名查询 |
| listUsers | page: Int, size: Int, keyword: String? | PageResponse\<UserResponse\> | 分页查询用户列表 |
| updateUser | userId: Long, UpdateUserRequest | UserResponse | 更新用户信息 |

### BE-PRODUCT: 产品组件

| 方法 | 输入 | 输出 | 用途 |
|------|------|------|------|
| createProduct | CreateProductRequest | ProductResponse | 创建产品 |
| updateProduct | productId: Long, UpdateProductRequest | ProductResponse | 更新产品 |
| deleteProduct | productId: Long | void | 删除产品 |
| getProductById | productId: Long | ProductResponse | 获取产品详情 |
| listProducts | page, size, categoryId?, keyword? | PageResponse\<ProductResponse\> | 分页查询产品 |
| updateStock | productId: Long, quantity: Int | void | 更新库存 |

### BE-CATEGORY: 分类组件

| 方法 | 输入 | 输出 | 用途 |
|------|------|------|------|
| createCategory | CreateCategoryRequest(name, parentId?) | CategoryResponse | 创建分类 |
| updateCategory | categoryId: Long, UpdateCategoryRequest | CategoryResponse | 更新分类 |
| deleteCategory | categoryId: Long | void | 删除分类 |
| getCategoryTree | — | List\<CategoryTreeNode\> | 获取完整分类树 |
| getCategoryById | categoryId: Long | CategoryResponse | 获取分类详情 |

### BE-POINTS: 积分组件

| 方法 | 输入 | 输出 | 用途 |
|------|------|------|------|
| getBalance | userId: Long | PointBalanceResponse | 查询积分余额 |
| adjustPoints | AdjustPointsRequest(userId, amount, reason, operatorId) | PointTransactionResponse | 手动调整积分 |
| deductPoints | userId: Long, amount: Int, orderId: Long | PointTransactionResponse | 兑换扣除积分 |
| rollbackDeduction | transactionId: Long | void | 回滚积分扣除 |
| getTransactionHistory | userId: Long, page, size | PageResponse\<PointTransactionResponse\> | 查询积分变动历史 |
| listAllBalances | page, size, keyword? | PageResponse\<UserPointResponse\> | 管理员查看所有余额 |

### BE-ORDER: 兑换组件

| 方法 | 输入 | 输出 | 用途 |
|------|------|------|------|
| createOrder | CreateOrderRequest(userId, productId) | OrderResponse | 创建兑换订单 |
| getOrderById | orderId: Long | OrderResponse | 获取兑换详情 |
| listUserOrders | userId: Long, page, size | PageResponse\<OrderResponse\> | 查询用户兑换历史 |
| listAllOrders | page, size, keyword?, dateRange? | PageResponse\<OrderResponse\> | 管理员查看所有兑换 |
| updateOrderStatus | orderId: Long, status: OrderStatus | OrderResponse | 更新兑换状态 |

### BE-FILE: 文件组件

| 方法 | 输入 | 输出 | 用途 |
|------|------|------|------|
| uploadFile | MultipartFile | FileResponse(url, filename) | 上传文件 |
| getFile | filename: String | FileResource | 获取文件 |
| deleteFile | filename: String | void | 删除文件 |

### BE-SCHEDULER: 调度组件

| 方法 | 输入 | 输出 | 用途 |
|------|------|------|------|
| executePointDistribution | — | DistributionResult | 执行积分自动发放 |
| getDistributionConfig | — | DistributionConfigResponse | 获取发放配置 |
| updateDistributionConfig | UpdateConfigRequest(amount, period) | DistributionConfigResponse | 更新发放配置 |

---

## API 端点汇总

### 公开端点（无需认证）
| 方法 | 路径 | 描述 |
|------|------|------|
| POST | /api/auth/register | 用户注册 |
| POST | /api/auth/login | 用户登录 |

### 员工端点（需要认证）
| 方法 | 路径 | 描述 |
|------|------|------|
| POST | /api/auth/logout | 退出登录 |
| GET | /api/products | 产品列表（分页、搜索、分类筛选） |
| GET | /api/products/{id} | 产品详情 |
| GET | /api/categories/tree | 分类树 |
| GET | /api/points/balance | 我的积分余额 |
| GET | /api/points/transactions | 我的积分历史 |
| POST | /api/orders | 创建兑换订单 |
| GET | /api/orders | 我的兑换历史 |
| GET | /api/orders/{id} | 兑换详情 |

### 管理员端点（需要管理员角色）
| 方法 | 路径 | 描述 |
|------|------|------|
| POST | /api/admin/products | 创建产品 |
| PUT | /api/admin/products/{id} | 更新产品 |
| DELETE | /api/admin/products/{id} | 删除产品 |
| POST | /api/admin/categories | 创建分类 |
| PUT | /api/admin/categories/{id} | 更新分类 |
| DELETE | /api/admin/categories/{id} | 删除分类 |
| GET | /api/admin/users | 用户列表 |
| GET | /api/admin/points/balances | 所有员工积分 |
| POST | /api/admin/points/adjust | 调整积分 |
| GET | /api/admin/points/config | 获取发放配置 |
| PUT | /api/admin/points/config | 更新发放配置 |
| GET | /api/admin/orders | 所有兑换记录 |
| PUT | /api/admin/orders/{id}/status | 更新兑换状态 |
| POST | /api/files/upload | 上传图片 |
