# Admin - User Management 页面设计规格文档

> 源文件: `awsome-shop.pen` | 节点ID: `370RH` | 尺寸: 1440 × 900px

---

## 1. 页面整体布局

页面采用经典的**左侧边栏 + 右侧主内容区**水平布局。

```
┌─────────────────────────────────────────────────────┐
│  Sidebar (240px)  │         Main Content (flex-1)    │
│                   │  ┌─────────────────────────────┐ │
│  Logo             │  │ Header                      │ │
│  ─────────        │  ├─────────────────────────────┤ │
│  Nav Items        │  │ Stats Cards (3列)           │ │
│                   │  ├─────────────────────────────┤ │
│                   │  │ Toolbar (搜索/筛选)         │ │
│                   │  ├─────────────────────────────┤ │
│                   │  │ User Table                  │ │
│                   │  │  ├─ Table Header             │ │
│                   │  │  ├─ Table Rows               │ │
│                   │  │  └─ Pagination               │ │
│                   │  └─────────────────────────────┘ │
└─────────────────────────────────────────────────────┘
```

- 背景色: `$bg-page` (#F8FAFC)
- 字体: Inter

---

## 2. 左侧边栏 (Admin Sidebar)

| 属性 | 值 |
|------|-----|
| 宽度 | 240px |
| 高度 | fill_container (撑满) |
| 背景色 | `$bg-sidebar` (#0F172A 深蓝黑) |
| 布局 | vertical |
| padding | 24px top, 0 horizontal |

### 2.1 Logo 区域
- 图标: Material Symbols Rounded `redeem`，28×28，颜色 `$primary-light`
- 文字: "AWSome 管理"，Inter 17px Bold，颜色 `$text-white`
- gap: 10px，padding: [0, 20, 24, 20]

### 2.2 分隔线
- 高度 1px，背景 `$bg-sidebar-hover`

### 2.3 导航菜单项

| 菜单项 | 图标 (Material Symbols Rounded) | 状态 |
|--------|------|------|
| 仪表盘 | `dashboard` | 默认 |
| 产品管理 | `inventory_2` | 默认 |
| 分类管理 | `category` | 默认 |
| 积分管理 | `stars` | 默认 |
| 订单记录 | `receipt_long` | 默认 |
| **用户管理** | `group` | **激活** |

**导航项样式:**
- 默认态: 文字颜色 `$text-sidebar`，图标颜色 `$text-sidebar`，字重 normal
- 激活态: 背景 `$bg-sidebar-active` (#2563EB)，文字颜色 `$text-white`，字重 500
- 字号: 13px，图标 20×20
- 布局: horizontal，gap 12px，padding [10, 12]，圆角 `$radius-md`
- 菜单区域: gap 2px，padding [12, 8]

---

## 3. 主内容区 (User Main)

| 属性 | 值 |
|------|-----|
| 宽度 | fill_container |
| 高度 | fill_container |
| 布局 | vertical |
| gap | 20px |
| padding | 32px |

### 3.1 页头 (Header)

水平布局，两端对齐 (`justifyContent: space_between`)

**左侧:**
- 标题: "用户管理"，24px Bold，颜色 `$text-primary`

**右侧（水平排列，gap 12px）:**
- **导出按钮:** 图标 `download` (18×18) + 文字 "导出数据" (14px, 500)，颜色 `$text-secondary`，圆角 `$radius-md`，padding [10, 20]，1px 边框 `$border`
- **用户头像:** 圆形 40×40，背景 `$primary`，文字 "李" (16px, 600, white)，圆角 20

### 3.2 统计卡片区 (Stats)

水平排列，gap 16px，每个卡片 `fill_container` 等分。

| 卡片 | 标签 | 数值 | 数值颜色 | 副标签 | 副标签颜色 |
|------|------|------|---------|--------|----------|
| S1 | 总用户数 | 356 | `$text-primary` | 较上月 +12 | `$success` |
| S2 | 活跃用户 | 218 | `$primary` | 占比 61.2% | `$text-secondary` |
| S3 | 本月新增 | 12 | `$success` | 较上月 +3 | `$success` |

**卡片通用样式:**
- 背景: `$bg-white`，圆角 `$radius-lg`，1px 边框 `$border-light`
- 布局: vertical，gap 8px，padding 16px
- 标签: 12px normal `$text-secondary`
- 数值: 28px Bold
- 副标签: 11px normal

### 3.3 工具栏 (Toolbar)

水平排列，垂直居中，gap 12px。

| 组件 | 描述 | 样式 |
|------|------|------|
| **搜索框** | placeholder "搜索用户名或工号..." | 宽 280px，高 40px，圆角 `$radius-md`，背景 `$bg-white`，1px 边框 `$border`，图标 `search` 18×18 |
| **角色筛选** | 下拉选择器 "全部角色" | 高 40px，圆角 `$radius-md`，背景 `$bg-white`，1px 边框 `$border`，图标 `filter_list` + `keyboard_arrow_down` |
| **用户计数** | "共 356 位用户" | 宽 fill_container（推向右侧），13px `$text-secondary` |

### 3.4 用户表格卡片 (Table Card)

外层卡片: 背景 `$bg-white`，圆角 `$radius-lg`，1px 边框 `$border-light`，vertical 布局。

#### 3.4.1 表头 (Table Header)

- 背景: `$bg-page`
- padding: [14, 20]
- 水平布局，垂直居中

| 列名 | 宽度 | 说明 |
|------|------|------|
| 用户信息 | fill_container | 自适应剩余宽度 |
| 部门 | 130px | 固定 |
| 积分余额 | 100px | 固定 |
| 兑换次数 | 90px | 固定 |
| 角色 | 110px | 固定 |
| 状态 | 80px | 固定 |
| 操作 | 90px | 固定 |

表头字体: 12px, 600, `$text-secondary`

#### 3.4.2 表格行数据

每行: padding [14, 20]，水平布局，垂直居中，底部 1px 分隔线 `$divider`。

**示例数据 (4行):**

| 头像 | 姓名 | 工号 | 部门 | 积分余额 | 兑换次数 | 角色 | 状态 | 操作 |
|------|------|------|------|---------|---------|------|------|------|
| 蓝色(张) | 张明辉 | EMP-2024001 | 技术研发部 | 3,680 | 12 | 员工 | 正常 | 编辑/禁用 |
| 红色(王) | 王建国 | EMP-2022118 | 市场营销部 | 0 | 23 | 员工 | 已禁用 | 编辑/解禁 |
| 紫色(李) | 李婷婷 | EMP-2023056 | 人力资源部 | 5,120 | 8 | 管理员 | 正常 | 编辑/禁用 |
| 绿色(陈) | 陈思雨 | EMP-2024089 | 财务部 | 1,450 | 5 | 员工 | 正常 | 编辑/禁用 |

**用户信息列 (复合布局):**
- 头像: 圆形 36×36，居中显示姓氏首字（14px, 600, white），各用户头像颜色不同
- 姓名: 13px, 500, `$text-primary`
- 工号: 11px, normal, `$text-disabled`，格式 "工号: EMP-XXXXXXX"
- 头像与信息 gap 10px，姓名与工号 gap 2px

**积分余额列:**
- 有积分: 13px, 600, 颜色 `#D97706` (amber)
- 零积分: 13px, 600, 颜色 `$text-disabled`

**兑换次数列:**
- 13px, normal, `$text-primary`

**角色 Badge:**

| 角色 | 背景色 | 文字颜色 |
|------|--------|---------|
| 员工 | `$chip-blue-bg` (#DBEAFE) | `$chip-blue-text` (#1E40AF) |
| 管理员 | #FEF3C7 (amber) | #92400E (amber-dark) |

- 圆角 12px，padding [4, 10]，字号 11px, 500

**状态 Badge:**

| 状态 | 背景色 | 文字颜色 |
|------|--------|---------|
| 正常 | `$chip-green-bg` (#DCFCE7) | `$chip-green-text` (#166534) |
| 已禁用 | `$chip-red-bg` (#FEE2E2) | `$chip-red-text` (#991B1B) |

- 圆角 12px，padding [4, 10]，字号 11px, 500

**操作列 (水平排列, gap 8px):**

| 状态 | 操作1 | 操作2 |
|------|-------|-------|
| 正常用户 | `edit` 编辑 (`$text-secondary`) | `block` 禁用 (`$warning`) |
| 已禁用用户 | `edit` 编辑 (`$text-secondary`) | `lock_open` 解禁 (`$success`) |

- 图标大小: 18×18

#### 3.4.3 分页器 (Pagination)

- 两端对齐 (`justifyContent: space_between`)
- padding [12, 20]，顶部 1px 分隔线

**左侧:** "显示 1-10 共 356 条"，12px, `$text-secondary`

**右侧分页按钮 (gap 4px):**
- 按钮尺寸: 32×32，圆角 `$radius-sm`
- 普通页码: 1px 边框 `$border`，无背景
- 当前页: 背景 `$primary`，文字白色
- 省略号: "..."
- 上/下页: `<` / `>` 箭头按钮
- 页码范围: 1, 2, 3 ... 36

---

## 4. 数据模型 (供后端 API 参考)

### 4.1 用户实体 (User)

```typescript
interface User {
  id: string;                    // 用户唯一ID
  employeeId: string;            // 工号，格式 "EMP-XXXXXXX"
  name: string;                  // 姓名
  avatar?: string;               // 头像URL (可选，无则显示姓氏首字+颜色)
  avatarColor: string;           // 头像背景色
  department: string;            // 部门名称
  points: number;                // 积分余额
  exchangeCount: number;         // 兑换次数
  role: 'employee' | 'admin';    // 角色: 员工 / 管理员
  status: 'active' | 'disabled'; // 状态: 正常 / 已禁用
  createdAt: string;             // 创建时间
  updatedAt: string;             // 更新时间
}
```

### 4.2 统计数据

```typescript
interface UserStats {
  totalUsers: number;         // 总用户数
  monthlyGrowth: number;      // 较上月增长数
  activeUsers: number;        // 活跃用户数
  activeRate: number;         // 活跃占比 (0-1)
  newUsersThisMonth: number;  // 本月新增
  newUsersGrowth: number;     // 新增较上月增长数
}
```

### 4.3 API 接口建议

#### GET /api/admin/users
用户列表（分页）

**Query 参数:**

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| page | number | 否 | 页码，默认 1 |
| pageSize | number | 否 | 每页条数，默认 10 |
| keyword | string | 否 | 搜索关键词 (姓名/工号) |
| role | string | 否 | 角色筛选: all / employee / admin |

**Response:**

```json
{
  "data": {
    "list": [User],
    "total": 356,
    "page": 1,
    "pageSize": 10
  }
}
```

#### GET /api/admin/users/stats
用户统计数据

**Response:**

```json
{
  "data": {
    "totalUsers": 356,
    "monthlyGrowth": 12,
    "activeUsers": 218,
    "activeRate": 0.612,
    "newUsersThisMonth": 12,
    "newUsersGrowth": 3
  }
}
```

#### PUT /api/admin/users/:id/status
更新用户状态（启用/禁用）

```json
{
  "status": "active" | "disabled"
}
```

#### PUT /api/admin/users/:id
编辑用户信息

#### GET /api/admin/users/export
导出用户数据

---

## 5. 交互逻辑

### 5.1 搜索
- 输入关键词后搜索匹配用户名或工号
- 建议: 防抖 300ms，最少输入 2 字符触发

### 5.2 角色筛选
- 下拉选项: 全部角色 / 员工 / 管理员
- 切换后重新请求列表，重置到第 1 页

### 5.3 表格操作
- **编辑** (edit icon): 打开用户编辑弹窗/页面
- **禁用** (block icon): 弹出确认对话框，确认后禁用用户，状态变为"已禁用"(红色 badge)
- **解禁** (lock_open icon): 仅对已禁用用户显示，确认后恢复用户状态

### 5.4 分页
- 每页 10 条记录
- 显示: 上一页 / 页码 / 省略号 / 下一页
- 当前页高亮 (蓝色背景)

### 5.5 导出数据
- 点击导出按钮，按当前筛选条件导出用户列表（建议 CSV/Excel 格式）

---

## 6. 设计令牌 (Design Tokens)

### 颜色变量

| 变量名 | 用途 | 值 |
|--------|------|-----|
| `$primary` | 主色/品牌色 | #2563EB |
| `$primary-light` | 浅主色 | #60A5FA |
| `$success` | 成功/增长 | #16A34A |
| `$warning` | 警告/禁用操作 | #D97706 |
| `$error` | 错误/危险 | #DC2626 |
| `$text-primary` | 主文字 | #1E293B |
| `$text-secondary` | 辅助文字 | #64748B |
| `$text-disabled` | 禁用文字 | #CBD5E1 |
| `$text-white` | 白色文字 | #FFFFFF |
| `$bg-page` | 页面背景 | #F8FAFC |
| `$bg-white` | 卡片背景 | #FFFFFF |
| `$bg-sidebar` | 侧边栏背景 | #0F172A |
| `$border` | 边框 | #E2E8F0 |
| `$border-light` | 浅边框 | #F1F5F9 |
| `$divider` | 分隔线 | #F1F5F9 |

### 圆角变量

| 变量名 | 值 |
|--------|-----|
| `$radius-sm` | 4px |
| `$radius-md` | 8px |
| `$radius-lg` | 12px |
| `$radius-xl` | 16px |

---

## 7. 前端组件拆分建议

```
AdminLayout
├── Sidebar
│   ├── SidebarLogo
│   └── SidebarNav
│       └── SidebarNavItem (×6)
└── MainContent
    ├── PageHeader
    │   ├── PageTitle
    │   ├── ExportButton
    │   └── UserAvatar
    ├── StatsCards
    │   └── StatCard (×3)
    ├── Toolbar
    │   ├── SearchInput
    │   ├── RoleFilter (Select)
    │   └── UserCount
    └── UserTableCard
        ├── UserTable
        │   ├── TableHeader
        │   └── TableRow (×N)
        │       ├── UserInfoCell (avatar + name + employeeId)
        │       ├── DepartmentCell
        │       ├── PointsCell
        │       ├── ExchangeCountCell
        │       ├── RoleBadge
        │       ├── StatusBadge
        │       └── ActionButtons
        └── Pagination
```
