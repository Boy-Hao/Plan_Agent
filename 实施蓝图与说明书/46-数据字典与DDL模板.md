# 46 数据字典与 DDL 模板

> 约定：MySQL 8、utf8mb4、UTC、软删除、逻辑外键、无 DB UNIQUE（除主键）。
> 所有表带 `tenant_id`；ID 用 `VARCHAR(32)`（ULID/UUID）。

---

## 1. 公共字段

```sql
tenant_id      VARCHAR(32) NOT NULL,
create_time    DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
update_time    DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
create_user_id VARCHAR(64) NULL,
update_user_id VARCHAR(64) NULL,
is_deleted     TINYINT NOT NULL DEFAULT 0,
delete_time    DATETIME(3) NULL
```

索引统一以 `tenant_id` 开头（多租户）。

---

## 2. 身份与权限

```sql
CREATE TABLE sys_user (
  user_id VARCHAR(32) PRIMARY KEY,
  tenant_id VARCHAR(32) NOT NULL,
  username VARCHAR(64) NOT NULL,
  name VARCHAR(64) NOT NULL,
  email VARCHAR(128) NOT NULL,
  job_num VARCHAR(32) NULL,
  org VARCHAR(128) NULL,
  status TINYINT NOT NULL DEFAULT 1,
  last_login_time DATETIME(3) NULL,
  create_time DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  update_time DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  is_deleted TINYINT NOT NULL DEFAULT 0,
  KEY idx_user_tenant (tenant_id, username),
  KEY idx_user_email (tenant_id, email)
);

CREATE TABLE sys_role (
  role_id VARCHAR(32) PRIMARY KEY,
  tenant_id VARCHAR(32) NOT NULL,
  code VARCHAR(32) NOT NULL,
  name VARCHAR(64) NOT NULL,
  description VARCHAR(255) NOT NULL DEFAULT '',
  is_system TINYINT NOT NULL DEFAULT 0,
  is_deleted TINYINT NOT NULL DEFAULT 0,
  create_time DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  KEY idx_role_tenant (tenant_id, code)
);

CREATE TABLE sys_permission (
  permission_id VARCHAR(32) PRIMARY KEY,
  code VARCHAR(64) NOT NULL,
  name VARCHAR(64) NOT NULL,
  resource VARCHAR(64) NOT NULL,
  action VARCHAR(32) NOT NULL,
  group_code VARCHAR(32) NOT NULL,
  sort_order INT NOT NULL DEFAULT 0,
  KEY idx_perm_group (group_code, sort_order)
);

CREATE TABLE sys_user_role (
  user_id VARCHAR(32) NOT NULL,
  role_id VARCHAR(32) NOT NULL,
  PRIMARY KEY (user_id, role_id)
);

CREATE TABLE sys_role_permission (
  role_id VARCHAR(32) NOT NULL,
  permission_id VARCHAR(32) NOT NULL,
  PRIMARY KEY (role_id, permission_id)
);

CREATE TABLE sys_resource_collaborator (
  id VARCHAR(32) PRIMARY KEY,
  tenant_id VARCHAR(32) NOT NULL,
  resource_type VARCHAR(32) NOT NULL,
  resource_id VARCHAR(32) NOT NULL,
  user_id VARCHAR(32) NOT NULL,
  role VARCHAR(16) NOT NULL DEFAULT 'editor',
  is_deleted TINYINT NOT NULL DEFAULT 0,
  create_time DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  KEY idx_collab (tenant_id, resource_type, resource_id, user_id)
);

CREATE TABLE sys_api_key (
  api_key_id VARCHAR(32) PRIMARY KEY,
  tenant_id VARCHAR(32) NOT NULL,
  app_id VARCHAR(64) NOT NULL,
  secret_hash VARCHAR(128) NOT NULL,
  secret_cipher VARCHAR(512) NOT NULL,
  system_name VARCHAR(128) NOT NULL,
  scope VARCHAR(255) NOT NULL,
  allowed_agents JSON NULL,
  status VARCHAR(16) NOT NULL DEFAULT 'enabled',
  create_user_id VARCHAR(64) NULL,
  create_time DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  update_time DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  KEY idx_apikey_app (app_id)
);

CREATE TABLE sys_audit_log (
  id VARCHAR(32) PRIMARY KEY,
  tenant_id VARCHAR(32) NOT NULL,
  user_id VARCHAR(64) NULL,
  action VARCHAR(64) NOT NULL,
  resource_type VARCHAR(32) NOT NULL,
  resource_id VARCHAR(32) NULL,
  before_json JSON NULL,
  after_json JSON NULL,
  result VARCHAR(16) NOT NULL,
  ip VARCHAR(64) NULL,
  ua VARCHAR(255) NULL,
  request_id VARCHAR(64) NULL,
  create_time DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  KEY idx_audit_res (tenant_id, resource_type, resource_id, create_time),
  KEY idx_audit_user (tenant_id, user_id, create_time)
);
```

