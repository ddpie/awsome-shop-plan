# Unit 1: awsomeshop-frontend — 领域实体

---

## 1. 页面结构

### 1.1 员工端页面

| 页面 | 路由 | 权限 | 说明 |
|------|------|------|------|
| 登录页 | /login | 公开 | 用户登录表单 |
| 注册页 | /register | 公开 | 用户注册表单 |
| 首页 | / | 已登录 | 产品列表（默认页） |
| 产品列表 | /products | 已登录 | 产品卡片网格，支持分类筛选和搜索 |
| 产品详情 | /products/:id | 已登录 | 产品详细信息，兑换入口 |
| 兑换确认 | /orders/confirm/:productId | 已登录 | 兑换确认页，显示产品信息和积分 |
| 兑换历史 | /orders | 已登录 | 用户兑换记录列表 |
| 积分中心 | /points | 已登录 | 积分余额和变动历史 |

### 1.2 管理端页面

| 页面 | 路由 | 权限 | 说明 |
|------|------|------|------|
| 管理首页 | /admin | 管理员 | 管理后台入口/仪表盘 |
| 产品管理 | /admin/products | 管理员 | 产品列表（表格）、新增、编辑、删除 |
| 产品新增 | /admin/products/new | 管理员 | 新增产品表单 |
| 产品编辑 | /admin/products/:id/edit | 管理员 | 编辑产品表单 |
| 分类管理 | /admin/categories | 管理员 | 分类列表、新增、编辑、删除 |
| 积分管理 | /admin/points | 管理员 | 员工积分列表、手动调整 |
| 积分配置 | /admin/points/config | 管理员 | 积分自动发放规则配置 |
| 兑换记录 | /admin/orders | 管理员 | 所有兑换记录、状态更新 |
| 用户管理 | /admin/users | 管理员 | 用户列表、禁用/启用 |

---

## 2. 组件结构

### 2.1 布局组件

| 组件 | 说明 |
|------|------|
| EmployeeLayout | 员工端布局（顶部导航） |
| AdminLayout | 管理端布局（侧边栏导航） |
| AuthLayout | 认证页布局（登录/注册） |

### 2.2 公共组件

| 组件 | 说明 |
|------|------|
| Navbar | 员工端顶部导航栏 |
| Sidebar | 管理端侧边栏导航 |
| UserMenu | 用户菜单（头像、退出） |
| LoadingSpinner | 加载中指示器 |
| EmptyState | 空状态占位 |
| ErrorBoundary | 错误边界 |
| InfiniteScroll | 无限滚动容器 |
| LazyImage | 图片懒加载组件 |

### 2.3 业务组件

| 组件 | 所属模块 | 说明 |
|------|---------|------|
| LoginForm | FE-AUTH | 登录表单 |
| RegisterForm | FE-AUTH | 注册表单 |
| ProductCard | FE-PRODUCT | 产品卡片（网格项） |
| ProductGrid | FE-PRODUCT | 产品卡片网格 |
| ProductDetail | FE-PRODUCT | 产品详情展示 |
| CategoryFilter | FE-PRODUCT | 分类筛选器 |
| SearchBar | FE-PRODUCT | 搜索栏 |
| PointsBalance | FE-POINTS | 积分余额展示 |
| PointsHistory | FE-POINTS | 积分变动历史列表 |
| OrderConfirm | FE-ORDER | 兑换确认信息 |
| OrderList | FE-ORDER | 兑换记录列表 |
| OrderStatusBadge | FE-ORDER | 兑换状态标签 |
| ProductTable | FE-ADMIN | 产品管理表格 |
| ProductForm | FE-ADMIN | 产品新增/编辑表单 |
| CategoryTree | FE-ADMIN | 分类树形结构 |
| CategoryForm | FE-ADMIN | 分类新增/编辑表单 |
| PointsTable | FE-ADMIN | 员工积分表格 |
| PointsAdjustModal | FE-ADMIN | 积分调整弹窗 |
| PointsConfigForm | FE-ADMIN | 积分配置表单 |
| OrderTable | FE-ADMIN | 兑换记录表格 |
| OrderStatusSelect | FE-ADMIN | 状态更新下拉框 |
| UserTable | FE-ADMIN | 用户管理表格 |

---

## 3. 状态模型

### 3.1 认证状态 (AuthState)

```typescript
interface AuthState {
  isAuthenticated: boolean;
  user: User | null;
  token: string | null;
  loading: boolean;
  error: string | null;
}

interface User {
  id: number;
  username: string;
  role: 'EMPLOYEE' | 'ADMIN';
}
```

