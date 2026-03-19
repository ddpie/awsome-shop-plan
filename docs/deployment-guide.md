# AWSomeShop 部署方案

## 1. 整体架构

```mermaid
graph LR
    User([用户]) -->|HTTPS| CF[CloudFront<br/>CDN + HTTPS]
    CF -->|X-CloudFront-Secret| WAF[AWS WAF<br/>WebACL]
    WAF --> ALB[Application<br/>Load Balancer]
    ALB --> GW[Gateway<br/>:8080]

    GW -->|JWT 验证 + 路由| Auth[Auth Service<br/>:8001]
    GW --> Product[Product Service<br/>:8002]
    GW --> Points[Points Service<br/>:8003]
    GW --> Order[Order Service<br/>:8004]

    Auth -.->|查询积分| Points
    Order -.->|查询商品| Product
    Order -.->|扣除/回滚积分| Points

    Auth --> RDS[(RDS MySQL)]
    Product --> RDS
    Points --> RDS
    Order --> RDS

    Auth --> Redis[(ElastiCache<br/>Redis)]
    Points --> Redis
    Order --> Redis

    subgraph VPC
        ALB
        GW
        Auth
        Product
        Points
        Order
        RDS
        Redis
    end

    style CF fill:#ff9900,color:#fff
    style WAF fill:#dd3522,color:#fff
    style ALB fill:#8c4fff,color:#fff
    style GW fill:#2ea44f,color:#fff
    style Auth fill:#0969da,color:#fff
    style Product fill:#0969da,color:#fff
    style Points fill:#0969da,color:#fff
    style Order fill:#0969da,color:#fff
    style RDS fill:#3b48cc,color:#fff
    style Redis fill:#dc3545,color:#fff
```

## 2. 部署流程

```mermaid
flowchart TD
    A[开发者执行<br/>copilot svc deploy] --> B[Docker 多阶段构建]
    B --> B1[Maven 编译打包<br/>mvn clean package]
    B1 --> B2[构建 JRE 运行镜像<br/>eclipse-temurin:21-jre]
    B2 --> C[推送镜像到 ECR]
    C --> D[创建 CloudFormation<br/>Change Set]
    D --> E[更新 ECS Task Definition]
    E --> F[ECS 滚动部署]

    F --> F1[启动新任务]
    F1 --> F2{Health Check<br/>/actuator/health}
    F2 -->|通过| F3[注册到 Target Group]
    F2 -->|失败| F4[回滚到旧版本]
    F3 --> F5[停止旧任务]
    F5 --> G[部署完成 ✔]
    F4 --> H[部署失败 ✘]

    style A fill:#0969da,color:#fff
    style B fill:#8c4fff,color:#fff
    style C fill:#ff9900,color:#fff
    style D fill:#ff9900,color:#fff
    style G fill:#2ea44f,color:#fff
    style H fill:#dc3545,color:#fff
```

单个服务部署耗时约 5-8 分钟（构建 + 推送 + 滚动更新）。

## 3. 安全架构

```mermaid
flowchart TD
    Req([外部请求]) --> CF[CloudFront]
    CF -->|注入 X-CloudFront-Secret 头| WAF{WAF 规则检查}

    WAF -->|规则1: 验证 CloudFront 密钥头| Allow1[✔ Allow]
    WAF -->|规则2: IP 白名单匹配| Allow2[✔ Allow]
    WAF -->|规则3: /actuator/health| Allow3[✔ Allow]
    WAF -->|默认: 其他请求| Block[✘ Block]

    Allow1 --> ALB[ALB]
    Allow2 --> ALB
    Allow3 --> ALB

    ALB --> GW[Gateway]
    GW --> AuthFilter{Auth Filter<br/>检查路由 metadata}

    AuthFilter -->|auth-required: false| Public[直接转发<br/>公开 API]
    AuthFilter -->|auth-required: true| JWT{JWT Token<br/>验证}

    JWT -->|有效| Inject[注入 X-Operator-Id<br/>X-User-Role 头]
    JWT -->|无效/过期| R401[401 Unauthorized]

    Inject --> Backend[Backend Service]

    style CF fill:#ff9900,color:#fff
    style Block fill:#dc3545,color:#fff
    style R401 fill:#dc3545,color:#fff
    style Allow1 fill:#2ea44f,color:#fff
    style Allow2 fill:#2ea44f,color:#fff
    style Allow3 fill:#2ea44f,color:#fff
```

### WAF 规则优先级

| 优先级 | 规则 | 说明 |
|--------|------|------|
| 1 | AllowCloudFront | 验证 `X-CloudFront-Secret` 头 |
| 2 | AllowWhitelistedIPs | IP 白名单放行 |
| 3 | AllowHealthChecks | ALB 健康检查放行 |
| 默认 | Block | 拒绝所有其他请求 |

## 4. 服务间通信