---

## 3. Agent

```sql
CREATE TABLE agent (
  agent_id VARCHAR(32) PRIMARY KEY,
  tenant_id VARCHAR(32) NOT NULL,
  name VARCHAR(100) NOT NULL,
  description VARCHAR(1000) NOT NULL DEFAULT '',
  system_prompt MEDIUMTEXT NULL,
  avatar_object_key VARCHAR(512) NULL,
  persona_object_key VARCHAR(512) NULL,
  persona_type VARCHAR(16) NULL,
  model VARCHAR(64) NULL,
  multi_agent_enabled TINYINT NOT NULL DEFAULT 0,
  sub_agent_stateful TINYINT NOT NULL DEFAULT 0,
  routing_description VARCHAR(1000) NULL,
  sandbox_mode VARCHAR(16) NOT NULL DEFAULT 'none',
  sandbox_config_id VARCHAR(32) NULL,
  shared_pool_size INT NOT NULL DEFAULT 0,
  tools JSON NULL,
  visibility VARCHAR(16) NOT NULL DEFAULT 'restricted',
  owner_id VARCHAR(32) NOT NULL,
  status VARCHAR(16) NOT NULL DEFAULT 'active',
  version INT NOT NULL DEFAULT 1,
  create_time DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  update_time DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  is_deleted TINYINT NOT NULL DEFAULT 0,
  KEY idx_agent_tenant (tenant_id, is_deleted, visibility),
  KEY idx_agent_owner (tenant_id, owner_id, is_deleted),
  KEY idx_agent_name (tenant_id, name)
);

CREATE TABLE agent_skill (
  id VARCHAR(32) PRIMARY KEY,
  tenant_id VARCHAR(32) NOT NULL,
  agent_id VARCHAR(32) NOT NULL,
  skill_id VARCHAR(32) NOT NULL,
  skill_version INT NULL,
  allow_user_cancel TINYINT NOT NULL DEFAULT 1,
  is_deleted TINYINT NOT NULL DEFAULT 0,
  UNIQUE KEY uk_agent_skill (agent_id, skill_id)
);

CREATE TABLE agent_sub_agent (
  id VARCHAR(32) PRIMARY KEY,
  agent_id VARCHAR(32) NOT NULL,
  sub_agent_id VARCHAR(32) NOT NULL,
  foreground_timeout_seconds INT NOT NULL DEFAULT 300,
  total_budget_seconds INT NOT NULL DEFAULT 900,
  report_enabled TINYINT NOT NULL DEFAULT 1,
  UNIQUE KEY uk_sub (agent_id, sub_agent_id)
);

CREATE TABLE agent_llm_binding (
  id VARCHAR(32) PRIMARY KEY,
  tenant_id VARCHAR(32) NOT NULL,
  agent_id VARCHAR(32) NOT NULL,
  llm_config_id VARCHAR(32) NOT NULL,
  is_default TINYINT NOT NULL DEFAULT 0,
  binding_policy JSON NULL,
  parameter_config JSON NULL,
  version INT NOT NULL DEFAULT 1,
  UNIQUE KEY uk_binding (agent_id, llm_config_id)
);

CREATE TABLE agent_variable (
  var_id VARCHAR(32) PRIMARY KEY,
  tenant_id VARCHAR(32) NOT NULL,
  agent_id VARCHAR(32) NOT NULL,
  var_key VARCHAR(64) NOT NULL,
  value_cipher VARCHAR(4096) NOT NULL,
  description VARCHAR(500) NOT NULL DEFAULT '',
  status TINYINT NOT NULL DEFAULT 1,
  value_type VARCHAR(16) NULL,
  create_time DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  KEY idx_agent_var (agent_id, var_key)
);

CREATE TABLE agent_quick_start (
  id VARCHAR(32) PRIMARY KEY,
  agent_id VARCHAR(32) NOT NULL,
  biz_id VARCHAR(64) NOT NULL DEFAULT '',
  label VARCHAR(100) NOT NULL,
  prompt_text VARCHAR(2000) NOT NULL,
  enabled TINYINT NOT NULL DEFAULT 1,
  sort_order INT NOT NULL DEFAULT 0
);

CREATE TABLE agent_biz_group (
  id VARCHAR(32) PRIMARY KEY,
  agent_id VARCHAR(32) NOT NULL,
  biz_id VARCHAR(64) NOT NULL,
  biz_name VARCHAR(100) NOT NULL,
  sort_order INT NOT NULL DEFAULT 0
);
```

