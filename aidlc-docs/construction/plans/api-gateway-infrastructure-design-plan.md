# Unit 6: api-gateway — 基础设施设计计划

---

## 执行步骤

- [x] 步骤 1: 分析前序设计文档
- [x] 步骤 2: 收集用户回答
- [x] 步骤 3: 生成基础设施设计文档
- [x] 步骤 4: 生成部署架构文档
- [x] 步骤 5: 更新 Unit 7 Docker Compose 配置

---

## 设计问题

### Q1: 服务端口配置
api-gateway 需要配置内部服务端口。根据现有服务端口分配：
- auth-service: 8001
- product-service: 8002
- points-service: 8003
- order-service: 8004

api-gateway 的内部端口应该是？

A) 8080（与对外暴露端口一致，简化配置）
B) 8005（延续端口递增规则）

[Answer]: A

---

### Q2: 健康检查端点
api-gateway 是否配置健康检查端点？

A) 是，配置 /actuator/health（与其他微服务一致）
B) 是，配置 /health（简化路径）
C) 否，api-gateway 无状态，不需要健康检查

[Answer]: A

---

### Q3: 下游服务地址配置
Unit 7 Docker Compose 中 api-gateway 的下游服务地址需要更新。当前配置：
```yaml
AUTH_SERVICE_URL: http://auth-service:8080
PRODUCT_SERVICE_URL: http://product-service:8080
POINTS_SERVICE_URL: http://points-service:8080
ORDER_SERVICE_URL: http://order-service:8004
```

需要更新为各服务的实际端口。确认是否按以下配置更新？

A) 是，更新为：
   - AUTH_SERVICE_URL: http://auth-service:8001
   - PRODUCT_SERVICE_URL: http://product-service:8002
   - POINTS_SERVICE_URL: http://points-service:8003
   - ORDER_SERVICE_URL: http://order-service:8004

[Answer]: A

---

## 回答完成后
请在上方 [Answer]: 后填写您的选择（如 A、B 或 C），然后回复"回答完成"。
