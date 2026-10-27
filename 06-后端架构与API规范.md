# 06 后端架构与 API 规范

## 1. 目标

- 一套 API 同时服务 Web、H5、飞书、A2A、OpenAPI。
- 契约稳定、可生成 SDK、可自动化测试。
- 长连接不拖垮数据库；慢任务不阻塞请求。
- 权限、审计、幂等、软删成为默认能力，而不是事后补。

---

## 2. 技术栈

| 层 | 选型 |
|---|---|
| 语言 | Python 3.12 |
| 框架 | FastAPI |
| 校验 | Pydantic v2 |
| ORM | SQLAlchemy 2（async） |
| 迁移 | Alembic |
| DB | MySQL 8 |
| 缓存/流 | Redis 7 |
| 队列 | ARQ / Redis Streams（起步） |
| 观测 | OpenTelemetry + Prometheus |
| 测试 | pytest + httpx + testcontainers |

---

## 3. 分层与依赖

```
api/          # 路由：鉴权、参数、响应；不写业务
services/     # 业务编排、事务边界、跨聚合协调
repositories/ # SQL、缓存；不写业务规则
domain/       # 实体、值对象、规则、枚举
integrations/ # SSO/LLM/OSS/飞书/GitLab/E2B
schemas/      # 请求/响应 DTO
core/         # 配置、异常、日志、依赖
workers/      # 异步任务
```

**规则**
- 路由不直接查库；service 不直接拼 SQL；repository 不抛 HTTP 异常。
- 事务在 service 层开启；跨服务用「本地消息表 + 重试」而非分布式事务。
- 所有外部调用有超时、重试、熔断、错误分类。

---

## 4. API 规范

### 4.1 命名与风格

| 项 | 约定 |
|---|---|
| 前缀 | `/api`（前端）、`/api/v1`（开放 API） |
| 资源 | 复数名词，kebab-case：`/llm-configs`、`/model-quota-pools` |
| 动作 | 子资源或动词：`/agents/{id}/invoke`、`/chat/cancel` |
| 方法 | GET 查询、POST 创建/动作、PUT 全量更新、PATCH 局部、DELETE 删除 |
| 时间 | ISO 8601，UTC 存储，前端本地化 |
| ID | 字符串（UUID/ULID），不暴露自增 |
| 分页 | `page`、`page_size`（默认 20，最大 100）；返回 `items,total,page,page_size` |
| 排序 | `sort_by`、`order=asc|desc`；白名单字段 |
| 过滤 | 明确参数，不用通用 query DSL |
| 软删 | 默认过滤；管理员可用 `include_deleted=true` |

### 4.2 统一响应

```json
{
  "code": 0,
  "message": "ok",
  "data": {},
  "request_id": "req_01H..."
}
```

- 成功：HTTP 2xx，`code=0`。
- 失败：HTTP 4xx/5xx，`code` 为业务码，`message` 可直接展示，`detail` 为结构化字段错误。
- 流式接口不包 envelope，直接 SSE。

### 4.3 错误码

| HTTP | code | 场景 |
|---|---|---|
| 400 | `invalid_argument` | 参数错误 |
| 401 | `unauthenticated` | 未登录/ token 失效 |
| 403 | `permission_denied` | 无权限 |
| 403 | `permission_audit_grant_required` | 需要临时授权（参考系统） |
| 404 | `not_found` | 资源不存在/不可见 |
| 409 | `conflict` | 唯一性/状态冲突 |
| 422 | `validation_error` | 字段校验 |
| 429 | `rate_limited` | 限流/配额 |
| 500 | `internal_error` | 未预期 |
| 503 | `dependency_unavailable` | 模型/沙箱/飞书不可用 |

**原则**：不泄露内部堆栈；错误信息包含 `request_id`；敏感字段不回显。

### 4.4 幂等

- 创建类支持 `Idempotency-Key` header，Redis 存 24h。
- 取消/暂停/恢复/删除天然幂等。
- 支付/配额扣减用「唯一业务键 + 事务」防重。
- 重试只对幂等请求自动进行（GET/PUT/DELETE/带 key 的 POST）。

### 4.5 乐观锁

- 配置类资源带 `version` 或 `expected_config_version`。
- 更新时版本不匹配返回 409，前端提示「配置已变更，请刷新」。
- 配额池切换模式必须带 `expected_config_version` + `reason`。

---

## 5. 鉴权与依赖注入

```python
async def get_current_user(token=Depends(bearer)) -> User: ...
async def require_permission(code: str): ...
async def require_resource_access(resource, action): ...
```

| 通道 | 识别方式 | 用途 |
|---|---|---|
| Web JWT | `Authorization: Bearer <jwt>` | 前端 |
| API Key | `app_id` + 签名 headers | 系统集成 |
| A2A | Bearer token | Agent 间 |
| 内部回调 | 签名 + 时间窗 + nonce | 沙箱/异步任务 |
| Bridge | 宿主 token（短期） | 嵌入 |

**资源级校验顺序**：登录 → 功能权限 → 资源可见性（owner/collaborator/public）→ 数据范围 → 业务状态。

---

## 6. 事务与一致性

| 场景 | 方案 |
|---|---|
| 创建 Agent + 绑定技能 | 单事务 |
| 删除 Agent + 解绑 | 单事务 + 影响预览 |
| 扣配额 + 记用量 | Redis 原子 Lua + DB 异步落账；对账任务 |
| 发消息 + 写会话 | 先写消息（pending）→ 流式完成更新 |
| 外部回调 | 幂等表 + 状态机 CAS |
| 跨服务事件 | 本地消息表（outbox）+ 轮询投递 |