---

## 4. Skill

```sql
CREATE TABLE skill (
  skill_id VARCHAR(32) PRIMARY KEY,
  tenant_id VARCHAR(32) NOT NULL,
  name VARCHAR(100) NOT NULL,
  display_name VARCHAR(100) NULL,
  description VARCHAR(2000) NOT NULL DEFAULT '',
  execution_mode VARCHAR(16) NOT NULL DEFAULT 'on_demand',
  sandbox_requirement VARCHAR(16) NOT NULL DEFAULT 'none',
  category_id VARCHAR(32) NULL,
  owner_id VARCHAR(32) NOT NULL,
  source VARCHAR(16) NOT NULL DEFAULT 'manual',
  is_private TINYINT NOT NULL DEFAULT 0,
  current_version INT NOT NULL DEFAULT 1,
  status VARCHAR(16) NOT NULL DEFAULT 'active',
  is_deleted TINYINT NOT NULL DEFAULT 0,
  create_time DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  update_time DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  KEY idx_skill (tenant_id, is_deleted, category_id),
  KEY idx_skill_owner (tenant_id, owner_id)
);

CREATE TABLE skill_version (
  id VARCHAR(32) PRIMARY KEY,
  skill_id VARCHAR(32) NOT NULL,
  version_number INT NOT NULL,
  content_hash VARCHAR(64) NOT NULL,
  manifest JSON NULL,
  object_prefix VARCHAR(512) NOT NULL,
  create_user_id VARCHAR(64) NULL,
  create_time DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  UNIQUE KEY uk_skill_ver (skill_id, version_number)
);

CREATE TABLE skill_file (
  id VARCHAR(32) PRIMARY KEY,
  skill_id VARCHAR(32) NOT NULL,
  version_id VARCHAR(32) NOT NULL,
  path VARCHAR(512) NOT NULL,
  size BIGINT NOT NULL,
  content_type VARCHAR(128) NULL,
  hash VARCHAR(64) NOT NULL
);

CREATE TABLE skill_tag (
  tag_id VARCHAR(32) PRIMARY KEY,
  tenant_id VARCHAR(32) NOT NULL,
  name VARCHAR(64) NOT NULL,
  is_deleted TINYINT NOT NULL DEFAULT 0
);

CREATE TABLE skill_tag_rel (
  skill_id VARCHAR(32) NOT NULL,
  tag_id VARCHAR(32) NOT NULL,
  PRIMARY KEY (skill_id, tag_id)
);

CREATE TABLE skill_category (
  category_id VARCHAR(32) PRIMARY KEY,
  tenant_id VARCHAR(32) NOT NULL,
  name VARCHAR(64) NOT NULL,
  parent_id VARCHAR(32) NULL,
  sort_order INT NOT NULL DEFAULT 0,
  is_deleted TINYINT NOT NULL DEFAULT 0
);

CREATE TABLE personal_skill (
  skill_id VARCHAR(32) PRIMARY KEY,
  tenant_id VARCHAR(32) NOT NULL,
  owner_id VARCHAR(32) NOT NULL,
  current_version INT NOT NULL DEFAULT 1,
  enabled TINYINT NOT NULL DEFAULT 0,
  governance_status VARCHAR(16) NOT NULL DEFAULT 'normal',
  risk_level VARCHAR(16) NOT NULL DEFAULT 'low',
  quota_used BIGINT NOT NULL DEFAULT 0,
  is_deleted TINYINT NOT NULL DEFAULT 0
);

CREATE TABLE personal_skill_share (
  share_id VARCHAR(32) PRIMARY KEY,
  skill_id VARCHAR(32) NOT NULL,
  owner_id VARCHAR(32) NOT NULL,
  target_user_id VARCHAR(32) NOT NULL,
  enabled TINYINT NOT NULL DEFAULT 1,
  status VARCHAR(16) NOT NULL DEFAULT 'active'
);

CREATE TABLE personal_skill_preference (
  id VARCHAR(32) PRIMARY KEY,
  user_id VARCHAR(32) NOT NULL,
  agent_id VARCHAR(32) NOT NULL,
  skill_id VARCHAR(32) NOT NULL,
  enabled TINYINT NOT NULL DEFAULT 1,
  UNIQUE KEY uk_pref (user_id, agent_id, skill_id)
);
```

