# 56 MCP 接入与工具暴露全流程

## 1. MCP 是什么

MCP（Model Context Protocol）是标准化的工具/资源接入协议。平台把 MCP Server 的工具发现出来，转成模型可调用的工具。

```
MCP Server（远程/本地）
  ├─ tools/list
  ├─ tools/call
  └─ resources/prompts（可选）
        ▲
        │ HTTP/SSE/stdio
   Runtime MCP Client
        │
   Agent 配置（启停/暴露/超时）
```

---

## 2. 接入方式

| 传输 | 说明 | 适用 |
|---|---|---|
| HTTP/Streamable | 远程服务，推荐 | 生产 |
| SSE | 旧版远程 | 兼容 |
| stdio | 本地进程 | 开发/单机 |

**生产建议**：HTTP + 认证 + 网关；不要让 Runtime 直接 stdio 启动任意命令。

---

## 3. 接入前准备

| 项 | 内容 |
|---|---|
| URL | MCP Server 地址 |
| 认证 | Bearer/API Key/OAuth |
| 工具清单 | 有哪些工具 |
| 参数 Schema | 必填/类型/枚举 |
| 超时 | list_tools/call_tool |
| 网络 | 平台到 MCP 的出站白名单 |
| 数据合规 | 是否允许数据出域 |

---

## 4. 配置字段

| 字段 | 必填 | 说明 |
|---|---|---|
| alias | 是 | 平台内唯一别名 |
| url | 是 | MCP endpoint |
| transport | 是 | http/sse/stdio |
| headers | 否 | 只存变量引用模板 |
| variables | 否 | 变量定义 |
| tool_exposure | 是 | all/selected |
| tool_filter | 否 | 选中的工具 |
| list_tools_timeout_ms | 否 | 默认 10s |
| call_tool_timeout_ms | 否 | 默认 30s |
| enabled | 是 | 启停 |

---

## 5. 全流程（10 步）

### Step 1：创建配置

- 选择 Agent → MCP → 新建。
- 填 alias/url/transport。
- 配置 headers：只能用变量引用（如 `${sys_mcp_token}`），不存明文。

### Step 2：草稿测试

```
POST /agents/{agent_id}/mcp-servers/test
→ 连接 → tools/list → 返回工具/延迟/错误
```

- 检查：连通、认证、工具数量、Schema。
- 失败：401/404/超时/DNS/证书。

### Step 3：选择暴露

- `all`：暴露全部（含未来新增）。
- `selected`：只暴露勾选工具。
- 建议：工具多时用 selected，减少上下文污染。

### Step 4：保存

- 保存配置；默认停用或启用。
- 加密 header 变量值（如有）。
- 审计。

### Step 5：已保存测试

```
POST /agents/{agent_id}/mcp-servers/{id}/test
```

- 用保存配置；验证工具列表/延迟。
- 记录最近测试时间/结果。

### Step 6：启用

```
PUT /agents/{agent_id}/mcp-servers/{id}/enabled {enabled:true}
```

- Runtime 下次加载时发现工具。
- 清 Agent 配置缓存。

### Step 7：绑定/使用

- 工具出现在 Agent 的工具清单。
- 运行时按 `tool_exposure` 过滤。
- 模型可调用；参数 Schema 校验。

### Step 8：调用

```
tools/call {name, arguments}
→ 校验权限/参数/风险
→ 调 MCP
→ 结果脱敏/截断
→ 回填模型
```

- 超时/重试/熔断。
- 结果大小限制；大结果落 OSS，只回摘要。

### Step 9：监控

- 工具调用次数/成功率/延迟。
- 错误分类（认证/超时/Schema/服务）。
- 工具列表变化（新增/删除）。
- 告警。

### Step 10：变更/下线

- 停用：立即从工具清单移除。
- 删除：影响 Agent 提示；确认后删。
- 认证轮换：更新变量/重启连接。
- 版本升级：先测试再启用。

---

## 6. 认证与密钥

| 方式 | 配置 | 说明 |
|---|---|---|
| Bearer | `Authorization: Bearer ${sys_mcp_token}` | 常用 |
| API Key | `X-API-Key: ${sys_mcp_key}` | |
| OAuth | 平台代管 token | 需刷新 |
| mTLS | 证书 | 内网 |

