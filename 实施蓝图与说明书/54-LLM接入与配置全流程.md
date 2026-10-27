# 54 LLM 接入与配置全流程

> 先澄清：LLM 在平台里通常不是「上传一个文件」，而是**接入/注册一个可调用的模型端点**。
> 只有私有化模型权重才涉及「上传/部署」，平台仍只登记它的 OpenAI 兼容 endpoint。

---

## 1. 三种接入方式

| 方式 | 说明 | 适用 | 密钥位置 |
|---|---|---|---|
| 云 Provider 直连 | 填 base_url + api_key + model | 快速 | 平台加密存储 |
| 统一网关 | 平台/公司网关，内部再路由 | 多供应商 | 网关密钥 |
| 私有化模型 | vLLM/TGI/SGLang 暴露 OpenAI 兼容 API | 数据不出域 | 平台内网 |

**推荐**：统一网关（配额/计费/降级/可观测），不要让业务直连厂商。

---

## 2. 接入前准备

| 项 | 内容 |
|---|---|
| Provider 类型 | openai-compatible / anthropic / azure / deepseek / qwen / custom |
| Base URL | 如 `https://gateway.example.com/v1` |
| API Key | 有权限调用目标模型 |
| Model ID | 供应商实际模型名 |
| 上下文/输出上限 | 用于能力注册 |
| 价格 | 输入/输出/缓存单价 |
| 数据合规 | 是否允许数据出境/敏感数据 |
| 网络 | 平台到 endpoint 的出站白名单 |

---

## 3. 配置字段

| 字段 | 必填 | 说明 |
|---|---|---|
| name | 是 | 业务名称 |
| provider | 是 | 协议类型 |
| api_base_url | 否 | 为空用 Provider 默认 |
| api_key | 是 | 加密存储 |
| model_identifier | 是 | 模型 ID |
| price_input/output/cache | 是 | 每千 token |
| quota_limit | 否 | 0=不限 |
| model_quota_pool_id | 否 | 绑定配额池 |
| max_output_tokens | 是 | 默认输出上限 |
| token_counter_key | 是 | 计费口径 |
| supports_thinking | 否 | 思考 |
| supports_vision | 否 | 图片 |
| capability_overrides | 否 | 能力覆盖 |
| is_shared | 否 | 共享 |
| extra_config | 否 | 厂商特有 |
| status | 是 | 启用/停用 |

---

## 4. 全流程（10 步）

### Step 1：选择协议

- OpenAI 兼容：大多数国产/自建模型。
- Anthropic：messages/thinking/tool use。
- Azure：deployment/api-version。
- 自定义：适配器。

### Step 2：填基础信息

- 名称、Provider、Base URL、Model ID。
- 备注业务用途。

### Step 3：填密钥

- 只显示掩码；保存后不可回显。
- 轮换时输入新值，旧值立即失效。
- 密钥不写日志/前端/镜像。

### Step 4：能力识别

- 自动：调 Provider `list_models`/能力探测。
- 手动：填上下文、最大输出、工具/视觉/思考/JSON。
- 覆盖：代理层限制时手动收窄。
- 组合约束：JSON Schema + 工具互斥等。

### Step 5：价格与配额

- 输入/输出/缓存单价。
- 绑定配额池（共享/独占）。
- 额度上限（0=不限）。
- 计费口径 `token_counter_key`。

### Step 6：连通性测试

| 测试 | 内容 |
|---|---|
| 草稿测试 | 未保存表单值 |
| 已保存测试 | 读库配置 |
| 返回 | 延迟、模型响应、错误分类 |
| 错误 | 401/404/429/超时/模型不存在 |

### Step 7：保存/发布

- 保存后默认停用或启用（按策略）。
- 发布前能力/价格/配额校验。
- 审计记录。

### Step 8：绑定 Agent

- 选择模型 → 设为默认/备用。
- 配置绑定策略（thinking/vision）。
- 配置参数覆盖（temperature/top_p/max_output）。
- 保存后清 Agent 配置缓存。

### Step 9：对话验证

- 用测试 Agent 发消息。
- 验证：流式、工具、思考、视觉、JSON。
- 检查 token/费用/延迟。
- 失败回滚/调整。

### Step 10：上线与运维

- 灰度（按 Agent/用户/租户）。
- 监控错误/延迟/成本。
- 密钥轮换、能力变更、影响分析。
- 停用/删除（先解绑）。

---

## 5. 私有化模型接入

### 5.1 部署