---

## 5. 会话与运行时

```sql
CREATE TABLE session (
  session_id VARCHAR(32) PRIMARY KEY,
  tenant_id VARCHAR(32) NOT NULL,
  agent_id VARCHAR(32) NOT NULL,
  user_id VARCHAR(32) NOT NULL,
  biz_id VARCHAR(64) NULL,
  name VARCHAR(200) NOT NULL DEFAULT '',
  source VARCHAR(16) NOT NULL DEFAULT 'web',
  source_name VARCHAR(64) NULL,
  last_active_time DATETIME(3) NULL,
  last_message_summary VARCHAR(500) NULL,
  total_tokens BIGINT NOT NULL DEFAULT 0,
  is_deleted TINYINT NOT NULL DEFAULT 0,
  create_time DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  KEY idx_session_user (tenant_id, user_id, is_deleted, last_active_time DESC),
  KEY idx_session_agent (tenant_id, agent_id, is_deleted)
);

CREATE TABLE message (
  message_id VARCHAR(32) PRIMARY KEY,
  tenant_id VARCHAR(32) NOT NULL,
  session_id VARCHAR(32) NOT NULL,
  role VARCHAR(16) NOT NULL,
  content MEDIUMTEXT NULL,
  metadata JSON NULL,
  status VARCHAR(16) NOT NULL DEFAULT 'done',
  seq BIGINT NOT NULL,
  create_time DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  KEY idx_msg_session (tenant_id, session_id, seq)
);

CREATE TABLE turn (
  turn_id VARCHAR(32) PRIMARY KEY,
  tenant_id VARCHAR(32) NOT NULL,
  session_id VARCHAR(32) NOT NULL,
  message_id VARCHAR(32) NOT NULL,
  client_message_id VARCHAR(64) NULL,
  status VARCHAR(16) NOT NULL,
  model VARCHAR(64) NULL,
  started_at DATETIME(3) NULL,
  ended_at DATETIME(3) NULL,
  error_code VARCHAR(64) NULL,
  UNIQUE KEY uk_turn_client (tenant_id, session_id, client_message_id),
  KEY idx_turn_status (tenant_id, status, started_at)
);

CREATE TABLE tool_call (
  id VARCHAR(32) PRIMARY KEY,
  tenant_id VARCHAR(32) NOT NULL,
  turn_id VARCHAR(32) NOT NULL,
  tool_call_id VARCHAR(64) NOT NULL,
  name VARCHAR(64) NOT NULL,
  args_summary VARCHAR(2000) NULL,
  result_summary VARCHAR(2000) NULL,
  status VARCHAR(16) NOT NULL,
  duration_ms INT NULL,
  create_time DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  UNIQUE KEY uk_tool_call (turn_id, tool_call_id)
);

CREATE TABLE task_plan (
  id VARCHAR(32) PRIMARY KEY,
  session_id VARCHAR(32) NOT NULL,
  message_id VARCHAR(32) NOT NULL,
  plan JSON NOT NULL,
  version INT NOT NULL,
  status VARCHAR(16) NOT NULL,
  update_time DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3)
);

CREATE TABLE external_context (
  id VARCHAR(32) PRIMARY KEY,
  session_id VARCHAR(32) NOT NULL,
  context_key VARCHAR(64) NOT NULL,
  content MEDIUMTEXT NOT NULL,
  active TINYINT NOT NULL DEFAULT 1,
  expire_time DATETIME(3) NULL,
  KEY idx_ext (session_id, context_key, active)
);

CREATE TABLE session_attachment (
  id VARCHAR(32) PRIMARY KEY,
  session_id VARCHAR(32) NOT NULL,
  message_id VARCHAR(32) NULL,
  file_id VARCHAR(32) NOT NULL,
  KEY idx_att (session_id, message_id)
);
```

