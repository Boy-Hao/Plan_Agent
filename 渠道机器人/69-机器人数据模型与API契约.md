# 69 机器人数据模型与 API 契约

## 1. 数据模型

| 表 | 用途 |
|---|---|
| `bot_config` | Bot 主配置（渠道/凭证/模式/状态） |
| `bot_agent_binding` | Bot→Agent 路由 |
| `external_identity` | 外部用户↔平台用户 |
| `bot_chat` | 外部会话/群/线程 |
| `conversation_link` | 外部会话↔平台 session |
| `message_map` | 外部消息↔平台消息 |
| `delivery_log` | 发送/更新/撤回日志 |
| `bot_health` | 健康状态 |
| `bot_event_dedupe` | 事件去重（也可 Redis） |

---

## 2. DDL

```sql
CREATE TABLE bot_config (
  bot_id VARCHAR(32) PRIMARY KEY,
  tenant_id VARCHAR(32) NOT NULL,
  channel VARCHAR(32) NOT NULL,
  name VARCHAR(100) NOT NULL,
  credentials_cipher TEXT NOT NULL,
  webhook_secret_cipher TEXT NULL,
  mode VARCHAR(16) NOT NULL DEFAULT 'webhook', -- webhook/ws/polling
  callback_url VARCHAR(512) NULL,
  capabilities JSON NULL,
  enabled TINYINT NOT NULL DEFAULT 0,
  status VARCHAR(16) NOT NULL DEFAULT 'draft',
  owner_id VARCHAR(32) NULL,
  create_time DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  update_time DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  is_deleted TINYINT NOT NULL DEFAULT 0,
  KEY idx_bot_tenant (tenant_id, channel, is_deleted),
  KEY idx_bot_status (tenant_id, status)
);

CREATE TABLE bot_agent_binding (
  id VARCHAR(32) PRIMARY KEY,
  tenant_id VARCHAR(32) NOT NULL,
  bot_id VARCHAR(32) NOT NULL,
  agent_id VARCHAR(32) NOT NULL,
  priority INT NOT NULL DEFAULT 0,
  match_type VARCHAR(16) NOT NULL DEFAULT 'default', -- default/command/keyword/chat
  match_value VARCHAR(255) NULL,
  is_default TINYINT NOT NULL DEFAULT 0,
  enabled TINYINT NOT NULL DEFAULT 1,
  KEY idx_bind_bot (bot_id, enabled, priority)
);

CREATE TABLE external_identity (
  id VARCHAR(32) PRIMARY KEY,
  tenant_id VARCHAR(32) NOT NULL,
  channel VARCHAR(32) NOT NULL,
  bot_id VARCHAR(32) NOT NULL,
  external_user_id VARCHAR(128) NOT NULL,
  union_id VARCHAR(128) NULL,
  platform_user_id VARCHAR(32) NULL,
  status VARCHAR(16) NOT NULL DEFAULT 'unbound', -- unbound/bound/guest/blocked
  bind_time DATETIME(3) NULL,
  create_time DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  UNIQUE KEY uk_ext (bot_id, external_user_id),
  KEY idx_ext_user (tenant_id, platform_user_id)
);

CREATE TABLE bot_chat (
  id VARCHAR(32) PRIMARY KEY,
  tenant_id VARCHAR(32) NOT NULL,
  bot_id VARCHAR(32) NOT NULL,
  channel_chat_id VARCHAR(128) NOT NULL,
  chat_type VARCHAR(16) NOT NULL, -- direct/group/thread
  title VARCHAR(255) NULL,
  scope_mode VARCHAR(16) NOT NULL DEFAULT 'per_user', -- per_chat/per_user/per_thread
  last_active_time DATETIME(3) NULL,
  UNIQUE KEY uk_chat (bot_id, channel_chat_id)
);

CREATE TABLE conversation_link (
  id VARCHAR(32) PRIMARY KEY,
  tenant_id VARCHAR(32) NOT NULL,
  bot_chat_id VARCHAR(32) NOT NULL,
  platform_session_id VARCHAR(32) NOT NULL,
  agent_id VARCHAR(32) NOT NULL,
  status VARCHAR(16) NOT NULL DEFAULT 'active',
  create_time DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  KEY idx_link_chat (bot_chat_id, status)
);

CREATE TABLE message_map (
  id VARCHAR(32) PRIMARY KEY,
  tenant_id VARCHAR(32) NOT NULL,
  bot_id VARCHAR(32) NOT NULL,
  channel_message_id VARCHAR(128) NOT NULL,
  platform_message_id VARCHAR(32) NULL,
  direction VARCHAR(8) NOT NULL, -- in/out
  status VARCHAR(16) NOT NULL,
  create_time DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  UNIQUE KEY uk_msg (bot_id, channel_message_id, direction)
);

CREATE TABLE delivery_log (
  id VARCHAR(32) PRIMARY KEY,
  tenant_id VARCHAR(32) NOT NULL,
  bot_id VARCHAR(32) NOT NULL,
  message_id VARCHAR(128) NULL,
  status VARCHAR(16) NOT NULL,
  attempts INT NOT NULL DEFAULT 0,
  error_code VARCHAR(64) NULL,
  latency_ms INT NULL,
  create_time DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  KEY idx_delivery (bot_id, create_time)
);

CREATE TABLE bot_health (
  bot_id VARCHAR(32) PRIMARY KEY,
  status VARCHAR(16) NOT NULL,
  mode VARCHAR(16) NOT NULL,
  last_ok DATETIME(3) NULL,
  last_error VARCHAR(512) NULL,
  ws_status VARCHAR(16) NULL,
  update_time DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3)
);
```

