# Unit 1: awsomeshop-frontend — 基础设施设计

---

## 1. 容器配置

### 1.1 基本信息

| 配置项 | 值 |
|--------|-----|
| 服务名 | frontend |
| 容器名 | awsomeshop-frontend |
| 基础镜像 | nginx:alpine |
| 对外端口 | 3000 |
| 内部端口 | 80 |

### 1.2 Dockerfile

```dockerfile
# awsomeshop-frontend/Dockerfile

# 阶段1: 构建
FROM node:20-alpine AS builder

WORKDIR /app

# 复制依赖文件
COPY package*.json ./

# 安装依赖
RUN npm ci

# 复制源代码
COPY . .

# 构建生产版本
RUN npm run build

# 阶段2: 运行
FROM nginx:alpine

# 复制构建产物到 Nginx 目录
COPY --from=builder /app/dist /usr/share/nginx/html

# 暴露端口
EXPOSE 80

# 启动 Nginx
CMD ["nginx", "-g", "daemon off;"]
```

说明：
- 使用多阶段构建，减小最终镜像体积
- 构建阶段使用 Node.js 20 Alpine
- 运行阶段使用 Nginx Alpine（约 40MB）
- 构建产物目录 `dist`（具体目录名在实现阶段根据框架确定）

---

## 2. Nginx 配置

### 2.1 完整配置文件

```nginx
# infrastructure/nginx/default.conf

server {
    listen 80;
    server_name localhost;

    root /usr/share/nginx/html;
    index index.html;

    # Gzip 压缩
    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml;
    gzip_min_length 1000;

    # SPA 路由：所有非文件请求回退到 index.html
    location / {
        try_files $uri $uri/ /index.html;
    }

    # API 反向代理：/api/* → api-gateway:8080
    location /api/ {
        proxy_pass http://api-gateway:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # 超时配置
        proxy_connect_timeout 10s;
        proxy_read_timeout 30s;

        # 文件上传大小限制
        client_max_body_size 10m;
    }

    # 静态资源：开发阶段不缓存
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires -1;
        add_header Cache-Control "no-cache, no-store, must-revalidate";
        add_header Pragma "no-cache";
    }

    # 健康检查端点
    location /health {
        access_log off;
        return 200 "OK";
        add_header Content-Type text/plain;
    }
}
```

### 2.2 配置说明

| 配置项 | 说明 |
|--------|------|
| SPA 路由 | `try_files` 将所有非文件请求回退到 index.html |
| API 代理 | `/api/*` 转发到 `api-gateway:8080`，避免跨域 |
| Gzip | 启用压缩，减少传输体积 |
| 缓存策略 | 开发阶段不缓存，方便调试 |
| 健康检查 | `/health` 端点返回 200 OK |
| 文件上传 | 最大 10MB（产品图片上传） |

---

## 3. Docker Compose 服务定义

```yaml
frontend:
  build:
    context: ../awsomeshop-frontend
  container_name: awsomeshop-frontend
  ports:
    - "${FRONTEND_PORT:-3000}:80"
  depends_on:
    - api-gateway
  volumes:
    - ./nginx/default.conf:/etc/nginx/conf.d/default.conf:ro
  healthcheck:
    test: ["CMD", "curl", "-f", "http://localhost/health"]
    interval: 15s
    timeout: 5s
    retries: 3
    start_period: 10s
  networks:
    - awsomeshop-net
```

---

## 4. 环境变量

| 变量名 | 默认值 | 说明 |
|--------|--------|------|
| FRONTEND_PORT | 3000 | 前端对外暴露端口 |

说明：
- 前端为静态资源，运行时无需环境变量
- API 地址通过 Nginx 反向代理配置，无需前端配置

---

## 5. 服务依赖

```
frontend
    └── depends_on: api-gateway
            └── depends_on: auth-service, product-service, points-service, order-service
                    └── depends_on: mysql (condition: service_healthy)
```

启动顺序：
1. mysql（等待健康检查通过）
2. auth-service, product-service, points-service, order-service（并行启动）
3. api-gateway
4. frontend

---

## 6. 健康检查

| 配置项 | 值 |
|--------|-----|
| 检查端点 | http://localhost/health |
| 检查间隔 | 15 秒 |
| 超时时间 | 5 秒 |
| 重试次数 | 3 次 |
| 启动等待 | 10 秒 |

---

## 7. 网络配置

| 配置项 | 值 |
|--------|-----|
| 网络名 | awsomeshop-net |
| 网络驱动 | bridge |
| 内部通信 | 通过服务名访问（如 api-gateway:8080） |

---

## 8. 数据卷

前端服务无需持久化数据卷。

Nginx 配置文件通过只读挂载：
```yaml
volumes:
  - ./nginx/default.conf:/etc/nginx/conf.d/default.conf:ro
```

---

## 9. 目录结构

```
awsomeshop-frontend/
├── Dockerfile              # 多阶段构建配置
├── package.json            # 依赖配置
├── src/                    # 源代码（实现阶段创建）
│   ├── components/
│   ├── pages/
│   ├── services/
│   ├── stores/
│   ├── router/
│   ├── hooks/
│   ├── utils/
│   ├── types/
│   ├── assets/
│   ├── App.tsx
│   └── main.tsx
├── public/                 # 静态资源
│   └── favicon.ico
└── dist/                   # 构建产物（构建后生成）
```

---

## 10. 开发环境配置

开发时可使用前端开发服务器（如 Vite dev server），通过代理配置访问后端：

```javascript
// vite.config.js 示例
export default {
  server: {
    port: 3000,
    proxy: {
      '/api': {
        target: 'http://localhost:8080',
        changeOrigin: true
      }
    }
  }
}
```

生产环境使用 Docker 部署，通过 Nginx 反向代理。