**分区建议**：`message`/`usage_llm_call`/`sys_audit_log` 按月分区；`message` 可再按 `session_id` hash。

---

## 6. 模型与配额

```sql
CREATE TABLE llm_config (
  llm_config_id VARCHAR(32) PRIMARY KEY,
  tenant_id VARCHAR(32) NOT NULL,
  name VARCHAR(100) NOT NULL,
  provider VARCHAR(32) NOT NULL,
  api_base_url VARCHAR(512) NULL,
  api_key_cipher VARCHAR(1024) NOT NULL,
  model_identifier VARCHAR(128) NOT NULL,
  price_input DECIMAL(18,6) NOT NULL DEFAULT 0,
  price_output DECIMAL(18,6) NOT NULL DEFAULT 0,
  price_cache DECIMAL(18,6) NOT NULL DEFAULT 0,
  quota_limit BIGINT NOT NULL DEFAULT 0,
  model_quota_pool_id VARCHAR(32) NULL,
  max_output_tokens INT NOT NULL DEFAULT 4096,
  token_counter_key VARCHAR(64) NOT NULL,
  supports_thinking TINYINT NOT NULL DEFAULT 0,
  supports_vision TINYINT NOT NULL DEFAULT 0,
  capability_overrides JSON NULL,
  is_shared TINYINT NOT NULL DEFAULT 0,
  extra_config JSON NULL,
  status TINYINT NOT NULL DEFAULT 1,
  owner_id VARCHAR(32) NULL,
  create_time DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  update_time DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  is_deleted TINYINT NOT NULL DEFAULT 0,
  KEY idx_llm_tenant (tenant_id, is_deleted)
);

CREATE TABLE model_quota_pool (
  pool_id VARCHAR(32) PRIMARY KEY,
  tenant_id VARCHAR(32) NOT NULL,
  name VARCHAR(100) NOT NULL,
  configured_tpm INT NOT NULL DEFAULT 0,
  burst_seconds INT NOT NULL DEFAULT 60,
  cache_ratio DECIMAL(8,4) NOT NULL DEFAULT 1,
  max_admission_wait_ms INT NOT NULL DEFAULT 3000,
  max_waiter_count INT NOT NULL DEFAULT 50,
  max_waiting_tokens BIGINT NOT NULL DEFAULT 100000,
  mode VARCHAR(16) NOT NULL DEFAULT 'OBSERVE',
  config_version INT NOT NULL DEFAULT 1,
  parameters_confirmed TINYINT NOT NULL DEFAULT 0,
  status VARCHAR(16) NOT NULL DEFAULT 'active',
  create_time DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3)
);

CREATE TABLE usage_llm_call (
  id VARCHAR(32) PRIMARY KEY,
  tenant_id VARCHAR(32) NOT NULL,
  message_id VARCHAR(32) NOT NULL,
  session_id VARCHAR(32) NOT NULL,
  agent_id VARCHAR(32) NULL,
  llm_config_id VARCHAR(32) NOT NULL,
  user_id VARCHAR(32) NULL,
  prompt_tokens INT NOT NULL DEFAULT 0,
  completion_tokens INT NOT NULL DEFAULT 0,
  cached_tokens INT NOT NULL DEFAULT 0,
  cost DECIMAL(18,6) NOT NULL DEFAULT 0,
  latency_ms INT NULL,
  status VARCHAR(16) NOT NULL,
  error_code VARCHAR(64) NULL,
  create_time DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  KEY idx_usage_time (tenant_id, create_time),
  KEY idx_usage_user (tenant_id, user_id, create_time),
  KEY idx_usage_agent (tenant_id, agent_id, create_time)
) PARTITION BY RANGE (TO_DAYS(create_time)) (
  PARTITION p202610 VALUES LESS THAN (TO_DAYS('2026-11-01')),
  PARTITION pmax VALUES LESS THAN MAXVALUE
);
```