**规则**
- Header 只存变量模板；真实值加密存储在系统变量/密钥库。
- 日志只出现变量名，不出现值。
- 轮换不重启 Agent；下次调用生效。
- 禁止把密钥写进 MCP URL/query。

---

## 7. 工具暴露与命名

### 7.1 暴露

| 模式 | 行为 | 适用 |
|---|---|---|
| all | 全部工具 | 工具少/稳定 |
| selected | 勾选工具 | 工具多/精细 |

### 7.2 命名冲突

- 多个 MCP 同名工具：加 `alias__tool` 前缀。
- 与内置/Skill 同名：同样加前缀。
- 名称稳定；变更需版本/提示。

### 7.3 描述

- 工具描述要说明「何时用/不用」。
- 参数 Schema 完整；必填/枚举/范围。
- 长文档按需加载，不进入上下文。

---

## 8. 安全

| 风险 | 控制 |
|---|---|
| SSRF | URL 白名单；禁内网/元数据 |
| 恶意工具 | 审核/签名/沙箱 |
| 工具注入 | 结果标记为数据；不作为指令 |
| 越权 | 工具级权限/Agent 授权 |
| 密钥泄露 | 变量引用/加密/脱敏 |
| 滥用 | 限流/配额/超时 |
| 供应链 | 服务方评估/版本锁定 |

**红线**：MCP Server 不能直接访问平台 DB；不能执行任意本地命令（stdio 仅开发）。

---

## 9. 失败与降级

| 失败 | 行为 |
|---|---|
| 连接失败 | 标记不可用；Agent 跳过该 Server |
| 认证失败 | 提示更新密钥 |
| 超时 | 返回超时给模型；重试 1 次 |
| Schema 不匹配 | 拒绝调用；记录 |
| 工具被删除 | 下次发现移除；提示 Agent 编辑者 |
| 结果过大 | 截断/落 OSS |
| 服务 5xx | 熔断 30s；降级 |

**原则**：单个 MCP 故障不阻塞整轮对话；模型可换工具/直接回答。

---

## 10. 模式

| 模式 | 说明 | 适用 |
|---|---|---|
| HTTP | 远程 | 生产 |
| SSE | 远程旧版 | 兼容 |
| stdio | 本地 | 开发 |
| all | 全暴露 | 工具少 |
| selected | 精选 | 工具多 |
| per-agent | 每 Agent 独立 | 默认 |
| shared server | 多 Agent 共用 | 平台服务 |
| sync | 同步调用 | 短任务 |
| async | 异步/回调 | 长任务 |

---

## 11. API 清单

| 方法 | 路径 | 说明 |
|---|---|---|
| GET | `/agents/{id}/mcp-servers` | 列表 |
| POST | `/agents/{id}/mcp-servers` | 新建 |
| POST | `/agents/{id}/mcp-servers/test` | 草稿测试 |
| GET/PUT/DELETE | `/agents/{id}/mcp-servers/{config_id}` | 详情/更新/删除 |
| PUT | `/agents/{id}/mcp-servers/{config_id}/enabled` | 启停 |
| POST | `/agents/{id}/mcp-servers/{config_id}/test` | 已保存测试 |

---

## 12. 数据模型

```sql
agent_mcp_server(
  config_id, tenant_id, agent_id, enabled, description,
  config JSON,           -- transport/url/alias/headers/variables/tool_exposure/tool_filter/timeouts
  updated_at
)
```

`headers` 只存变量引用模板；真实值在 `system_variable`/密钥库。

---

## 13. UI 流程

1. Agent 详情 → 工具 → MCP Server。
2. 新建：别名/URL/传输/认证。
3. 测试：显示工具列表/延迟/错误。
4. 选择暴露：全部/精选。
5. 保存/启用。
6. 查看调用统计/错误。
7. 停用/删除/轮换密钥。

---

## 14. 验收标准

- [ ] HTTP/SSE 接入可用（stdio 仅开发）。
- [ ] 草稿/已保存测试返回工具/延迟/错误。
- [ ] all/selected 暴露生效。
- [ ] 工具命名冲突有前缀。
- [ ] 认证变量不落明文/日志。
- [ ] 调用超时/重试/熔断/降级。
- [ ] MCP 故障不阻塞整轮。
- [ ] 工具调用可观测/可审计。
