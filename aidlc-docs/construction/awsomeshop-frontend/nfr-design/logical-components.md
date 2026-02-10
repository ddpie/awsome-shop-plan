# Unit 1: awsomeshop-frontend — 逻辑组件

---

## 1. 组件清单

### 1.1 核心基础设施组件

| 组件 | 职责 | 关联 NFR |
|------|------|---------|
| HttpClient | 统一 HTTP 请求封装，超时、拦截器、错误处理 | NFR-FE-014, 016 |
| AuthProvider | 认证状态管理，token 存储与恢复 | NFR-FE-011 |
| RouterGuard | 路由权限守卫，认证与授权检查 | NFR-FE-011, 013 |
| ErrorBoundary | 错误边界，捕获渲染错误并降级 | NFR-FE-015 |
| ToastProvider | 全局消息提示管理 | NFR-FE-023 |

### 1.2 性能优化组件

| 组件 | 职责 | 关联 NFR |
|------|------|---------|
| LazyImage | 图片懒加载，Intersection Observer 实现 | NFR-FE-020, 021 |
| InfiniteScroll | 无限滚动容器，分页加载 | NFR-FE-004 |
| Suspense/LazyLoad | 路由级代码分割，按需加载 | NFR-FE-001, 003 |

### 1.3 可访问性组件

| 组件 | 职责 | 关联 NFR |
|------|------|---------|
| FocusTrap | 焦点陷阱，用于模态框 | NFR-FE-006 |
| SkipLink | 跳过导航链接 | NFR-FE-006 |
| LiveRegion | aria-live 区域，动态内容通知 | NFR-FE-008 |

### 1.4 UI 反馈组件

| 组件 | 职责 | 关联 NFR |
|------|------|---------|
| LoadingSpinner | 加载中指示器 | NFR-FE-022 |
| Skeleton | 骨架屏 | NFR-FE-022 |
| EmptyState | 空状态占位 | NFR-FE-024 |
| ErrorState | 错误状态展示 | NFR-FE-015, 016 |

### 1.5 表单组件

| 组件 | 职责 | 关联 NFR |
|------|------|---------|
| FormField | 表单字段封装，label + input + error | NFR-FE-005 |
| FormValidator | 表单校验逻辑 | NFR-FE-005 |
| SubmitButton | 提交按钮，loading 状态 | NFR-FE-022 |

---

## 2. 目录结构

```
src/
├── components/                    # 公共组件
│   ├── common/                    # 通用 UI 组件
│   │   ├── LoadingSpinner.tsx     # 加载指示器
│   │   ├── Skeleton.tsx           # 骨架屏
│   │   ├── EmptyState.tsx         # 空状态
│   │   ├── ErrorState.tsx         # 错误状态
│   │   └── LazyImage.tsx          # 图片懒加载
│   │
│   ├── feedback/                  # 反馈组件
│   │   ├── Toast.tsx              # 消息提示
│   │   ├── ToastProvider.tsx      # Toast 上下文
│   │   └── ConfirmDialog.tsx      # 确认对话框
│   │
│   ├── form/                      # 表单组件
│   │   ├── FormField.tsx          # 表单字段
│   │   ├── FormValidator.ts       # 校验逻辑
│   │   └── SubmitButton.tsx       # 提交按钮
│   │
│   ├── layout/                    # 布局组件
│   │   ├── EmployeeLayout.tsx     # 员工端布局
│   │   ├── AdminLayout.tsx        # 管理端布局
│   │   ├── AuthLayout.tsx         # 认证页布局
│   │   ├── Navbar.tsx             # 顶部导航
│   │   └── Sidebar.tsx            # 侧边栏
│   │
│   ├── accessibility/             # 可访问性组件
│   │   ├── FocusTrap.tsx          # 焦点陷阱
│   │   ├── SkipLink.tsx           # 跳过链接
│   │   └── LiveRegion.tsx         # aria-live 区域
│   │
│   └── data/                      # 数据展示组件
│       └── InfiniteScroll.tsx     # 无限滚动
│
├── pages/                         # 页面组件
│   ├── auth/                      # 认证页面
│   │   ├── LoginPage.tsx
│   │   └── RegisterPage.tsx
│   │
│   ├── employee/                  # 员工端页面
│   │   ├── HomePage.tsx
│   │   ├── ProductListPage.tsx
│   │   ├── ProductDetailPage.tsx
│   │   ├── OrderConfirmPage.tsx
│   │   ├── OrderListPage.tsx
│   │   └── PointsPage.tsx
│   │
│   ├── admin/                     # 管理端页面
│   │   ├── DashboardPage.tsx
│   │   ├── ProductManagePage.tsx
│   │   ├── ProductFormPage.tsx
│   │   ├── CategoryManagePage.tsx
│   │   ├── PointsManagePage.tsx
│   │   ├── PointsConfigPage.tsx
│   │   ├── OrderManagePage.tsx
│   │   └── UserManagePage.tsx
│   │
│   └── error/                     # 错误页面
│       ├── NotFoundPage.tsx
│       └── ErrorPage.tsx
│
├── services/                      # API 服务
│   ├── http.ts                    # HTTP 客户端封装
│   ├── auth.service.ts            # 认证服务
│   ├── product.service.ts         # 产品服务
│   ├── points.service.ts          # 积分服务
│   ├── order.service.ts           # 兑换服务
│   └── admin.service.ts           # 管理服务
│
├── stores/                        # 状态管理
│   ├── auth.store.ts              # 认证状态
│   ├── product.store.ts           # 产品状态
│   ├── points.store.ts            # 积分状态
│   ├── order.store.ts             # 兑换状态
│   └── admin.store.ts             # 管理状态
│
├── router/                        # 路由配置
│   ├── index.ts                   # 路由定义
│   ├── guards.ts                  # 路由守卫
│   └── routes.ts                  # 路由配置
│
├── hooks/                         # 自定义 Hooks
│   ├── useAuth.ts                 # 认证 Hook
│   ├── useToast.ts                # Toast Hook
│   ├── useInfiniteScroll.ts       # 无限滚动 Hook
│   └── useLazyImage.ts            # 图片懒加载 Hook
│
├── utils/                         # 工具函数
│   ├── validators.ts              # 校验函数
│   ├── formatters.ts              # 格式化函数
│   └── storage.ts                 # 本地存储封装
│
├── types/                         # 类型定义
│   ├── auth.types.ts
│   ├── product.types.ts
│   ├── points.types.ts
│   ├── order.types.ts
│   └── api.types.ts
│
├── assets/                        # 静态资源
│   ├── images/
│   │   └── placeholder.svg        # 占位图
│   └── styles/
│       └── global.css             # 全局样式
│
├── App.tsx                        # 应用入口
├── main.tsx                       # 渲染入口
└── index.html                     # HTML 模板
```

