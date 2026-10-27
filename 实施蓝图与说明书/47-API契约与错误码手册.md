# 47 API 契约与错误码手册

## 1. 通用约定

| 项 | 约定 |
|---|---|
| 前缀 | 内部 `/api`，开放 `/api/v1` |
| 资源 | 复数、kebab-case |
| 方法 | GET/POST/PUT/PATCH/DELETE |
| 时间 | ISO 8601 UTC |
| ID | 字符串（ULID/UUID） |
| 分页 | `page`/`page_size`，返回 `items,total,page,page_size` |
| 排序 | `sort_by`/`order`，白名单 |
| 软删 | 默认过滤；管理员可 `include_deleted` |
| 幂等 | `Idempotency-Key`；取消/删除天然幂等 |
| 乐观锁 | `version`/`expected_config_version` |

---

## 2. 响应格式

```json
{
  "code": 0,
  "message": "ok",
  "data": {},
  "request_id": "req_01H..."
}
```

错误：

```json
{
  "code": "permission_denied",
  "message": "没有访问该资源的权限",
  "detail": {"resource": "agent", "action": "update"},
  "request_id": "req_01H..."
}
```

流式接口不包 envelope。

---

## 3. 错误码

| HTTP | code | 说明 |
|---|---|---|
| 400 | invalid_argument | 参数错误 |
| 401 | unauthenticated | 未登录/过期 |
| 401 | invalid_signature | API Key 签名错误 |
| 401 | nonce_replayed | 重放 |
| 403 | permission_denied | 无权限 |
| 403 | tenant_forbidden | 跨租户 |
| 403 | quota_exceeded | 配额不足（也可 429） |
| 403 | permission_audit_grant_required | 需临时授权 |
| 404 | not_found | 不存在/不可见 |
| 409 | conflict | 唯一/状态冲突 |
| 409 | version_conflict | 乐观锁冲突 |
| 409 | session_busy | 会话有活跃轮 |
| 422 | validation_error | 字段校验 |
| 429 | rate_limited | 限流 |
| 429 | quota_exceeded | 配额 |
| 500 | internal_error | 未预期 |
| 503 | dependency_unavailable | 模型/沙箱/飞书不可用 |
| 504 | timeout | 超时 |

**约定**：`request_id` 必返；敏感错误不暴露内部细节；`Retry-After` 用于 429/503。

---

## 4. 端点目录（按模块）

### 4.1 认证/权限

| 方法 | 路径 | 权限 |
|---|---|---|
| GET | `/auth/sso/config` | 公开 |
| GET | `/auth/callback` | 公开 |
| POST | `/auth/sso/callback` | 公开 |
| POST | `/auth/refresh` | refresh |
| POST | `/auth/logout` | 登录 |
| GET | `/auth/me` | 登录 |
| GET | `/auth/me/permissions` | 登录 |
| GET | `/admin/users` | role:manage |
| PUT | `/admin/users/{username}/roles` | role:manage |
| GET/POST | `/admin/roles` | role:manage |
| PUT/DELETE | `/admin/roles/{id}` | role:manage |
| GET/PUT | `/admin/roles/{id}/permissions` | role:manage |
| GET | `/admin/permissions` | role:manage |
| GET/POST | `/admin/api-keys` | api_key:manage |
| PUT/DELETE | `/admin/api-keys/{id}` | api_key:manage |
| POST | `/admin/api-keys/{id}/regenerate` | api_key:manage |

### 4.2 Agent/Skill

| 方法 | 路径 | 权限 |
|---|---|---|
| GET/POST | `/agents` | agent:view/create |
| GET/PUT/DELETE | `/agents/{id}` | view/update/delete |
| GET/PUT | `/agents/{id}/skills` | view/update |
| GET/PUT | `/agents/{id}/sub-agents` | view/update |
| GET/PUT | `/agents/{id}/llm-configs` | view/update |
| GET/PUT | `/agents/{id}/variables` | view/update |
| GET/PUT | `/agents/{id}/templates` | view/update |
| GET/PUT | `/agents/{id}/quick-starts` | view/update |
| GET/POST | `/agents/{id}/mcp-servers` | view/update |
| GET/POST | `/skills` `/skills/upload` | skill:view/create |
| GET/PUT/DELETE | `/skills/{id}` | view/update/delete |
| POST | `/skills/{id}/evaluate` | skill:update |
| POST | `/skills/{id}/invoke` | skill:invoke |
| GET | `/skills/{id}/versions` | skill:view |
| POST | `/skills/{id}/rollback` | skill:update |
| GET | `/me/skills` | 登录 |

### 4.3 会话/运行时

| 方法 | 路径 | 权限 |
|---|---|---|
| POST | `/conversations` | agent:chat |
| GET | `/conversations` | agent:chat |
| GET/DELETE | `/conversations/{id}` | 登录/owner |
| PATCH | `/conversations/{id}/name` | owner |
| PATCH | `/conversations/{id}/model` | owner |
| PATCH | `/conversations/{id}/thinking` | owner |
| POST | `/conversations/{id}/chat` | agent:chat |
| GET | `/conversations/{id}/live` | agent:chat |
| GET | `/conversations/{id}/active-turn` | agent:chat |
| POST | `/conversations/{id}/chat/cancel` | agent:chat |
| GET | `/conversations/{id}/task-plan` | agent:chat |
| POST | `/conversations/{id}/external-context` | agent:chat |

### 4.4 模型/配额/用量