---

## 7. 沙箱

```sql
CREATE TABLE sandbox_config (
  sandbox_config_id VARCHAR(32) PRIMARY KEY,
  tenant_id VARCHAR(32) NOT NULL,
  name VARCHAR(100) NOT NULL,
  domain VARCHAR(255) NOT NULL,
  template VARCHAR(128) NOT NULL,
  api_key_cipher VARCHAR(1024) NOT NULL,
  ttl_seconds INT NOT NULL DEFAULT 3600,
  env_json JSON NULL,
  llm_proxy_rules JSON NULL,
  git_auth_mode VARCHAR(16) NOT NULL DEFAULT 'caller',
  git_allowed_projects JSON NULL,
  git_token_ttl_seconds INT NOT NULL DEFAULT 1800,
  git_auth_fallback_to_caller TINYINT NOT NULL DEFAULT 0,
  git_mr_mode VARCHAR(16) NOT NULL DEFAULT 'platform',
  lifecycle_mode VARCHAR(16) NOT NULL DEFAULT 'ttl',
  pause_after_seconds INT NOT NULL DEFAULT 900,
  delete_after_paused_seconds INT NOT NULL DEFAULT 3600,
  creation_strategy VARCHAR(16) NOT NULL DEFAULT 'lazy',
  provision_timeout_seconds INT NOT NULL DEFAULT 300,
  background_task_enabled TINYINT NOT NULL DEFAULT 0,
  is_private TINYINT NOT NULL DEFAULT 0,
  owner_id VARCHAR(32) NULL,
  is_deleted TINYINT NOT NULL DEFAULT 0
);

CREATE TABLE sandbox_instance (
  sandbox_id VARCHAR(32) PRIMARY KEY,
  tenant_id VARCHAR(32) NOT NULL,
  config_id VARCHAR(32) NOT NULL,
  state VARCHAR(16) NOT NULL,
  owner_app VARCHAR(64) NULL,
  owner_session VARCHAR(32) NULL,
  owner_env VARCHAR(32) NULL,
  metadata JSON NULL,
  bound TINYINT NOT NULL DEFAULT 0,
  session_id VARCHAR(32) NULL,
  user_id VARCHAR(32) NULL,
  created_at DATETIME(3) NULL,
  started_at DATETIME(3) NULL,
  end_at DATETIME(3) NULL,
  last_active_time DATETIME(3) NULL,
  KEY idx_sb_state (tenant_id, state),
  KEY idx_sb_session (tenant_id, session_id)
);

CREATE TABLE sandbox_task (
  task_id VARCHAR(32) PRIMARY KEY,
  tenant_id VARCHAR(32) NOT NULL,
  session_id VARCHAR(32) NOT NULL,
  sandbox_id VARCHAR(32) NULL,
  command TEXT NOT NULL,
  kind VARCHAR(16) NOT NULL DEFAULT 'shell',
  cli VARCHAR(16) NOT NULL DEFAULT '',
  access_mode VARCHAR(16) NOT NULL DEFAULT 'write',
  cwd VARCHAR(512) NULL,
  status VARCHAR(16) NOT NULL,
  timeout_seconds INT NULL,
  created_by VARCHAR(32) NULL,
  started_at DATETIME(3) NULL,
  ended_at DATETIME(3) NULL
);
```

---

## 8. 文件与集成

