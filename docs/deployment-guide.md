# AWSome Shop 部署指南

## 架构总览

全部后端服务运行在 **AWS 原生托管服务**上，零服务器管理，全链路可观测。

```
用户 --> CloudFront (CDN/HTTPS) --> WAF (WebACL) --> ALB --> ECS Fargate
                                                              |
                         +----------+----------+---------+----+
                         |          |          |         |
                       Gateway    Auth     Product    Points    Order
                       (公网)    (内部)     (内部)     (内部)    (内部)
                                   |          |         |         |
                                   +-----+----+---------+---------+
                                         |              |
                                    RDS MySQL    ElastiCache Redis
```

## AWS 原生服务一览

| 层级 | 服务 | 用途 |
|------|------|------|
| CDN 与 HTTPS | **Amazon CloudFront** | 全球边缘缓存、SSL 终止 |
| 安全防护 | **AWS WAF** | CloudFront 请求头校验、IP 白名单、请求过滤 |
| 负载均衡 | **Application Load Balancer** | 七层路由分发、健康检查 |
| 容器计算 | **AWS ECS Fargate** | 无服务器容器编排，无需管理 EC2 |
| 镜像仓库 | **Amazon ECR** | 私有 Docker 镜像存储 |
| 服务发现 | **AWS Cloud Map** | 基于 DNS 的服务发现（`*.dev.awsome-shop.local`） |
| 数据库 | **Amazon RDS MySQL** | 托管关系型数据库，多服务共享 |
| 缓存 | **Amazon ElastiCache Redis** | 会话缓存、分布式锁 |
| 密钥管理 | **AWS SSM Parameter Store** | 运行时加密注入敏感配置 |
| 基础设施即代码 | **AWS CloudFormation** | 全部基础设施代码化，由 Copilot 管理 |
| 部署工具 | **AWS Copilot CLI** | ECS 专用部署框架，一键发布 |

## 服务拓扑

| 服务 | 角色 | 端口 | Copilot 类型 |
|------|------|------|-------------|
| gateway | 公网入口 | 8080 | Load Balanced Web Service |
| auth | 内部服务 | 8001 | Backend Service |
| product | 内部服务 | 8002 | Backend Service |
| points | 内部服务 | 8003 | Backend Service |
| order | 内部服务 | 8004 | Backend Service |

所有后端服务规格：**4 vCPU / 8 GB 内存**，Spring Boot + JRE 21。

## 安全链路

```
请求 --> CloudFront
           |
           | 注入 X-CloudFront-Secret 请求头
           v
         WAF WebACL
           |
           +-- 规则 1: CloudFront 密钥头匹配则放行    (优先级 1)
           +-- 规则 2: IP 白名单匹配则放行            (优先级 2)
           +-- 规则 3: /actuator/health 放行          (优先级 3)
           +-- 默认: 拒绝所有其他流量
           |
           v
          ALB --> Gateway --> JWT 校验 --> 后端微服务
```

## 项目结构

```
copilot/
  environments/dev/manifest.yml     # VPC + ECS 集群
  gateway/
    manifest.yml                    # 公网负载均衡服务
    addons/waf.yml                  # WAF 规则 (CloudFormation)
  auth/manifest.yml                 # 内部后端服务
  product/manifest.yml              # 内部后端服务
  points/manifest.yml               # 内部后端服务
  order/manifest.yml                # 内部后端服务
```

## 密钥管理 (SSM Parameter Store)

```
/copilot/awsome-shop/dev/secrets/
  jwt-secret        # JWT 签名密钥
  encryption-key    # 数据加密密钥
  db-host           # RDS 连接地址
  db-port           # RDS 端口
  db-username       # RDS 用户名
  db-password       # RDS 密码
```

## 部署命令

```bash
# 一键部署全部服务
./scripts/deploy.sh dev

# 部署单个服务
copilot svc deploy --name auth --env dev

# 按顺序部署全部
for svc in auth product points order gateway; do
  copilot svc deploy --name $svc --env dev
done
```

部署流水线：`copilot svc deploy` --> Docker 构建 --> 推送至 ECR --> CloudFormation 变更集 --> ECS 滚动部署 --> 健康检查通过 --> 完成

## 运维操作

```bash
# 查看服务状态
copilot svc status --name auth --env dev

# 实时日志
copilot svc logs --name auth --env dev --follow

# 进入容器调试 (ECS Exec，基于 SSM)
copilot svc exec --name auth --env dev

# 查看环境概览
copilot env show --name dev
```
