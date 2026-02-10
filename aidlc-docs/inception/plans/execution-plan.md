# AWSomeShop 执行计划

## 详细分析摘要

### 变更影响评估
- **用户界面变更**: 是 — 全新的前端界面（员工端 + 管理端）
- **结构变更**: 是 — 全新的前后端分离架构
- **数据模型变更**: 是 — 全新的数据库设计（用户、产品、分类、积分、兑换记录）
- **API 变更**: 是 — 全新的 RESTful API 设计
- **NFR 影响**: 是 — 安全认证、Docker 部署、性能考量

### 风险评估
- **风险级别**: 中等
- **回滚复杂度**: 低（全新项目，无历史包袱）
- **测试复杂度**: 中等（多模块集成测试）

## 工作流可视化

```mermaid
flowchart TD
    Start(["用户请求"])
    
    subgraph INCEPTION["🔵 启动阶段 — ✅ 全部完成"]
        WD["工作区检测 ✅"]
        RA["需求分析 ✅"]
        US["用户故事 ✅"]
        WP["工作流规划 ✅"]
        AD["应用设计 ✅"]
        UG["工作单元生成 ✅"]
    end

    subgraph CONSTRUCTION["🟢 构建阶段"]

        subgraph P1["阶段1（先行）: Unit 7 infrastructure ✅"]
            U7_FD["功能设计 ✅"]
            U7_NFR["NFR需求 ✅"]
            U7_NFRD["NFR设计 ✅"]
            U7_ID["基础设施设计 ✅"]
            U7_CG["代码生成 ⏭️"]
            U7_BT["构建测试 ⏭️"]
        end

        subgraph P2_U2["Unit 2 auth-service"]
            U2_FD["功能设计 ✅"]
            U2_NFR["NFR需求 ✅"]
            U2_NFRD["NFR设计 ✅"]
            U2_ID["基础设施设计 ✅"]
            U2_CG["代码生成"]
            U2_BT["构建测试"]
        end

        subgraph P2_U3["Unit 3 product-service"]
            U3_FD["功能设计 ✅"]
            U3_NFR["NFR需求 ✅"]
            U3_NFRD["NFR设计 ✅"]
            U3_ID["基础设施设计 ✅"]
            U3_CG["代码生成"]
            U3_BT["构建测试"]
        end

        subgraph P2_U4["Unit 4 points-service"]
            U4_FD["功能设计 ✅"]
            U4_NFR["NFR需求 ✅"]
            U4_NFRD["NFR设计 ✅"]
            U4_ID["基础设施设计 ✅"]
            U4_CG["代码生成"]
            U4_BT["构建测试"]
        end

        subgraph P2_U5["Unit 5 order-service"]
            U5_FD["功能设计 ✅"]
            U5_NFR["NFR需求 ✅"]
            U5_NFRD["NFR设计 ✅"]
            U5_ID["基础设施设计 ✅"]
            U5_CG["代码生成"]
            U5_BT["构建测试"]
        end

        subgraph P2_U6["Unit 6 api-gateway"]
            U6_FD["功能设计 ✅"]
            U6_NFR["NFR需求 ✅"]
            U6_NFRD["NFR设计 ✅"]
            U6_ID["基础设施设计 ✅"]
            U6_CG["代码生成"]
            U6_BT["构建测试"]
        end

        subgraph P2_U1["Unit 1 frontend"]
            U1_FD["功能设计 ✅"]
            U1_NFR["NFR需求"]
            U1_NFRD["NFR设计"]
            U1_ID["基础设施设计"]
            U1_CG["代码生成"]
            U1_BT["构建测试"]
        end

        subgraph P3["阶段3: 集成测试"]
            IT["全链路集成测试"]
        end

    end

    Start --> WD --> RA --> US --> WP --> AD --> UG

    UG --> U7_FD --> U7_NFR --> U7_NFRD --> U7_ID --> U7_CG --> U7_BT

    U7_BT --> U2_FD
    U7_BT --> U3_FD
    U7_BT --> U4_FD
    U7_BT --> U5_FD
    U7_BT --> U6_FD
    U7_BT --> U1_FD

    U2_FD --> U2_NFR --> U2_NFRD --> U2_ID --> U2_CG --> U2_BT
    U3_FD --> U3_NFR --> U3_NFRD --> U3_ID --> U3_CG --> U3_BT
    U4_FD --> U4_NFR --> U4_NFRD --> U4_ID --> U4_CG --> U4_BT
    U5_FD --> U5_NFR --> U5_NFRD --> U5_ID --> U5_CG --> U5_BT
    U6_FD --> U6_NFR --> U6_NFRD --> U6_ID --> U6_CG --> U6_BT
    U1_FD --> U1_NFR --> U1_NFRD --> U1_ID --> U1_CG --> U1_BT

    U2_BT --> IT
    U3_BT --> IT
    U4_BT --> IT
    U5_BT --> IT
    U6_BT --> IT
    U1_BT --> IT

    IT --> End(["完成"])

    style WD fill:#4CAF50,stroke:#1B5E20,stroke-width:2px,color:#fff
    style RA fill:#4CAF50,stroke:#1B5E20,stroke-width:2px,color:#fff
    style US fill:#4CAF50,stroke:#1B5E20,stroke-width:2px,color:#fff
    style WP fill:#4CAF50,stroke:#1B5E20,stroke-width:2px,color:#fff
    style AD fill:#4CAF50,stroke:#1B5E20,stroke-width:2px,color:#fff
    style UG fill:#4CAF50,stroke:#1B5E20,stroke-width:2px,color:#fff
    style U7_FD fill:#4CAF50,stroke:#1B5E20,stroke-width:2px,color:#fff
    style U7_NFR fill:#4CAF50,stroke:#1B5E20,stroke-width:2px,color:#fff
    style U7_NFRD fill:#4CAF50,stroke:#1B5E20,stroke-width:2px,color:#fff
    style Start fill:none,stroke:#6A1B9A,stroke-width:2px
    style End fill:none,stroke:#6A1B9A,stroke-width:2px
    style INCEPTION fill:none,stroke:#1565C0,stroke-width:2px
    style CONSTRUCTION fill:none,stroke:#2E7D32,stroke-width:2px

    style U7_ID fill:#4CAF50,stroke:#1B5E20,stroke-width:2px,color:#fff
    style U7_CG fill:none,stroke:#999,stroke-width:1px,stroke-dasharray:5
    style U7_BT fill:none,stroke:#999,stroke-width:1px,stroke-dasharray:5

    style U2_FD fill:#4CAF50,stroke:#1B5E20,stroke-width:2px,color:#fff
    style U2_NFR fill:#4CAF50,stroke:#1B5E20,stroke-width:2px,color:#fff
    style U2_NFRD fill:#4CAF50,stroke:#1B5E20,stroke-width:2px,color:#fff
    style U2_ID fill:#4CAF50,stroke:#1B5E20,stroke-width:2px,color:#fff
    style U2_CG fill:none,stroke:#333,stroke-width:1px
    style U2_BT fill:none,stroke:#333,stroke-width:1px

    style U3_FD fill:#4CAF50,stroke:#1B5E20,stroke-width:2px,color:#fff
    style U3_NFR fill:#4CAF50,stroke:#1B5E20,stroke-width:2px,color:#fff
    style U3_NFRD fill:#4CAF50,stroke:#1B5E20,stroke-width:2px,color:#fff
    style U3_ID fill:#4CAF50,stroke:#1B5E20,stroke-width:2px,color:#fff
    style U3_CG fill:none,stroke:#333,stroke-width:1px
    style U3_BT fill:none,stroke:#333,stroke-width:1px

    style U4_FD fill:#4CAF50,stroke:#1B5E20,stroke-width:2px,color:#fff
    style U4_NFR fill:#4CAF50,stroke:#1B5E20,stroke-width:2px,color:#fff
    style U4_NFRD fill:#4CAF50,stroke:#1B5E20,stroke-width:2px,color:#fff
    style U4_ID fill:#4CAF50,stroke:#1B5E20,stroke-width:2px,color:#fff
    style U4_CG fill:none,stroke:#333,stroke-width:1px
    style U4_BT fill:none,stroke:#333,stroke-width:1px

    style U5_FD fill:#4CAF50,stroke:#1B5E20,stroke-width:2px,color:#fff
    style U5_NFR fill:#4CAF50,stroke:#1B5E20,stroke-width:2px,color:#fff
    style U5_NFRD fill:#4CAF50,stroke:#1B5E20,stroke-width:2px,color:#fff
    style U5_ID fill:#4CAF50,stroke:#1B5E20,stroke-width:2px,color:#fff
    style U5_CG fill:none,stroke:#333,stroke-width:1px
    style U5_BT fill:none,stroke:#333,stroke-width:1px

    style U6_FD fill:#4CAF50,stroke:#1B5E20,stroke-width:2px,color:#fff
    style U6_NFR fill:#4CAF50,stroke:#1B5E20,stroke-width:2px,color:#fff
    style U6_NFRD fill:#4CAF50,stroke:#1B5E20,stroke-width:2px,color:#fff
    style U6_ID fill:#4CAF50,stroke:#1B5E20,stroke-width:2px,color:#fff
    style U6_CG fill:none,stroke:#333,stroke-width:1px
    style U6_BT fill:none,stroke:#333,stroke-width:1px

    style U1_FD fill:#4CAF50,stroke:#1B5E20,stroke-width:2px,color:#fff
    style U1_NFR fill:#4CAF50,stroke:#1B5E20,stroke-width:2px,color:#fff
    style U1_NFRD fill:#4CAF50,stroke:#1B5E20,stroke-width:2px,color:#fff
    style U1_ID fill:#4CAF50,stroke:#1B5E20,stroke-width:2px,color:#fff
    style U1_CG fill:none,stroke:#333,stroke-width:1px
    style U1_BT fill:none,stroke:#333,stroke-width:1px

    style IT fill:none,stroke:#333,stroke-width:1px

    style P1 fill:none,stroke:#555,stroke-width:1px
    style P2_U2 fill:none,stroke:#555,stroke-width:1px
    style P2_U3 fill:none,stroke:#555,stroke-width:1px
    style P2_U4 fill:none,stroke:#555,stroke-width:1px
    style P2_U5 fill:none,stroke:#555,stroke-width:1px
    style P2_U6 fill:none,stroke:#555,stroke-width:1px
    style P2_U1 fill:none,stroke:#555,stroke-width:1px
    style P3 fill:none,stroke:#555,stroke-width:1px
```