> 去重也可用 Redis：`t:{tenant}:bot:dedupe:{bot}:{event_id}`，TTL 24h。

---

## 3. 管理端 API

| 方法 | 路径 | 权限 | 说明 |
|---|---|---|---|
| GET | `/admin/bots` | bot:view | 列表 |
| POST | `/admin/bots` | bot:manage | 新建 |
| GET | `/admin/bots/{id}` | bot:view | 详情 |
| PUT | `/admin/bots/{id}` | bot:manage | 更新 |
| DELETE | `/admin/bots/{id}` | bot:manage | 软删 |
| POST | `/admin/bots/{id}/test` | bot:manage | 测试连接/发消息 |
| PUT | `/admin/bots/{id}/enabled` | bot:manage | 启停 |
| GET/PUT | `/admin/bots/{id}/bindings` | bot:manage | 路由绑定 |
| GET | `/admin/bots/{id}/health` | bot:view | 健康 |
| GET | `/admin/bots/{id}/logs` | bot:view | 日志 |
| POST | `/admin/bots/{id}/rotate-secret` | bot:manage | 轮换 |

**权限码**：`bot:view`、`bot:manage`（可归入 `feishu_config:view` 扩展）。

---

## 4. 入站回调

```
POST /api/bots/{channel}/callback/{bot_id}
```

- 无需 Bearer；靠渠道验签。
- 验签失败 401。
- 重复事件 200（幂等）。
- 处理异步：先 200，后入队。
- 超时：渠道要求 3–5s 内响应。

**响应**
```json
{"ok": true}
```

---

## 5. 统一消息 Schema

```json
{
  "channel": "feishu",
  "bot_id": "bot_1",
  "tenant_id": "t1",
  "event_id": "evt_1",
  "message_id": "m_1",
  "chat_id": "c_1",
  "chat_type": "direct",
  "sender": {"external_user_id": "u_1", "union_id": null, "name": "张三"},
  "text": "你好",
  "mentions": [],
  "attachments": [],
  "reply_to": null,
  "raw": {}
}
```

**出站**
```json
{
  "chat_id": "c_1",
  "reply_to": "m_1",
  "text": "...",
  "card": null,
  "media": [],
  "thread": null
}
```

---

## 6. 错误码

| HTTP | code | 说明 |
|---|---|---|
| 400 | invalid_payload | 解析失败 |
| 401 | invalid_signature | 验签失败 |
| 401 | timestamp_expired | 时间窗 |
| 409 | duplicate_event | 重复（可 200） |
| 403 | bot_disabled | Bot 停用 |
| 403 | tenant_mismatch | 租户不匹配 |
| 404 | bot_not_found | 不存在 |
| 429 | rate_limited | 限流 |
| 503 | channel_unavailable | 渠道故障 |

---

## 7. 幂等与去重

- 入站：`(bot_id, event_id)` 去重。
- 出站：`idempotency_key = hash(bot_id, chat_id, platform_message_id, part_index)`。
- 更新：`message_map` 查外部消息 ID。
- 重试：同 key 不重复发。

---

## 8. 示例：创建 Bot

```http
POST /api/admin/bots
Authorization: Bearer <jwt>
Content-Type: application/json

{
  "channel": "feishu",
  "name": "BOM 助手",
  "mode": "ws",
  "credentials": {
    "app_id": "cli_x",
    "app_secret": "***",
    "encrypt_key": "***",
    "verification_token": "***"
  }
}
```

```json
{
  "code": 0,
  "data": {"bot_id":"bot_1","status":"draft"},
  "request_id":"req_1"
}
```

---

## 9. 验收标准

- [ ] 表/索引覆盖配置/身份/会话/日志。
- [ ] 管理端 API 有权限/审计。
- [ ] 回调验签/去重/幂等。
- [ ] 统一消息字段完整。
- [ ] 错误码可映射。
- [ ] 出站可重试/不重复。