```sql
CREATE TABLE file_object (
  file_id VARCHAR(32) PRIMARY KEY,
  tenant_id VARCHAR(32) NOT NULL,
  object_key VARCHAR(512) NOT NULL,
  bucket VARCHAR(128) NOT NULL,
  size BIGINT NOT NULL,
  content_type VARCHAR(128) NULL,
  hash VARCHAR(64) NULL,
  owner_id VARCHAR(32) NOT NULL,
  status VARCHAR(16) NOT NULL DEFAULT 'active',
  version INT NOT NULL DEFAULT 1,
  is_deleted TINYINT NOT NULL DEFAULT 0,
  create_time DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  KEY idx_file_owner (tenant_id, owner_id, is_deleted)
);

CREATE TABLE file_reference (
  id VARCHAR(32) PRIMARY KEY,
  tenant_id VARCHAR(32) NOT NULL,
  file_id VARCHAR(32) NOT NULL,
  ref_type VARCHAR(32) NOT NULL,
  ref_id VARCHAR(32) NOT NULL,
  KEY idx_ref (file_id, ref_type, ref_id)
);

CREATE TABLE feishu_config (
  feishu_config_id VARCHAR(32) PRIMARY KEY,
  tenant_id VARCHAR(32) NOT NULL,
  name VARCHAR(100) NOT NULL,
  app_id VARCHAR(64) NOT NULL,
  app_secret_cipher VARCHAR(1024) NOT NULL,
  encrypt_key_cipher VARCHAR(1024) NOT NULL,
  verification_token_cipher VARCHAR(1024) NOT NULL,
  enabled TINYINT NOT NULL DEFAULT 1,
  is_default TINYINT NOT NULL DEFAULT 0,
  is_primary TINYINT NOT NULL DEFAULT 0,
  bot_chat_enabled TINYINT NOT NULL DEFAULT 1,
  owner_id VARCHAR(32) NULL,
  is_deleted TINYINT NOT NULL DEFAULT 0
);

CREATE TABLE feishu_user_token (
  id VARCHAR(32) PRIMARY KEY,
  tenant_id VARCHAR(32) NOT NULL,
  user_id VARCHAR(32) NOT NULL,
  feishu_config_id VARCHAR(32) NOT NULL,
  access_token_cipher VARCHAR(2048) NOT NULL,
  refresh_token_cipher VARCHAR(2048) NULL,
  expire_time DATETIME(3) NULL,
  status VARCHAR(16) NOT NULL DEFAULT 'active'
);

CREATE TABLE gitlab_coding_account (
  id VARCHAR(32) PRIMARY KEY,
  tenant_id VARCHAR(32) NOT NULL,
  username VARCHAR(64) NOT NULL,
  token_cipher VARCHAR(2048) NOT NULL,
  projects JSON NULL,
  status VARCHAR(16) NOT NULL DEFAULT 'active'
);

CREATE TABLE schedule (
  schedule_id VARCHAR(32) PRIMARY KEY,
  tenant_id VARCHAR(32) NOT NULL,
  agent_id VARCHAR(32) NOT NULL,
  owner_user_id VARCHAR(32) NOT NULL,
  created_by VARCHAR(16) NOT NULL,
  trigger_type VARCHAR(16) NOT NULL,
  cron_expr VARCHAR(64) NULL,
  run_at DATETIME(3) NULL,
  next_run_at DATETIME(3) NULL,
  status VARCHAR(16) NOT NULL DEFAULT 'active',
  title VARCHAR(200) NULL,
  action_prompt TEXT NOT NULL,
  last_fire_at DATETIME(3) NULL
);
```

---

## 9. 通知/反馈/系统参数