### 文本替代方案
```
启动阶段: ✅ 全部完成
  ✅ 工作区检测 → ✅ 需求分析 → ✅ 用户故事 → ✅ 工作流规划 → ✅ 应用设计 → ✅ 工作单元生成

构建阶段: ⏳ 进行中
  阶段1（先行）: Unit 7 (infrastructure) — 功能设计 → NFR需求 → NFR设计 → 基础设施设计 → 代码生成 → 构建测试
  阶段2（并行）: Unit 2/3/4/5/6 + Unit 1 — 各自 功能设计 → NFR需求 → NFR设计 → 基础设施设计 → 代码生成 → 构建测试
  阶段3: 全链路集成测试
```

---

## 阶段执行计划

### 🔵 启动阶段 (INCEPTION) — ✅ 全部完成
- [x] 工作区检测 — 已完成
- [x] 需求分析 — 已完成
- [x] 用户故事 — 已完成（25个故事，3个用户画像）
- [x] 工作流规划 — 已完成
- [x] 应用设计 — 已完成（组件、方法、服务、依赖关系）
- [x] 工作单元生成 — 已完成（7个工作单元：前端SPA + 4个微服务 + API网关 + 基础设施）

### 🟢 构建阶段 (CONSTRUCTION) — ⏳ 进行中

