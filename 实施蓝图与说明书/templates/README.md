# Templates

可直接复制到新项目的启动模板。

| 文件 | 用途 |
|---|---|
| `docker-compose.yml` | 本地 MySQL/Redis/MinIO/API/Runtime/Web |
| `.env.example` | 全部环境变量基线 |
| `schema.sql` | MySQL 核心表 DDL + 种子 |
| `helm-values.yaml` | K8s 部署基线 |
| `Makefile` | 安装/迁移/启动/测试/构建/部署 |
| `nginx.conf` | SPA + API + SSE 反向代理 |

## 快速使用

```bash
# 1. 复制模板到新仓库
cp -r templates/* ./cloud-agent-platform/

# 2. 改 .env
cp .env.example .env

# 3. 起基础设施
docker compose up -d mysql redis minio

# 4. 初始化
make install
make migrate
make seed
make api
make runtime
make web
```

## 注意

- `schema.sql` 是「起步版」，不是完整生产 schema；按 46 文档补齐。
- `nginx.conf` 的 SSE 配置是必须的，否则流式会被缓冲。
- `helm-values.yaml` 的密钥用 `existingSecret`，不要把密钥写进 values。
- `docker-compose.yml` 的沙箱不包含在内；本地可用 Docker 仅做流程验证，生产必须用强隔离。
