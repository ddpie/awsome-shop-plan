# Unit 4: points-service — 逻辑组件清单

---

## 1. 组件清单

| # | 组件 | 类型 | 职责 | 关联 NFR |
|---|------|------|------|---------|
| 1 | PointsController | REST 控制器 | 员工积分查询端点（余额、历史） | NFR-PTS-SEC-003 |
| 2 | AdminPointsController | REST 控制器 | 管理员积分管理端点（列表、调整、配置） | NFR-PTS-SEC-002, NFR-PTS-SEC-003 |
| 3 | InternalPointsController | REST 控制器 | 内部接口端点（初始化、扣除、回滚、查询） | NFR-PTS-SEC-001 |
| 4 | PointsService | 业务逻辑 | 积分余额查询、扣除、调整、回滚核心逻辑 | NFR-PTS-REL-001, NFR-PTS-REL-004 |
| 5 | DistributionService | 业务逻辑 | 积分自动发放、批次管理、补发逻辑 | NFR-PTS-REL-002, NFR-PTS-REL-003 |
| 6 | ConfigService | 业务逻辑 | 系统配置读取和更新 | NFR-PTS-MAINT-003 |
| 7 | PointBalanceRepository | 数据访问 | point_balances 表 CRUD + 悲观锁查询 | NFR-PTS-PERF-002 |
| 8 | PointTransactionRepository | 数据访问 | point_transactions 表 CRUD + 分页查询 + 类型筛选 | NFR-PTS-PERF-003 |
| 9 | DistributionBatchRepository | 数据访问 | distribution_batches 表 CRUD + 状态查询 | NFR-PTS-REL-002 |
| 10 | SystemConfigRepository | 数据访问 | system_configs 表 CRUD + UPSERT | NFR-PTS-MAINT-003 |
| 11 | DistributionScheduler | 定时任务 | cron 触发器，调用 DistributionService | NFR-PTS-PERF-004, NFR-PTS-TEST-002 |
| 12 | GlobalExceptionHandler | 横切关注点 | 统一异常捕获和错误响应格式化 | NFR-PTS-MAINT-001 |

---

## 2. 目录结构

```
points-service/
  src/
    controller/
      PointsController          # 员工积分查询
      AdminPointsController     # 管理员积分管理
      InternalPointsController  # 内部接口
    service/
      PointsService             # 积分核心业务逻辑
      DistributionService       # 发放业务逻辑
      ConfigService             # 配置管理
    repository/
      PointBalanceRepository    # 余额数据访问
      PointTransactionRepository # 流水数据访问
      DistributionBatchRepository # 批次数据访问
      SystemConfigRepository    # 配置数据访问
    model/
      PointBalance              # 余额实体
      PointTransaction          # 流水实体
      DistributionBatch         # 批次实体
      SystemConfig              # 配置实体
      TransactionType           # 变动类型枚举
    dto/
      InitPointsRequest
      AdjustPointsRequest
      DeductPointsRequest
      RollbackDeductionRequest
      UpdateDistributionConfigRequest
      PointBalanceResponse
      PointTransactionResponse
      UserPointResponse
      DistributionConfigResponse
    config/                     # 数据库配置等
    scheduler/
      DistributionScheduler     # 定时任务触发器
    exception/
      GlobalExceptionHandler    # 统一异常处理
      PointsException           # 业务异常类
```

---

## 3. 组件交互图

```
┌─────────────────────────────────────────────────────────────┐
│                     points-service                           │
│                                                              │
│  ┌──────────────────┐  ┌───────────────────┐                │
│  │ PointsController │  │AdminPointsController│               │
│  │  (员工端点)       │  │  (管理员端点)       │               │
│  └────────┬─────────┘  └─────────┬──────────┘               │
│           │                      │                           │
│  ┌────────┴──────────────────────┴──────────┐               │
│  │              PointsService                │               │
│  │  (余额查询/扣除/调整/回滚/历史查询)        │               │
│  └────────┬──────────────────────┬──────────┘               │
│           │                      │                           │
│  ┌────────┴─────────┐  ┌────────┴──────────┐               │
│  │PointBalanceRepo  │  │PointTransactionRepo│               │
│  │ (悲观锁查询)      │  │ (分页+类型筛选)     │               │
│  └──────────────────┘  └───────────────────┘               │
│                                                              │
│  ┌───────────────────────┐                                  │
│  │InternalPointsController│                                  │
│  │  (内部接口端点)         │──→ PointsService                │
│  └───────────────────────┘                                  │
│                                                              │
│  ┌──────────────────────┐  ┌──────────────────┐            │
│  │DistributionScheduler │→│DistributionService │            │
│  │  (cron 触发)          │  │ (发放+批次+补发)   │            │
│  └──────────────────────┘  └────────┬─────────┘            │
│                                      │                      │
│                            ┌─────────┴──────────┐          │
│                            │DistributionBatchRepo│          │
│                            │ (批次状态管理)       │          │
│                            └────────────────────┘          │
│                                                              │
│  ┌──────────────┐  ┌──────────────────┐                    │
│  │ ConfigService │→│SystemConfigRepo   │                    │
│  │ (配置管理)     │  │ (UPSERT)         │                    │
│  └──────────────┘  └──────────────────┘                    │
│                                                              │
│  ┌──────────────────────┐                                   │
│  │GlobalExceptionHandler │  (横切：统一错误处理)              │
│  └──────────────────────┘                                   │
└─────────────────────────────────────────────────────────────┘
```

---

## 4. NFR 需求覆盖映射

| NFR 编号 | 描述 | 实现组件 | 设计模式 |
|---------|------|---------|---------|
| NFR-PTS-SEC-001 | 内部接口网络隔离 | InternalPointsController | 内部接口隔离 |
| NFR-PTS-SEC-002 | 管理员操作审计 | AdminPointsController, PointsService | — |
| NFR-PTS-SEC-003 | 输入校验 | 所有 Controller | 分层输入校验 |
| NFR-PTS-PERF-001 | API P95 ≤ 200ms | 所有组件 | — |
| NFR-PTS-PERF-002 | 悲观锁 5s 超时 | PointBalanceRepository | 悲观锁并发控制 |
| NFR-PTS-PERF-003 | 分页查询性能 | PointTransactionRepository | — |
| NFR-PTS-PERF-004 | 定时任务执行效率 | DistributionScheduler, DistributionService | 定时任务批次可靠性 |
| NFR-PTS-REL-001 | 事务一致性 | PointsService | 悲观锁并发控制 |
| NFR-PTS-REL-002 | 发放批次记录 | DistributionService, DistributionBatchRepository | 定时任务批次可靠性 |
| NFR-PTS-REL-003 | 单条隔离 | DistributionService | 定时任务批次可靠性 |
| NFR-PTS-REL-004 | 幂等性保证 | PointsService | 幂等性设计 |
| NFR-PTS-REL-005 | 跨服务调用容错 | PointsService | 幂等性设计 |
| NFR-PTS-MAINT-001 | 统一错误响应 | GlobalExceptionHandler | 统一错误处理 |
| NFR-PTS-MAINT-002 | 日志规范 | DistributionService | — |
| NFR-PTS-MAINT-003 | 配置外部化 | ConfigService, SystemConfigRepository | — |
| NFR-PTS-TEST-001 | 接口可测试 | 所有 Controller | — |
| NFR-PTS-TEST-002 | 定时任务可测试 | DistributionScheduler, DistributionService | — |

**覆盖率**: 17/17 NFR 需求全部覆盖 ✅