### 3.2 产品状态 (ProductState)

```typescript
interface ProductState {
  products: Product[];
  currentProduct: Product | null;
  categories: Category[];
  selectedCategoryId: number | null;
  searchKeyword: string;
  loading: boolean;
  hasMore: boolean;
  page: number;
  error: string | null;
}

interface Product {
  id: number;
  name: string;
  description: string;
  pointsCost: number;
  stock: number;
  imageUrl: string | null;
  categoryId: number;
  categoryName: string;
  status: 'ACTIVE' | 'INACTIVE';
  createdAt: string;
}

interface Category {
  id: number;
  name: string;
  parentId: number | null;
  children?: Category[];
}
```

### 3.3 积分状态 (PointsState)

```typescript
interface PointsState {
  balance: number;
  transactions: PointTransaction[];
  loading: boolean;
  hasMore: boolean;
  page: number;
  error: string | null;
}

interface PointTransaction {
  id: number;
  type: 'EARN' | 'SPEND' | 'ADJUST' | 'REFUND';
  amount: number;
  balance: number;
  description: string;
  createdAt: string;
}
```

### 3.4 兑换状态 (OrderState)

```typescript
interface OrderState {
  orders: Order[];
  currentOrder: Order | null;
  loading: boolean;
  hasMore: boolean;
  page: number;
  error: string | null;
}

interface Order {
  id: number;
  productId: number;
  productName: string;
  productImage: string | null;
  pointsCost: number;
  status: 'PENDING' | 'READY' | 'COMPLETED' | 'CANCELLED';
  createdAt: string;
  updatedAt: string;
}
```

### 3.5 管理状态 (AdminState)

```typescript
interface AdminState {
  // 产品管理
  products: AdminProduct[];
  productsPagination: Pagination;
  
  // 分类管理
  categories: Category[];
  
  // 积分管理
  userPoints: UserPoints[];
  userPointsPagination: Pagination;
  pointsConfig: PointsConfig | null;
  
  // 兑换管理
  orders: AdminOrder[];
  ordersPagination: Pagination;
  
  // 用户管理
  users: AdminUser[];
  usersPagination: Pagination;
  
  loading: boolean;
  error: string | null;
}

interface Pagination {
  page: number;
  size: number;
  total: number;
  totalPages: number;
}

interface AdminProduct extends Product {
  // 管理视角额外字段
}

interface UserPoints {
  userId: number;
  username: string;
  balance: number;
}

interface PointsConfig {
  monthlyAmount: number;
}

interface AdminOrder extends Order {
  userId: number;
  username: string;
}

interface AdminUser {
  id: number;
  username: string;
  role: 'EMPLOYEE' | 'ADMIN';
  status: 'ACTIVE' | 'DISABLED';
  createdAt: string;
}
```

---

## 4. API 服务接口

### 4.1 认证服务 (AuthService)

| 方法 | 请求 | 响应 | 说明 |
|------|------|------|------|
| register | POST /api/auth/register | User | 用户注册 |
| login | POST /api/auth/login | { token, user } | 用户登录 |
| logout | - | - | 清除本地令牌 |
| getCurrentUser | GET /api/auth/me | User | 获取当前用户（可选） |

### 4.2 产品服务 (ProductService)

| 方法 | 请求 | 响应 | 说明 |
|------|------|------|------|
| getProducts | GET /api/products | Product[] | 产品列表（分页） |
| getProductById | GET /api/products/:id | Product | 产品详情 |
| searchProducts | GET /api/products?keyword=xxx | Product[] | 搜索产品 |
| getCategories | GET /api/categories | Category[] | 分类列表 |
| getCategoryTree | GET /api/categories/tree | Category[] | 分类树 |

### 4.3 积分服务 (PointsService)

| 方法 | 请求 | 响应 | 说明 |
|------|------|------|------|
| getBalance | GET /api/points/balance | { balance } | 获取积分余额 |
| getTransactions | GET /api/points/transactions | Transaction[] | 积分变动历史 |

### 4.4 兑换服务 (OrderService)

| 方法 | 请求 | 响应 | 说明 |
|------|------|------|------|
| createOrder | POST /api/orders | Order | 创建兑换订单 |
| getOrders | GET /api/orders | Order[] | 兑换历史 |
| getOrderById | GET /api/orders/:id | Order | 兑换详情 |

### 4.5 管理服务 (AdminService)

