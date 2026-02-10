# Unit 7: infrastructure — 技术选型

---

## 技术栈决策

| 技术 | 选型 | 版本 | 理由 |
|------|------|------|------|
| 数据库 | MySQL | 8.4 (LTS) | 用户选择最新 LTS 版本 |
| 容器化 | Docker + Docker Compose | Docker 24+, Compose V2 | 项目需求指定 Docker 部署 |
| 数据库镜像 | mysql:8.4 | 8.4 | 官方镜像，与选型一致 |

## MySQL 8.4 配置要点

- 默认认证插件：`caching_sha2_password`（MySQL 8.4 默认）
- 字符集：`utf8mb4`，排序规则：`utf8mb4_unicode_ci`
- 时区：容器内设置为 `Asia/Shanghai`
- max_connections：MVP 阶段使用默认值（151），足够支撑开发和测试

## Docker Compose 版本

- 使用 Compose V2 语法（`docker compose` 命令）
- compose.yaml 文件格式（无需指定 version 字段）

## 网络策略

- 单一 bridge 网络 `awsomeshop-net`
- 所有服务加入同一网络，通过服务名 DNS 解析
- 仅 api-gateway:8080 和 frontend:80 映射宿主机端口
- MySQL:3306 映射宿主机端口（开发调试用）

## 数据持久化策略

| 卷 | 类型 | 宿主机路径 | 容器路径 | 用途 |
|----|------|-----------|---------|------|
| mysql-data | named volume | Docker 管理 | /var/lib/mysql | 数据库数据 |
| product-uploads | bind mount | ./uploads | /app/uploads | 产品图片 |

## 日志策略

- infrastructure 层不做额外日志配置
- 各微服务按后端技术框架自身的日志规范输出
- 容器日志通过 `docker logs <service>` 查看
