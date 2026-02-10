# Unit 7: infrastructure — 非功能性需求

---

## 1. 数据库可靠性与持久化

| 需求ID | 描述 | 优先级 |
|--------|------|--------|
| NFR-INFRA-001 | MySQL 数据通过 Docker named volume 持久化，容器重启不丢失数据 | Must Have |
| NFR-INFRA-002 | MySQL 数据卷挂载到宿主机目录，便于宿主机层面的文件系统备份 | Must Have |
| NFR-INFRA-003 | 数据库初始化脚本幂等执行，重复运行不产生错误 | Must Have |
| NFR-INFRA-004 | 每个微服务使用独立的数据库用户，仅授权访问自己的 database | Must Have |

## 2. 容器运行环境

| 需求ID | 描述 | 优先级 |
|--------|------|--------|
| NFR-INFRA-005 | 使用 Docker Compose 一键启动所有服务 | Must Have |
| NFR-INFRA-006 | 服务启动顺序通过 depends_on + healthcheck 控制 | Must Have |
| NFR-INFRA-007 | MySQL 健康检查确保数据库就绪后再启动微服务 | Must Have |
| NFR-INFRA-008 | MVP 阶段不设置容器资源限制（CPU/内存），简化配置 | — |
| NFR-INFRA-009 | 产品图片存储通过 Docker volume 持久化 | Must Have |

## 3. 安全配置

| 需求ID | 描述 | 优先级 |
|--------|------|--------|
| NFR-INFRA-010 | 所有敏感配置（密码、密钥）通过环境变量注入，不硬编码 | Must Have |
| NFR-INFRA-011 | 仅 API 网关端口（8080）和前端端口（80）暴露到宿主机 | Must Have |
| NFR-INFRA-012 | MySQL 端口（3306）暴露到宿主机仅用于开发调试，生产环境应关闭 | Should Have |
| NFR-INFRA-013 | 提供 .env.example 模板，生产环境必须更换所有默认密码和密钥 | Must Have |
| NFR-INFRA-014 | Docker 网络隔离，微服务仅在内部网络通信 | Must Have |

## 4. 日志与可观测性

| 需求ID | 描述 | 优先级 |
|--------|------|--------|
| NFR-INFRA-015 | 日志管理由后端技术框架自身的日志规范处理，infrastructure 层不做额外日志配置 | — |
| NFR-INFRA-016 | 各微服务日志输出到 stdout/stderr，可通过 docker logs 查看 | Must Have |

## 5. 可维护性

| 需求ID | 描述 | 优先级 |
|--------|------|--------|
| NFR-INFRA-017 | Docker Compose 配置清晰注释，便于理解和修改 | Should Have |
| NFR-INFRA-018 | 环境变量集中管理在 .env 文件中 | Must Have |
| NFR-INFRA-019 | 数据库初始化脚本按服务分文件，便于独立维护 | Should Have |