```bash
# 示例：vLLM OpenAI 兼容
vllm serve /models/qwen2.5-32b \
  --served-model-name qwen2.5-32b \
  --port 8000 \
  --max-model-len 32768
```

### 5.2 注册

- Base URL：`http://vllm.internal:8000/v1`
- API Key：内网 token（可空但建议）
- Model ID：`qwen2.5-32b`
- 能力：按实际填写（工具/视觉/思考）
- 网络：平台 → vLLM 白名单

### 5.3 注意

- 上下文/并发/显存限制。
- 流式/工具调用兼容性。
- 版本升级/回滚。
- 监控 GPU/队列。

---

## 6. 模式

| 模式 | 说明 | 适用 |
|---|---|---|
| 直连 | 平台 → Provider | 单供应商 |
| 网关 | 平台 → 公司网关 → Provider | 多供应商 |
| 共享 | 多 Agent 共用配置 | 降本 |
| 独占 | 单 Agent/业务 | 隔离 |
| 流式 | SSE | 对话 |
| 非流式 | 阻塞 | 系统调用 |
| 思考 | thinking | 复杂推理 |
| 视觉 | vision | 图片 |
| JSON | response_format | 结构化 |
| 备用 | fallback | 故障 |
| OBSERVE/ENFORCE | 配额 | 成本 |

---

## 7. 校验与错误

| 校验 | 规则 | 错误 |
|---|---|---|
| URL | http/https、域名 | 400 |
| Key | 非空、长度 | 400 |
| Model | 非空、存在 | 404 |
| 价格 | ≥0 | 400 |
| max_output | >0 | 400 |
| 能力 | 覆盖在允许范围 | 422 |
| 配额池 | 存在/未归档 | 404/409 |
| 绑定 | Agent 可见 | 403 |

**常见错误**：401 密钥无效、404 模型不存在、429 限流、timeout 网络、unsupported 参数/能力。

---

## 8. 变更与影响分析

| 变更 | 影响 | 处理 |
|---|---|---|
| 价格 | 新调用新价 | 历史不变 |
| 能力收窄 | 绑定参数失效 | 预览清理 |
| 删除 | Agent 解绑 | 影响列表 + 确认 |
| 停用 | 会话回退/报错 | 提示 + 备用 |
| 密钥轮换 | 旧调用失败 | 双版本过渡 |
| 配额池切换 | 准入变化 | 版本 + 原因 |

**能力变更影响**：保存前展示将清理的 Agent 绑定字段；用户确认后保存 + 审计。

---

## 9. 安全

- 密钥加密（KMS/Vault + AES-GCM）。
- 只在网关解密；Runtime 不持有长期密钥。
- 日志/调用链不记录 prompt/密钥。
- 出站白名单；禁 SSRF。
- 数据分级：敏感数据路由到私有化模型。
- 供应商合规评估。

---

## 10. API 清单

| 方法 | 路径 | 说明 |
|---|---|---|
| GET | `/llm-configs/providers` | Provider/表单 schema |
| POST | `/llm-configs/ping` | 草稿测试 |
| GET/POST | `/llm-configs` | 列表/创建 |
| GET/PUT/DELETE | `/llm-configs/{id}` | 详情/更新/删除 |
| POST | `/llm-configs/{id}/ping` | 已保存测试 |
| POST | `/llm-configs/{id}/capability-impact` | 能力影响 |
| GET | `/llm-configs/{id}/affected-agents` | 删除影响 |
| GET | `/llm-configs/{id}/agents` | 绑定 Agent |
| PUT | `/llm-configs/{id}/status` | 启停 |
| GET/POST | `/model-quota-pools` | 配额池 |

---

## 11. 数据模型

```sql
llm_config(
  llm_config_id, tenant_id, name, provider, api_base_url,
  api_key_cipher, model_identifier, price_input, price_output, price_cache,
  quota_limit, model_quota_pool_id, max_output_tokens, token_counter_key,
  supports_thinking, supports_vision, capability_overrides, is_shared,
  extra_config, status, owner_id, is_deleted
)
```

---

## 12. 验收标准

- [ ] 至少 2 个 Provider/3 个模型可接入。
- [ ] 密钥加密、掩码、轮换、删除可用。
- [ ] 连通性测试返回延迟/错误分类。
- [ ] 能力/参数/配额校验生效。
- [ ] 绑定 Agent 后可对话（流式/工具/思考）。
- [ ] 删除/停用前有影响分析。
- [ ] 调用可追溯 token/费用/延迟。
- [ ] 私有化模型可接入。