```mermaid
graph TB
    subgraph "API Gateway (公网入口)"
        GW[Gateway :8080]
    end

    subgraph "Backend Services (VPC 内部)"
        Auth[Auth :8001]
        Product[Product :8002]
        Points[Points :8003]
        Order[Order :8004]
    end

    subgraph "Cloud Map DNS 服务发现"
        DNS["*.dev.awsome-shop.local"]
    end

    GW -->|/api/v1/**/auth/**| Auth
    GW -->|/api/v1/**/product/**<br/>/api/v1/**/category/**| Product
    GW -->|/api/v1/**/point/**| Points
    GW -->|/api/v1/**/order/**| Order

    Auth -->|"POST /internal/point/balance<br/>(查询积分余额)"| Points
    Order -->|"POST /internal/product/query<br/>(查询商品信息)"| Product
    Order -->|"POST /internal/point/deduct<br/>POST /internal/point/rollback<br/>(积分扣除与回滚)"| Points

    Auth -.-> DNS
    Product -.-> DNS
    Points -.-> DNS
    Order -.-> DNS

    style GW fill:#2ea44f,color:#fff
    style Auth fill:#0969da,color:#fff
    style Product fill:#0969da,color:#fff
    style Points fill:#0969da,color:#fff
    style Order fill:#0969da,color:#fff
    style DNS fill:#ff9900,color:#fff
```

## 5. Copilot 项目结构

```mermaid
graph TD
    App[awsome-shop<br/>Copilot Application] --> Env[dev Environment<br/>VPC + ECS Cluster]

    Env --> GW["gateway<br/>Load Balanced Web Service<br/>公网 ALB"]
    Env --> Auth["auth<br/>Backend Service<br/>VPC 内部"]
    Env --> Product["product<br/>Backend Service<br/>VPC 内部"]
    Env --> Points["points<br/>Backend Service<br/>VPC 内部"]
    Env --> Order["order<br/>Backend Service<br/>VPC 内部"]

    GW --> WAF_Addon["addons/waf.yml<br/>WAF WebACL"]

    style App fill:#ff9900,color:#fff
    style Env fill:#8c4fff,color:#fff
    style GW fill:#2ea44f,color:#fff
    style Auth fill:#0969da,color:#fff
    style Product fill:#0969da,color:#fff
    style Points fill:#0969da,color:#fff
    style Order fill:#0969da,color:#fff
    style WAF_Addon fill:#dd3522,color:#fff
```

```
copilot/
├── .workspace               # 应用名: awsome-shop
├── environments/
│   └── dev/
│       └── manifest.yml     # 环境配置 (VPC, Cluster)
├── gateway/
│   ├── manifest.yml         # Load Balanced Web Service (公网)
│   └── addons/
│       └── waf.yml          # WAF WebACL 规则
├── auth/
│   └── manifest.yml         # Backend Service (VPC 内部)
├── product/
│   └── manifest.yml         # Backend Service
├── points/
│   └── manifest.yml         # Backend Service
└── order/
    └── manifest.yml         # Backend Service
```

## 6. 环境配置管理

```mermaid
graph LR
    subgraph "Spring Profiles"
        Local["local<br/>localhost:800x"]
        Docker["docker<br/>服务名:800x"]
        ECS["ecs<br/>Cloud Map DNS"]
    end

    subgraph "配置来源"
        YML["application-{profile}.yml<br/>非敏感配置"]
        SSM["SSM Parameter Store<br/>敏感信息"]
        ENV["Environment Variables<br/>Copilot manifest.yml"]
    end

    Local --> YML
    Docker --> YML
    ECS --> YML
    ECS --> SSM
    ECS --> ENV

    style Local fill:#2ea44f,color:#fff
    style Docker fill:#0969da,color:#fff
    style ECS fill:#ff9900,color:#fff
    style SSM fill:#dd3522,color:#fff
```

| Profile | 用途 | 服务发现方式 |
|---------|------|------------|
| local | 本地开发 | `localhost:800x` |
| docker | Docker Compose | Docker 服务名:800x |
| ecs | ECS Fargate | Cloud Map DNS |

### 敏感信息 (SSM Parameter Store)

```
/copilot/awsome-shop/dev/secrets/jwt-secret
/copilot/awsome-shop/dev/secrets/encryption-key
/copilot/awsome-shop/dev/secrets/db-host
/copilot/awsome-shop/dev/secrets/db-port
/copilot/awsome-shop/dev/secrets/db-username
/copilot/awsome-shop/dev/secrets/db-password
```

## 7. 技术栈

| 组件 | 技术 |
|------|------|
| 容器编排 | AWS ECS Fargate |
| 部署工具 | AWS Copilot CLI（底层 CloudFormation） |
| 服务发现 | AWS Cloud Map（DNS: `*.dev.awsome-shop.local`） |
| CDN & HTTPS | Amazon CloudFront |
| 安全防护 | AWS WAF WebACL |
| 数据库 | Amazon RDS MySQL |
| 缓存 | Amazon ElastiCache Redis |
| 容器仓库 | Amazon ECR |
| 密钥管理 | AWS SSM Parameter Store |
| 实例规格 | 4 vCPU / 8 GB（每服务） |

## 8. 常用运维命令

```bash
# 部署单个服务
copilot svc deploy --name auth --env dev

# 查看服务状态
copilot svc status --name auth --env dev

# 查看实时日志
copilot svc logs --name auth --env dev --follow

# 进入容器调试 (ECS Exec)
copilot svc exec --name auth --env dev

# 部署全部服务 (逐个执行，不可并行)
for svc in auth product points order gateway; do
  copilot svc deploy --name $svc --env dev
done

# 查看应用概览
copilot app show

# 查看环境信息
copilot env show --name dev
```

