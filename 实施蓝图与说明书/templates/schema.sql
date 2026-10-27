-- Cloud Agent Platform - core schema (MySQL 8)
-- Convention: utf8mb4, soft delete, tenant_id on every business table.

SET NAMES utf8mb4;

CREATE TABLE IF NOT EXISTS sys_user (
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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS sys_role (
  role_id VARCHAR(32) PRIMARY KEY,
  tenant_id VARCHAR(32) NOT NULL,
  code VARCHAR(32) NOT NULL,
  name VARCHAR(64) NOT NULL,
  description VARCHAR(255) NOT NULL DEFAULT '',
  is_system TINYINT NOT NULL DEFAULT 0,
  is_deleted TINYINT NOT NULL DEFAULT 0,
  create_time DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  KEY idx_role_tenant (tenant_id, code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS sys_permission (
  permission_id VARCHAR(32) PRIMARY KEY,
  code VARCHAR(64) NOT NULL,
  name VARCHAR(64) NOT NULL,
  resource VARCHAR(64) NOT NULL,
  action VARCHAR(32) NOT NULL,
  group_code VARCHAR(32) NOT NULL,
  sort_order INT NOT NULL DEFAULT 0,
  KEY idx_perm_group (group_code, sort_order)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS sys_user_role (
  user_id VARCHAR(32) NOT NULL,
  role_id VARCHAR(32) NOT NULL,
  PRIMARY KEY (user_id, role_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS sys_role_permission (
  role_id VARCHAR(32) NOT NULL,
  permission_id VARCHAR(32) NOT NULL,
  PRIMARY KEY (role_id, permission_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS sys_resource_collaborator (
  id VARCHAR(32) PRIMARY KEY,
  tenant_id VARCHAR(32) NOT NULL,
  resource_type VARCHAR(32) NOT NULL,
  resource_id VARCHAR(32) NOT NULL,
  user_id VARCHAR(32) NOT NULL,
  role VARCHAR(16) NOT NULL DEFAULT 'editor',
  is_deleted TINYINT NOT NULL DEFAULT 0,
  create_time DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  KEY idx_collab (tenant_id, resource_type, resource_id, user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS sys_api_key (
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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS sys_audit_log (
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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS agent (
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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS agent_skill (
  id VARCHAR(32) PRIMARY KEY,
  tenant_id VARCHAR(32) NOT NULL,
  agent_id VARCHAR(32) NOT NULL,
  skill_id VARCHAR(32) NOT NULL,
  skill_version INT NULL,
  allow_user_cancel TINYINT NOT NULL DEFAULT 1,
  is_deleted TINYINT NOT NULL DEFAULT 0,
  UNIQUE KEY uk_agent_skill (agent_id, skill_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS agent_llm_binding (
  id VARCHAR(32) PRIMARY KEY,
  tenant_id VARCHAR(32) NOT NULL,
  agent_id VARCHAR(32) NOT NULL,
  llm_config_id VARCHAR(32) NOT NULL,
  is_default TINYINT NOT NULL DEFAULT 0,
  binding_policy JSON NULL,
  parameter_config JSON NULL,
  version INT NOT NULL DEFAULT 1,
  UNIQUE KEY uk_binding (agent_id, llm_config_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS skill (
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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS skill_version (
  id VARCHAR(32) PRIMARY KEY,
  skill_id VARCHAR(32) NOT NULL,
  version_number INT NOT NULL,
  content_hash VARCHAR(64) NOT NULL,
  manifest JSON NULL,
  object_prefix VARCHAR(512) NOT NULL,
  create_user_id VARCHAR(64) NULL,
  create_time DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  UNIQUE KEY uk_skill_ver (skill_id, version_number)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS session (
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
  KEY idx_session_user (tenant_id, user_id, is_deleted, last_active_time),
  KEY idx_session_agent (tenant_id, agent_id, is_deleted)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS message (
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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS turn (
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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS llm_config (
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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS model_quota_pool (
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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS usage_llm_call (
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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS sandbox_config (
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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS sandbox_instance (
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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS file_object (
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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS sys_notification (
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
  KEY idx_notify (tenant_id, user_id, read_status, create_time)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Seed (optional)
INSERT IGNORE INTO sys_user (user_id, tenant_id, username, name, email)
VALUES ('u_admin','t1','admin','管理员','admin@example.com'),
       ('u_user','t1','user','普通用户','user@example.com');

INSERT IGNORE INTO agent (agent_id, tenant_id, name, description, visibility, owner_id)
VALUES ('agt_demo','t1','Demo 助手','演示用 Agent','public','u_admin');