---

## 3. 组件交互图

```
┌─────────────────────────────────────────────────────────────────────┐
│                           App.tsx                                    │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │                     ErrorBoundary                            │   │
│  │  ┌─────────────────────────────────────────────────────┐   │   │
│  │  │                   AuthProvider                       │   │   │
│  │  │  ┌─────────────────────────────────────────────┐   │   │   │
│  │  │  │                ToastProvider                 │   │   │   │
│  │  │  │  ┌─────────────────────────────────────┐   │   │   │   │
│  │  │  │  │              Router                  │   │   │   │   │
│  │  │  │  │  ┌─────────────────────────────┐   │   │   │   │   │
│  │  │  │  │  │        RouterGuard          │   │   │   │   │   │
│  │  │  │  │  │  ┌─────────────────────┐   │   │   │   │   │   │
│  │  │  │  │  │  │   Layout + Page     │   │   │   │   │   │   │
│  │  │  │  │  │  └─────────────────────┘   │   │   │   │   │   │
│  │  │  │  │  └─────────────────────────────┘   │   │   │   │   │
│  │  │  │  └─────────────────────────────────────┘   │   │   │   │
│  │  │  └─────────────────────────────────────────────┘   │   │   │
│  │  └─────────────────────────────────────────────────────┘   │   │
│  └─────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 4. 数据流图

```
┌─────────────────────────────────────────────────────────────────────┐
│                          数据流向                                    │
│                                                                     │
│  ┌─────────────┐      ┌─────────────┐      ┌─────────────┐        │
│  │   Component │ ───→ │    Store    │ ───→ │   Service   │        │
│  │   (View)    │ ←─── │   (State)   │ ←─── │   (API)     │        │
│  └─────────────┘      └─────────────┘      └─────────────┘        │
│        │                    │                    │                 │
│        │                    │                    ↓                 │
│        │                    │           ┌─────────────┐           │
│        │                    │           │  HttpClient │           │
│        │                    │           └─────────────┘           │
│        │                    │                    │                 │
│        │                    │                    ↓                 │
│        │                    │           ┌─────────────┐           │
│        │                    │           │ API Gateway │           │
│        │                    │           │ :8080/api/* │           │
│        │                    │           └─────────────┘           │
│        │                    │                                      │
│        ↓                    ↓                                      │
│  ┌─────────────────────────────────────────────────────────┐      │
│  │                    用户交互流程                          │      │
│  │  1. 用户操作 → Component 触发 action                    │      │
│  │  2. Store 调用 Service 发起 API 请求                    │      │
│  │  3. HttpClient 添加 token，发送请求                     │      │
│  │  4. 响应返回 → Store 更新状态                           │      │
│  │  5. Component 响应状态变化，更新 UI                     │      │
│  └─────────────────────────────────────────────────────────┘      │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 5. 关键组件详细设计

### 5.1 HttpClient

```typescript
// services/http.ts
interface HttpClientConfig {
  baseURL: string;
  timeout: number;
}

interface HttpClient {
  get<T>(url: string, config?: RequestConfig): Promise<T>;
  post<T>(url: string, data?: any, config?: RequestConfig): Promise<T>;
  put<T>(url: string, data?: any, config?: RequestConfig): Promise<T>;
  delete<T>(url: string, config?: RequestConfig): Promise<T>;
}

// 功能:
// - 统一 baseURL 配置 (/api)
// - 统一超时配置 (10s)
// - 请求拦截: 添加 Authorization header
// - 响应拦截: 统一错误处理
// - 支持请求取消
```

### 5.2 AuthProvider

```typescript
// stores/auth.store.ts
interface AuthState {
  isAuthenticated: boolean;
  user: User | null;
  token: string | null;
  loading: boolean;
}

interface AuthActions {
  login(credentials: LoginRequest): Promise<void>;
  logout(): void;
  restoreSession(): void;
}

// 功能:
// - 管理认证状态
// - 登录/登出操作
// - 从 localStorage 恢复会话
// - token 过期处理
```

### 5.3 RouterGuard

```typescript
// router/guards.ts
interface RouteGuardConfig {
  public?: boolean;    // 公开路由
  auth?: boolean;      // 需要登录
  admin?: boolean;     // 需要管理员
}

// 功能:
// - 检查路由权限
// - 未登录重定向到 /login
// - 非管理员重定向到 /
// - 已登录访问 /login 重定向到 /
```

### 5.4 ErrorBoundary

```typescript
// components/common/ErrorBoundary.tsx
interface ErrorBoundaryProps {
  fallback?: ReactNode;
  onError?: (error: Error, errorInfo: ErrorInfo) => void;
  children: ReactNode;
}

// 功能:
// - 捕获子组件渲染错误
// - 显示降级 UI
// - 提供重试机制
// - 错误日志记录
```

### 5.5 LazyImage

```typescript
// components/common/LazyImage.tsx
interface LazyImageProps {
  src: string;
  alt: string;
  placeholder?: string;
  errorPlaceholder?: string;
  rootMargin?: string;
}

// 功能:
// - Intersection Observer 监听
// - 进入视口前显示占位图
// - 加载成功显示真实图片
// - 加载失败显示错误占位图
```

---

## 6. NFR 需求覆盖映射

| NFR 编号 | NFR 描述 | 覆盖组件 |
|---------|---------|---------|
| NFR-FE-001 | 首屏加载性能 | Suspense/LazyLoad |
| NFR-FE-002 | 页面交互响应 | 所有交互组件 |
| NFR-FE-003 | 路由切换性能 | Suspense/LazyLoad |
| NFR-FE-004 | 无限滚动性能 | InfiniteScroll |
| NFR-FE-005 | WCAG 2.1 AA | FormField, FocusTrap, SkipLink |
| NFR-FE-006 | 键盘导航 | FocusTrap, SkipLink |
| NFR-FE-007 | 语义化 HTML | 所有组件 |
| NFR-FE-008 | 屏幕阅读器 | LiveRegion, FormField |
| NFR-FE-009 | 浏览器支持 | 构建配置 |
| NFR-FE-010 | 桌面端优先 | 布局组件 |
| NFR-FE-011 | JWT 存储 | AuthProvider, RouterGuard |
| NFR-FE-012 | XSS 防护 | 框架默认 |
| NFR-FE-013 | 敏感信息保护 | AuthProvider, RouterGuard |
| NFR-FE-014 | API 超时 | HttpClient |
| NFR-FE-015 | 错误边界 | ErrorBoundary, ErrorState |
| NFR-FE-016 | 网络错误处理 | HttpClient, ErrorState |
| NFR-FE-017 | 代码组织 | 目录结构 |
| NFR-FE-018 | 组件复用 | 公共组件 |
| NFR-FE-019 | 代码风格 | ESLint/Prettier |
| NFR-FE-020 | 图片懒加载 | LazyImage |
| NFR-FE-021 | 图片失败处理 | LazyImage |
| NFR-FE-022 | 加载状态 | LoadingSpinner, Skeleton, SubmitButton |
| NFR-FE-023 | 操作反馈 | ToastProvider, ConfirmDialog |
| NFR-FE-024 | 空状态处理 | EmptyState |

**覆盖率**: 24/24 = 100%