| 方法 | 请求 | 响应 | 说明 |
|------|------|------|------|
| getProducts | GET /api/admin/products | Product[] | 产品列表（管理） |
| createProduct | POST /api/admin/products | Product | 新增产品 |
| updateProduct | PUT /api/admin/products/:id | Product | 更新产品 |
| deleteProduct | DELETE /api/admin/products/:id | - | 删除产品 |
| getCategories | GET /api/admin/categories | Category[] | 分类列表（管理） |
| createCategory | POST /api/admin/categories | Category | 新增分类 |
| updateCategory | PUT /api/admin/categories/:id | Category | 更新分类 |
| deleteCategory | DELETE /api/admin/categories/:id | - | 删除分类 |
| uploadFile | POST /api/files/upload | { url } | 上传图片 |
| getUserPoints | GET /api/admin/points/balances | UserPoints[] | 员工积分列表 |
| adjustPoints | POST /api/admin/points/adjust | - | 手动调整积分 |
| getPointsConfig | GET /api/admin/points/config | PointsConfig | 获取积分配置 |
| updatePointsConfig | PUT /api/admin/points/config | PointsConfig | 更新积分配置 |
| getOrders | GET /api/admin/orders | Order[] | 所有兑换记录 |
| updateOrderStatus | PUT /api/admin/orders/:id/status | Order | 更新兑换状态 |
| getUsers | GET /api/admin/users | User[] | 用户列表 |
| updateUserStatus | PUT /api/admin/users/:id/status | User | 更新用户状态 |

---

## 5. 路由配置

### 5.1 路由定义

```typescript
const routes = [
  // 公开路由
  { path: '/login', component: LoginPage, layout: AuthLayout, public: true },
  { path: '/register', component: RegisterPage, layout: AuthLayout, public: true },
  
  // 员工端路由（需要登录）
  { path: '/', component: HomePage, layout: EmployeeLayout, auth: true },
  { path: '/products', component: ProductListPage, layout: EmployeeLayout, auth: true },
  { path: '/products/:id', component: ProductDetailPage, layout: EmployeeLayout, auth: true },
  { path: '/orders/confirm/:productId', component: OrderConfirmPage, layout: EmployeeLayout, auth: true },
  { path: '/orders', component: OrderListPage, layout: EmployeeLayout, auth: true },
  { path: '/points', component: PointsPage, layout: EmployeeLayout, auth: true },
  
  // 管理端路由（需要管理员角色）
  { path: '/admin', component: AdminDashboard, layout: AdminLayout, admin: true },
  { path: '/admin/products', component: AdminProductList, layout: AdminLayout, admin: true },
  { path: '/admin/products/new', component: AdminProductForm, layout: AdminLayout, admin: true },
  { path: '/admin/products/:id/edit', component: AdminProductForm, layout: AdminLayout, admin: true },
  { path: '/admin/categories', component: AdminCategoryList, layout: AdminLayout, admin: true },
  { path: '/admin/points', component: AdminPointsList, layout: AdminLayout, admin: true },
  { path: '/admin/points/config', component: AdminPointsConfig, layout: AdminLayout, admin: true },
  { path: '/admin/orders', component: AdminOrderList, layout: AdminLayout, admin: true },
  { path: '/admin/users', component: AdminUserList, layout: AdminLayout, admin: true },
  
  // 404
  { path: '*', component: NotFoundPage },
];
```

### 5.2 路由守卫逻辑

```typescript
function routeGuard(to, from, next) {
  const isAuthenticated = store.isAuthenticated;
  const isAdmin = store.user?.role === 'ADMIN';
  
  if (to.public) {
    // 公开路由，已登录用户重定向到首页
    if (isAuthenticated) {
      next('/');
    } else {
      next();
    }
  } else if (to.admin) {
    // 管理员路由
    if (!isAuthenticated) {
      next('/login');
    } else if (!isAdmin) {
      next('/'); // 非管理员重定向到员工首页
    } else {
      next();
    }
  } else if (to.auth) {
    // 需要登录的路由
    if (!isAuthenticated) {
      next('/login');
    } else {
      next();
    }
  } else {
    next();
  }
}
```

---

## 6. 本地存储

| 键名 | 类型 | 说明 |
|------|------|------|
| token | string | JWT 令牌 |
| user | JSON | 用户信息（id, username, role） |

说明：
- 登录成功后存储 token 和 user
- 退出登录时清除 token 和 user
- 页面刷新时从本地存储恢复认证状态