| 方法 | 路径 | 权限 |
|---|---|---|
| GET | `/llm-configs/providers` | llm_config:view |
| GET/POST | `/llm-configs` | view/manage |
| GET/PUT/DELETE | `/llm-configs/{id}` | view/manage |
| POST | `/llm-configs/ping` | manage |
| POST | `/llm-configs/{id}/ping` | manage |
| POST | `/llm-configs/{id}/capability-impact` | manage |
| GET/POST | `/model-quota-pools` | model_quota_pool:view |
| GET/PUT | `/model-quota-pools/{id}` | view/manage |
| POST | `/model-quota-pools/{id}/confirm` | manage |
| POST | `/model-quota-pools/{id}/mode` | manage |
| GET | `/usage/summary` | usage:view |
| GET | `/usage/by-user` | usage:admin |

### 4.5 沙箱/文件

| 方法 | 路径 | 权限 |
|---|---|---|
| GET/POST | `/sandbox-configs` | sandbox_config:view/manage |
| GET/PUT/DELETE | `/sandbox-configs/{id}` | view/manage |
| GET | `/sandbox-admin/sandboxes` | sandbox:admin |
| POST | `/sandbox-admin/sandboxes/{id}/kill|pause|resume` | sandbox:admin |
| POST | `/sandbox-tasks` | 登录 |
| GET | `/sandbox-tasks/{id}/events|log` | 登录 |
| POST | `/sandbox-tasks/{id}/cancel` | 登录 |
| GET | `/files/upload-policy` | 登录 |
| POST | `/files/uploads` | 登录 |
| GET | `/files/{id}/access-url` | 登录 |
| GET | `/admin/oss/overview` | oss:file:govern |

### 4.6 集成/治理

| 方法 | 路径 | 权限 |
|---|---|---|
| GET/POST | `/feishu-configs` | feishu_config:view/manage |
| POST | `/feishu-configs/{id}/reconnect` | manage |
| GET | `/feishu/oauth/*` | 登录/公开 |
| POST | `/admin/feishu-push/send` | feishu_push:manage |
| GET | `/admin/feishu-push/logs` | feishu_push:manage |
| GET/PUT | `/gitlab-sync/config` | llm_config:view/manage |
| POST | `/gitlab-sync/run` | manage |
| GET/PUT | `/admin/a2a-configs` | a2a_config:view |
| GET/POST | `/admin/schedules` | schedule:manage |
| GET | `/admin/data-pages` | data_page:view |
| GET | `/admin/permission-audit/*` | db_super_admin |
| GET | `/feedback` | feedback:view |
| GET | `/notifications` | 登录 |

---

## 5. 关键示例

### 5.1 创建 Agent

```http
POST /api/agents
Authorization: Bearer <jwt>
Content-Type: application/json

{
  "name": "BOM 助手",
  "description": "查询与校验 BOM",
  "system_prompt": "你是 BOM 专家...",
  "visibility": "restricted",
  "sandbox_mode": "none"
}
```

```json
{
  "code": 0,
  "data": {
    "agent_id": "agt_01H...",
    "name": "BOM 助手",
    "owner_id": "u1",
    "version": 1,
    "create_time": "2026-10-27T10:00:00Z"
  },
  "request_id": "req_01H..."
}
```

### 5.2 对话（SSE）

```http
POST /api/conversations/s1/chat
Authorization: Bearer <jwt>
Accept: text/event-stream

{
  "message": "查一下 D11 的 BOM 异常",
  "client_message_id": "c_01H...",
  "attachments": [],
  "references": []
}
```

```
id: 1
event: msg_start
data: {"message_id":"m1","model":"gpt-x","seq":1}

id: 2
event: token
data: {"message_id":"m1","seq":2,"delta":"正在"}

id: 3
event: tool_call_start
data: {"tool_call_id":"t1","name":"query_bom","args_summary":"{\"model\":\"D11\"}"}

id: 4
event: tool_call_end
data: {"tool_call_id":"t1","status":"ok","duration_ms":320}

id: 5
event: msg_end
data: {"message_id":"m1","status":"completed","usage":{"total_tokens":1234}}
```

### 5.3 配额池确认

```http
POST /api/model-quota-pools/pool1/confirm
{
  "expected_config_version": 3,
  "reason": "校准完成，进入强制模式"
}
```

### 5.4 API Key 调用

```http
POST /api/v1/agent/blocking/chat
Authorization: XPD-HMAC-SHA256 app_id=app1, timestamp=1760000000, nonce=uuid, signature=...
Content-Type: application/json

{
  "agent_id": "agt_1",
  "message": "查 D11 BOM",
  "async": true
}
```

---

## 6. SSE 契约

| 事件 | data |
|---|---|
| msg_start | message_id, model, seq |
| token | message_id, seq, delta |
| thinking | message_id, seq, delta |
| tool_call_start | tool_call_id, name, args_summary |
| tool_call_end | status, duration_ms, result_summary |
| artifact | artifact_id, type, url |
| task_plan_updated | plan, version |
| sub_agent_progress | child_session_id, status |
| msg_end | message_id, status, usage |
| error | code, message, retryable |

**规则**：`id` 单调；`seq` 去重；`msg_end` 必达；`Last-Event-ID` 续传。

---

## 7. 契约治理

- Pydantic 模型即契约；`response_model` 必填。
- CI 跑 OpenAPI diff；破坏性变更升版本。
- 前端用 `openapi-typescript` 生成类型。
- 每个端点有 summary/description/tags。
- Mock Server 供前端并行。

---

## 8. 验收标准

- [ ] 所有端点有鉴权/权限/错误码。
- [ ] 统一 envelope/pagination/idempotency。
- [ ] SSE 契约有版本/续传/去重。
- [ ] OpenAPI 可生成客户端。
- [ ] 破坏性变更可检测。
- [ ] 错误信息可展示、可追踪。