#### 阶段 1（先行）: Unit 7 — infrastructure ✅
- [x] 功能设计
- [x] NFR需求
- [x] NFR设计
- [x] 基础设施设计
- [x] 代码生成 — ⏭️ 跳过（用户选择先完成所有 Unit 设计）
- [x] 构建和测试 — ⏭️ 跳过（用户选择先完成所有 Unit 设计）

#### 阶段 2（并行）: Unit 2/3/4/5/6 + Unit 1

Unit 2 (auth-service):
- [x] 功能设计
- [x] NFR需求
- [x] NFR设计
- [x] 基础设施设计
- [ ] 代码生成
- [ ] 构建和测试

Unit 3 (product-service):
- [x] 功能设计
- [x] NFR需求
- [x] NFR设计
- [x] 基础设施设计
- [ ] 代码生成
- [ ] 构建和测试

Unit 4 (points-service):
- [x] 功能设计
- [x] NFR需求
- [x] NFR设计
- [x] 基础设施设计
- [ ] 代码生成
- [ ] 构建和测试

Unit 5 (order-service):
- [x] 功能设计
- [x] NFR需求
- [x] NFR设计
- [x] 基础设施设计
- [ ] 代码生成
- [ ] 构建和测试

Unit 6 (api-gateway):
- [x] 功能设计
- [x] NFR需求
- [x] NFR设计
- [x] 基础设施设计
- [ ] 代码生成
- [ ] 构建和测试

Unit 1 (awsomeshop-frontend):
- [x] 功能设计
- [x] NFR需求
- [x] NFR设计
- [x] 基础设施设计
- [ ] 代码生成
- [ ] 构建和测试

#### 阶段 3: 集成测试
- [ ] 全链路集成测试

### 🟡 运维阶段 (OPERATIONS)
- [ ] 运维 — 占位（未来扩展）

---

## 成功标准
- **主要目标**: 交付可运行的 AWSomeShop MVP，验证员工积分兑换商业模式
- **关键交付物**:
  - 前后端分离的 Web 应用
  - MySQL 数据库及初始化脚本
  - Docker 容器化部署配置
  - API 文档
  - 单元测试
- **质量门禁**:
  - 所有 Must Have 用户故事的验收标准通过
  - 安全认证机制正常工作
  - Docker 一键启动成功