**状态机**：会话轮次 `idle → running → completed/cancelled/failed`；沙箱 `creating → running → paused → deleted`；任务 `pending → running → done/failed/cancelled`。

---

## 7. SSE 服务端设计

### 7.1 端点

| 端点 | 用途 |
|---|---|
| `POST /conversations/{id}/chat` | 发送消息并流式返回 |
| `GET /conversations/{id}/live` | 断线续传/刷新恢复 |
| `GET /conversations/{id}/active-turn` | 查询是否有活跃轮 |
| `POST /conversations/{id}/chat/cancel` | 取消当前轮 |
| `GET /notifications/stream` | 通知流 |

### 7.2 存储

- `sse:log:{message_id}`：Redis Stream，保留最近 N 条/1h；
- `sse:live:{message_id}`：Pub/Sub，实时广播；
- `session:active_turn:{session_id}`：当前消息 id + 状态；
- 事件 `id` 单调递增，客户端用 `Last-Event-ID` 续传。

### 7.3 连接管理

- 建连时校验一次 token，后续不查 DB；
- 每 15s 心跳；
- 客户端断开后保留 ring buffer 5–10 分钟；
- 不持有 DB 连接；连接数上限按实例配置；
- 多副本通过 Redis Pub/Sub 广播。

### 7.4 背压

- 生产速度 > 消费速度时，合并 token（如 50ms 一批）；
- ring buffer 满时丢弃最旧事件并标记 `truncated=true`；
- 前端收到 `truncated` 后调用消息详情补齐。

---

## 8. 异步任务

| 任务 | 触发 | 重试 |
|---|---|---|
| 沙箱创建/回收 | 用户请求/定时 | 指数退避，最大 5 次 |
| 飞书推送 | 管理端 | 分批 + 断点续传 |
| OSS 盘点 | 定时 | 任务级重试 |
| 审计导出 | 管理端 | 生成文件后通知 |
| 用量聚合 | 定时 | 幂等重算 |
| 通知推送 | 事件 | 至少一次 |

**约定**：任务幂等、可观测、可取消；失败进死信队列；管理端可重试。

---

## 9. 数据访问规范

- 所有查询带 `is_deleted=0`（除管理员）。
- 分页用覆盖索引；避免 `%keyword%` 全表扫，必要时上搜索。
- 大字段（消息内容、工具结果）可拆表/落 OSS。
- 禁止在循环里查库（N+1）；批量用 `IN`。
- 写操作记录 `create_user_id/update_user_id/create_time/update_time`。
- 软删记录 `delete_time/delete_user_id`。
- 不在数据库建 UNIQUE KEY（参考系统规范）；用应用层 + 幂等键 + 读端容忍。

---

## 10. OpenAPI 与 SDK

- Pydantic 模型即契约；`response_model` 必须声明。
- 每个路由有 `summary`、`description`、`tags`。
- CI 检查 OpenAPI diff，破坏性变更需版本升级。
- 前端用 `openapi-typescript` 生成类型；外部提供 OpenAPI 文档与示例。
- 开放 API 单独 `/api/v1`，与内部 API 解耦。

---

## 11. 限流与配额

| 层 | 策略 |
|---|---|
| 网关 | IP/用户 QPS、并发连接数 |
| 应用 | 接口级令牌桶；登录/发送消息/上传单独限 |
| 模型 | TPM 配额池、最大等待、最大排队 |
| 沙箱 | 每用户并发沙箱数、总容量 |
| 导出/盘点 | 单用户同时任务数 |

**返回**：429 + `Retry-After`；配额不足返回明确 `quota_exceeded` + 重置时间。

---

## 12. 日志与审计

| 类型 | 内容 | 去向 |
|---|---|---|
| 访问日志 | 方法、路径、状态、耗时、request_id、user_id | 标准输出 → Loki |
| 应用日志 | 结构化 JSON，禁止密钥/正文 | Loki |
| 审计日志 | 操作人、对象、动作、前后值、IP、UA | DB + 不可篡改存储 |
| 模型调用 | 模型、token、费用、延迟、错误码 | DB/指标 |
| 安全日志 | 登录失败、越权、密钥操作 | SIEM |

**禁止**：日志出现 API Key、用户 token、完整 prompt（可存脱敏摘要）、附件内容。

---

## 13. 测试策略（后端）

| 层 | 工具 | 覆盖 |
|---|---|---|
| 单元 | pytest | 领域规则、权限、配额算法 |
| 集成 | testcontainers（MySQL/Redis） | repository、事务、迁移 |
| 契约 | schemathesis / OpenAPI | 所有端点参数/响应 |
| 端到端 | httpx + mock 外部 | 登录、对话、Skill、沙箱 |
| 压测 | Locust/k6 | 对话并发、SSE 连接、列表 |

**必测**：401/403、软删过滤、幂等、并发锁、SSE 续传、配额边界、外部超时。

---

## 14. 验收标准

- [ ] 所有路由有鉴权依赖、权限码、OpenAPI 描述。
- [ ] 统一错误体与错误码，前端可映射。
- [ ] SSE 断线续传、取消、并发轮次有集成测试。
- [ ] 慢任务全部异步化，不阻塞请求。
- [ ] 数据库迁移可向前/向后兼容。
- [ ] 日志不泄露密钥与敏感正文。