```sql
CREATE TABLE sys_notification (
  id VARCHAR(32) PRIMARY KEY,
  tenant_id VARCHAR(32) NOT NULL,
  user_id VARCHAR(32) NOT NULL,
  type VARCHAR(32) NOT NULL,
  title VARCHAR(200) NOT NULL,
  content VARCHAR(2000) NULL,
  payload JSON NULL,
  ref_type VARCHAR(32) NULL,
  ref_id VARCHAR(32) NULL,
  read_status VARCHAR(16) NOT NULL DEFAULT 'unread',
  create_time DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  KEY idx_notify (tenant_id, user_id, read_status, create_time DESC)
);

CREATE TABLE message_feedback (
  feedback_id VARCHAR(32) PRIMARY KEY,
  tenant_id VARCHAR(32) NOT NULL,
  message_id VARCHAR(32) NOT NULL,
  user_id VARCHAR(32) NOT NULL,
  rating TINYINT NOT NULL,
  reason VARCHAR(256) NULL,
  is_deleted TINYINT NOT NULL DEFAULT 0,
  create_time DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  UNIQUE KEY uk_feedback (message_id, user_id)
);

CREATE TABLE sys_parameter (
  id VARCHAR(32) PRIMARY KEY,
  tenant_id VARCHAR(32) NOT NULL,
  group_code VARCHAR(64) NOT NULL,
  config_version INT NOT NULL,
  values_json JSON NOT NULL,
  status VARCHAR(16) NOT NULL DEFAULT 'active',
  create_time DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3)
);
```

---

## 10. Redis 键

| Key | 结构 | TTL |
|---|---|---|
| `t:{tenant}:sso:access:{jti}` | String | access |
| `t:{tenant}:sso:refresh:{jti}` | String | refresh |
| `t:{tenant}:perm:user:{id}` | String(JSON) | 10m |
| `t:{tenant}:session:active_turn:{sid}` | Hash | 1h |
| `t:{tenant}:sse:log:{mid}` | Stream | 1h |
| `t:{tenant}:sse:live:{mid}` | Pub/Sub | — |
| `t:{tenant}:lock:session:{sid}` | String | 30s |
| `t:{tenant}:quota:{pool}:bucket` | Hash | — |
| `t:{tenant}:quota:{pool}:waiters` | ZSet | — |
| `t:{tenant}:idem:{key}` | String | 24h |
| `t:{tenant}:nonce:{app}:{nonce}` | String | 10m |
| `t:{tenant}:oauth:state:{state}` | String | 10m |
| `t:{tenant}:notify:unread:{uid}` | String | — |

---

## 11. OSS 布局

```
/{tenant}/files/{user_id}/{file_id}/{name}
/{tenant}/avatars/{agent_id}/{hash}
/{tenant}/personas/{agent_id}/{hash}
/{tenant}/skills/{skill_id}/{version}/...
/{tenant}/personal-skills/{user_id}/{skill_id}/{version}/...
/{tenant}/attachments/{session_id}/{file_id}/{name}
/{tenant}/artifacts/{session_id}/{artifact_id}/...
/{tenant}/data-pages/{page_key}/{version}/...
/{tenant}/exports/{export_id}/...
```

---

## 12. 种子数据

```sql
-- 租户/用户
INSERT INTO sys_user (user_id,tenant_id,username,name,email) VALUES
 ('u_admin','t1','admin','管理员','admin@example.com'),
 ('u_user','t1','user','普通用户','user@example.com');
-- 角色/权限略（由迁移脚本初始化）
-- Agent
INSERT INTO agent (agent_id,tenant_id,name,description,visibility,owner_id)
VALUES ('agt_demo','t1','Demo 助手','演示用','public','u_admin');
-- 模型配置（测试 Key 占位）
INSERT INTO llm_config (llm_config_id,tenant_id,name,provider,api_base_url,api_key_cipher,model_identifier,token_counter_key)
VALUES ('llm_demo','t1','Demo 模型','openai','https://api.example.com/v1','ENC(...)','demo-model','tiktoken');
-- 配额池
INSERT INTO model_quota_pool (pool_id,tenant_id,name,configured_tpm,mode)
VALUES ('pool_demo','t1','Demo 池',100000,'OBSERVE');
```

---

## 13. 验收标准

- [ ] DDL 可在 MySQL 8 直接执行。
- [ ] 核心表有租户/软删/审计字段。
- [ ] 索引覆盖列表/详情/统计查询。
- [ ] 大表分区/归档策略明确。
- [ ] Redis/OSS 命名有租户前缀。
- [ ] 种子数据可一键初始化。
