# AWSomeShop 需求验证问题

请回答以下问题，帮助我更好地理解项目需求。
请在每个问题的 [Answer]: 标签后填写您选择的字母。

---

## Question 1
该项目的技术栈偏好是什么？

A) React + Node.js（全栈 JavaScript/TypeScript）
B) React 前端 + Java/Spring Boot 后端
C) Vue.js + Python/Django 后端
D) Next.js 全栈（React + API Routes）
E) Other (please describe after [Answer]: tag below)

[Answer]: 前后端各自都有已经搭建好的技术框架

## Question 2
数据存储方案偏好是什么？

A) 关系型数据库（PostgreSQL/MySQL）
B) NoSQL 文档数据库（DynamoDB/MongoDB）
C) 内存数据库 + 持久化存储组合（Redis + PostgreSQL）
D) 无服务器数据库（如 Aurora Serverless）
E) Other (please describe after [Answer]: tag below)

[Answer]: MySQL

## Question 3
员工认证/登录方式是什么？

A) 公司内部 SSO（单点登录）集成
B) 用户名 + 密码（独立认证系统）
C) 基于 AWS Cognito 的认证
D) MVP 阶段暂不实现认证，使用模拟登录
E) Other (please describe after [Answer]: tag below)

[Answer]: B

## Question 4
"AWSome积分"的初始发放机制是什么？

A) 管理员手动为每位员工设置初始积分
B) 系统自动按固定额度定期发放（如每月）
C) 管理员批量导入积分（如通过 CSV 文件）
D) MVP 阶段每位员工预设固定积分额度
E) Other (please describe after [Answer]: tag below)

[Answer]: B

## Question 5
产品目录的规模预期是多少？

A) 小型（10-50 个产品）
B) 中型（50-200 个产品）
C) 大型（200+ 个产品）
D) MVP 阶段先上线少量产品（< 10 个），后续扩展
E) Other (please describe after [Answer]: tag below)

[Answer]: C

## Question 6
兑换流程是否需要物流/配送管理？

A) 需要，包含完整的订单配送跟踪
B) 仅需要简单的订单状态（已兑换/已完成）
C) 线下自取，系统只记录兑换信息
D) MVP 阶段不需要物流，仅记录兑换记录
E) Other (please describe after [Answer]: tag below)

[Answer]: C

## Question 7
系统的部署环境偏好是什么？

A) AWS 云服务（EC2/ECS/Lambda 等）
B) 本地 Docker 容器化部署
C) 无服务器架构（AWS Lambda + API Gateway）
D) MVP 阶段本地运行，后续迁移到云端
E) Other (please describe after [Answer]: tag below)

[Answer]: B

## Question 8
MVP 的目标用户规模是多少？

A) 小团队试点（< 50 人）
B) 部门级别（50-200 人）
C) 公司级别（200-1000 人）
D) 大规模（1000+ 人）
E) Other (please describe after [Answer]: tag below)

[Answer]: D

## Question 9
是否需要产品分类功能？

A) 需要，支持多级分类（如：电子产品 > 耳机）
B) 需要，但仅支持单级分类（如：电子产品、办公用品）
C) 不需要分类，所有产品平铺展示
D) MVP 阶段不需要，后续迭代添加
E) Other (please describe after [Answer]: tag below)

[Answer]: A

## Question 10
管理员界面的需求是什么？

A) 独立的管理后台页面（与员工端分离）
B) 在同一应用中通过角色权限区分管理功能
C) 使用命令行工具或脚本管理
D) MVP 阶段使用简单的管理页面，后续完善
E) Other (please describe after [Answer]: tag below)

[Answer]: B
