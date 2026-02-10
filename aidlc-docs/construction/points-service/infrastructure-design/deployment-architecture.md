# Unit 4: points-service — 部署架构

---

## 1. 部署拓扑

```
┌─────────────────────────────────────────────────────────────────┐
│                    Docker Host (开发机)                           │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │              awsomeshop-net (bridge network)              │   │
│  │                                                           │   │
│  │  ┌─────────────┐    ┌──────────────┐                     │   │
│  │  │  nginx       │    │ api-gateway  │                     │   │
│  │  │  :80 → :8080 │───→│  :8080       │                     │   │
│  │  └─────────────┘    └──────┬───────┘                     │   │
│  │                            │                              │   │
│  │         ┌──────────────────┼──────────────────┐          │   │
│  │         │                  │                  │          │   │
│  │         ▼                  ▼                  ▼          │   │
│  │  ┌─────────────┐  ┌──────────────┐  ┌──────────────┐   │   │
│  │  │auth-service  │  │product-service│  │points-service│   │   │
│  │  │  :8001       │  │  :8002       │  │  :8003       │   │   │
│  │  └──────┬──────┘  └──────┬───────┘  └──────┬───────┘   │   │
│  │         │                │                  │           │   │
│  │         │    ┌───────────┴──────────────────┘           │   │
│  │         │    │                                          │   │
│  │         ▼    ▼                                          │   │
│  │  ┌──────────────┐                                       │   │
│  │  │    mysql      │                                       │   │
│  │  │  :3306        │                                       │   │
│  │  │  ├─ auth_db   │                                       │   │
│  │  │  ├─ product_db│                                       │   │
│  │  │  ├─ points_db │                                       │   │
│  │  │  └─ order_db  │                                       │   │
│  │  └──────────────┘                                       │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                  │
│  端口映射: 宿主机:80 → nginx:80                                   │
│           宿主机:3306 → mysql:3306                                │
└─────────────────────────────────────────────────────────────────┘
```

---

## 2. 端口分配汇总

| 服务 | 内部端口 | 对外暴露 | 说明 |
|------|---------|---------|------|
| nginx | 80 | 是（:80） | 前端静态文件 + 反向代理 |
| api-gateway | 8080 | 否 | 统一 API 入口 |
| auth-service | 8001 | 否 | 认证服务 |
| product-service | 8002 | 否 | 产品服务 |
| points-service | 8003 | 否 | 积分服务 |
| order-service | 8004 | 否 | 兑换服务 |
| mysql | 3306 | 是（:3306） | 数据库（开发调试用） |

---

## 3. 启动流程

```
1. mysql 启动
   └── healthcheck: mysqladmin ping（通过后标记 healthy）

2. 微服务并行启动（depends_on mysql: service_healthy）
   ├── auth-service (:8001)
   ├── product-service (:8002)
   └── points-service (:8003)
       └── healthcheck: curl http://localhost:8003/actuator/health

3. api-gateway 启动（depends_on 各微服务: service_healthy）

4. nginx 启动（depends_on api-gateway）
```

---

## 4. 请求流转路径

### 路径 1: 员工查询积分余额
```
浏览器 → nginx:80
  → /api/points/balance
  → api-gateway:8080（JWT 校验）
  → points-service:8003 GET /api/points/balance
  → mysql:3306 (points_db.point_balances)
  → 返回 PointBalanceResponse
```

### 路径 2: 员工查询积分历史
```
浏览器 → nginx:80
  → /api/points/transactions?page=0&size=20
  → api-gateway:8080（JWT 校验）
  → points-service:8003 GET /api/points/transactions
  → mysql:3306 (points_db.point_transactions)
  → 返回 PageResponse<PointTransactionResponse>
```

### 路径 3: 管理员手动调整积分
```
浏览器 → nginx:80
  → /api/admin/points/adjust
  → api-gateway:8080（JWT 校验 + 管理员角色校验）
  → points-service:8003 POST /api/admin/points/adjust
  → mysql:3306 (SELECT FOR UPDATE → UPDATE → INSERT)
  → 返回 PointTransactionResponse
```

### 路径 4: 管理员查看/更新发放配置
```
浏览器 → nginx:80
  → /api/admin/points/config
  → api-gateway:8080（JWT 校验 + 管理员角色校验）
  → points-service:8003 GET/PUT /api/admin/points/config
  → mysql:3306 (points_db.system_configs)
  → 返回 DistributionConfigResponse
```

### 路径 5: 用户注册时积分初始化（内部调用）
```
auth-service:8001
  → POST http://points-service:8003/api/internal/points/init
  → mysql:3306 (INSERT point_balances)
  → 返回 PointBalanceResponse
  （失败时 auth-service 降级处理，注册仍成功）
```

### 路径 6: 兑换扣除积分（内部调用）
```
order-service:8004
  → POST http://points-service:8003/api/internal/points/deduct
  → mysql:3306 (SELECT FOR UPDATE → UPDATE → INSERT)
  → 返回 PointTransactionResponse
```

### 路径 7: 兑换回滚积分（内部调用）
```
order-service:8004
  → POST http://points-service:8003/api/internal/points/rollback
  → mysql:3306 (查询原始记录 → SELECT FOR UPDATE → UPDATE → INSERT)
  → 返回成功
```

### 路径 8: 定时任务自动发放
```
points-service:8003 内部 cron 触发（每月1日 02:00）
  → 查询 system_configs（发放额度）
  → 查询 point_balances（所有用户）
  → 创建 distribution_batches 记录
  → 逐条发放：UPDATE point_balances + INSERT point_transactions
  → 更新 distribution_batches 状态
```

---

## 5. 故障恢复

### points-service 容器重启
- Docker Compose `restart: unless-stopped`（如配置）
- 重启后 healthcheck 通过前，api-gateway 路由到该服务的请求会失败
- auth-service 注册时调用失败 → 降级处理
- order-service 兑换时调用失败 → 事务回滚，提示用户重试
- 定时任务：重启后检查 RUNNING 状态的发放批次，执行补发

### MySQL 重启
- points-service 依赖 MySQL 健康检查
- 数据库连接池自动重连（依赖后端框架实现）

---

## 6. 开发调试

### 查看积分数据
```bash
# 连接 MySQL 查看积分余额
mysql -h 127.0.0.1 -P 3306 -u points_user -p points_db

# 查看所有余额
SELECT * FROM point_balances;

# 查看积分流水
SELECT * FROM point_transactions ORDER BY created_at DESC LIMIT 20;

# 查看发放批次
SELECT * FROM distribution_batches ORDER BY started_at DESC;

# 查看发放配置
SELECT * FROM system_configs WHERE config_key = 'points.distribution.amount';
```

### 测试内部接口
```bash
# 初始化积分（模拟 auth-service 调用）
curl -X POST http://localhost:8003/api/internal/points/init \
  -H "Content-Type: application/json" \
  -d '{"userId": 1}'

# 查询余额（模拟 order-service 调用）
curl http://localhost:8003/api/internal/points/balance/1
```

> 注意：内部接口在 Docker 网络内可直接访问。如需从宿主机测试，需临时暴露 points-service 端口或使用 `docker exec` 进入容器。
