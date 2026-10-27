# 36 模块详解：Agent 与 Skill

## 1. Agent 职责与边界

**负责**
- Agent 定义：名称、描述、系统提示词、人设、可见性。
- 绑定：模型、Skill、子 Agent、系统工具、MCP、变量、模板、引用源、快捷开始、卡片。
- 生命周期：创建、编辑、发布、停用、软删、转移 owner。
- 协作：owner、collaborator、可见性。

**不负责**：会话状态（Conversation）、模型密钥（Model）、Skill 包解析（Skill）。

---

## 2. Agent 数据模型

| 表 | 关键字段 |
|---|---|
| `agent` | agent_id, tenant_id, name, description, system_prompt, avatar_object_key, persona_object_key, persona_type, model, multi_agent_enabled, sub_agent_stateful, routing_description, sandbox_mode, sandbox_config_id, shared_pool_size, tools(JSON), visibility, owner_id, status, version |
| `agent_skill` | agent_id, skill_id, skill_version, allow_user_cancel, is_deleted |
| `agent_sub_agent` | agent_id, sub_agent_id, foreground_timeout_seconds, total_budget_seconds, report_enabled |
| `agent_llm_binding` | agent_id, llm_config_id, is_default, binding_policy(JSON), parameter_config(JSON), version |
| `agent_tool_config` | agent_id, tool_type, enabled, config(JSON) |
| `agent_mcp_server` | config_id, agent_id, enabled, config(JSON) |
| `agent_variable` | var_id, agent_id, var_key, value_cipher, description, status, value_type |
| `agent_template` | template_id, agent_id, biz_id, name, content, reference_source_ids |
| `agent_quick_start` | id, agent_id, biz_id, label, prompt_text, enabled, order |
| `agent_biz_group` | id, agent_id, biz_id, biz_name, order |
| `agent_reference_source` | id, agent_id, source_type, group_type, query_url, selection_mode, cascade_level_names, llm_description, enabled, order |
| `agent_card_config` | agent_id, card_key, template, enabled, is_customized |

---

## 3. Agent 生命周期

```
draft → active → disabled → deleted
         │
         └─ update (version+1，运行时按版本/快照)
```

- **draft**：仅 owner 可见，可编辑。
- **active**：按 visibility 可见/可聊。
- **disabled**：不可新建会话；已有会话可读。
- **deleted**：软删；解绑技能/子 Agent；保留审计。
- 编辑不阻塞正在运行的轮次：运行时用「配置快照」或版本号。

### 删除影响

删除前必须展示：
- 绑定的会话数；
- 定时任务；
- 作为子 Agent 被哪些 Agent 引用；
- 绑定的 Skill/模型（不删，只解绑）。
用户确认后单事务软删 + 解绑。

---

## 4. Agent 模式

| 模式 | 配置 | 行为 | 适用 |
|---|---|---|---|
| 单 Agent | `multi_agent_enabled=0` | 单轮 ReAct | 大多数场景 |
| 多 Agent | `multi_agent_enabled=1` | 规划 + 子 Agent | 复杂任务 |
| 有状态子 Agent | `sub_agent_stateful=true` | 子会话保留历史 | 长任务/连续追问 |
| 无状态子 Agent | `false` | 每次新建上下文 | 独立任务 |
| 无沙箱 | `sandbox_mode=none` | 只用工具 | 问答/查询 |
| 会话沙箱 | `sandbox_mode=session` | 会话绑定沙箱 | 代码/文件 |
| 共享池 | `sandbox_mode=shared` | 共享沙箱槽位 | 低并发短任务 |

---

## 5. 绑定规则

### 5.1 模型

- 可绑定多个，指定默认。
- 每个绑定可有独立参数覆盖（temperature/top_p/thinking/vision/response format）。
- 删除模型前展示受影响 Agent 并解绑。
- 会话可临时切换模型；切换时迁移 thinking 状态。

### 5.2 Skill

- 绑定 `skill_id` + 可选 `skill_version`（建议固定）。
- 校验 Skill 存在、未删除、对当前用户可用。
- 不可用原因：已删除/禁用/风险/沙箱要求不满足/个人未启用。
- 用户级偏好：用户可禁用某 Agent 的某 Skill。

### 5.3 子 Agent

- 选择当前用户可见的 Agent。
- 配置前台超时、总预算、是否回传报告。
- 防循环：A→B→A 检测/最大深度。
- 子 Agent 不能删除被引用关系；删除前展示。

### 5.4 工具/MCP

- 系统工具：白名单 + 参数 Schema + 风险等级。
- MCP：URL/transport/headers（变量模板）/tool_exposure（all/selected）/超时。
- 测试：草稿测试 + 已保存测试；返回工具列表/延迟/错误。

### 5.5 变量/模板/引用源/快捷开始

- 变量 key：`agt_*`，值加密，掩码展示。
- 模板：按 `biz_id` 管理，可引用变量/引用源。
- 引用源：查询 URL、单选/级联、LLM 描述；运行时只传选中项。
- 快捷开始：按 `biz_id` 分组，排序、启停。

---

## 6. Skill 规范

### 6.1 包结构

```
my-skill/
  SKILL.md
  manifest.json      # 可选
  scripts/           # 可选（需沙箱）
  references/
  assets/
  tests/
```

### 6.2 SKILL.md

```yaml
---
name: bom-purchase-type-check
display_name: EBOM 采购类型校验
description: 对 EBOM 房间中的 BOM 行进行采购类型校验...
version: 1.2.0
license: internal
sandbox: required
execution_mode: on_demand
---
```

正文必须包含：适用场景、输入、输出、步骤、边界、依赖、示例。

### 6.3 manifest（可选）

```json
{
  "tools": [{ "name": "check_bom", "description": "...", "parameters": {} }],
  "requires": { "mcp": ["xbom-ebom-mcp"], "sandbox": true },
  "permissions": ["bom:read"],
  "entry": "scripts/main.py"
}
```

---

## 7. Skill 生命周期

```
upload → parse/validate → store(OSS+DB) → evaluate → publish
→ bind → invoke → feedback → new version → rollback/deprecate
```

| 阶段 | 校验 | 失败 |
|---|---|---|
| 上传 | 大小/类型/文件数 | 明确错误 |
| 解析 | frontmatter/name/description | 拒绝 |
| 安全 | 路径穿越/脚本/压缩炸弹 | 拒绝/隔离 |
| 存储 | OSS + DB 事务/补偿 | 回滚 |
| 评估 | AI/人工 | 标记风险 |
| 发布 | 可见性/分类/标签 | — |
| 绑定 | 存在/可用/版本 | 提示 |
| 调用 | 模式/沙箱/权限 | 降级/报错 |

### 版本

- 每次上传生成不可变版本（version_number/content_hash/manifest）。
- current_version 指针；回滚 = 切指针。
- Agent 绑定可固定版本（推荐）或跟随最新。
- 版本差异可查看；旧版本保留。

---

## 8. Skill 执行模式

| 模式 | 加载 | 优点 | 缺点 | 适用 |
|---|---|---|---|---|
| inline | 说明注入提示词 | 快、简单 | 占上下文 | 轻量规则 |
| on_demand | 按需读取 | 省上下文 | 多一次读取 | 中等复杂 |
| subagent | 独立子会话 | 隔离、长任务 | 成本高 | 复杂任务 |

**选择**：规则/格式→inline；脚本/多文件→on_demand；多步工具/长耗时→subagent。

---

## 9. 个人 Skill 与共享

| 能力 | 规则 |
|---|---|
| 创建 | 从对话或上传；默认关闭 |
| 配额 | 每人数量/大小限制 |
| 生效 | 本人 + 本人使用的 Agent |
| 共享 | 指定用户；接收方加入/启停 |
| 治理 | 管理员禁用/风险/审计 |
| 转正 | 另存为平台 Skill（需审核） |

**偏好**：`(user_id, agent_id, skill_id) -> enabled`；优先于默认。

---

## 10. 评估与治理

### 自动评估维度

- 触发条件是否明确；
- 输入/输出是否完整；
- 步骤是否可执行；
- 是否含危险操作；
- 依赖是否声明；
- 示例是否充分。

输出：评分、风险等级、改进建议。高风险需人工审核。

### 治理

- 分类/标签/可见性；
- 禁用（全局）；
- 审计（上传/修改/删除/绑定/调用）；
- 删除保护：被 Agent 绑定/被共享时提示；
- 下载鉴权 + 短签名 URL。

---

## 11. API 清单（节选）

| 方法 | 路径 | 权限 |
|---|---|---|
| GET/POST | `/agents` | agent:view / create |
| GET/PUT/DELETE | `/agents/{id}` | view/update/delete |
| GET/PUT | `/agents/{id}/skills` | view/update |
| GET/PUT | `/agents/{id}/sub-agents` | view/update |
| GET/PUT | `/agents/{id}/llm-configs` | view/update |
| GET/PUT | `/agents/{id}/variables` | view/update |
| GET/PUT | `/agents/{id}/templates` | view/update |
| GET/PUT | `/agents/{id}/quick-starts` | view/update |
| POST | `/skills/upload` | skill:create |
| GET | `/skills` `/skills/{id}` | skill:view |
| POST | `/skills/{id}/evaluate` | skill:update |
| POST | `/skills/{id}/invoke` | skill:invoke |
| GET | `/me/skills` | 登录 |

---

## 12. 失败与边界

| 场景 | 行为 |
|---|---|
| 绑定的 Skill 被删 | 标记不可用；运行时跳过并提示 |
| 模型被删 | 解绑；会话回退默认/报错 |
| 子 Agent 循环 | 检测并拒绝 |
| Skill 包过大 | 拒绝上传 |
| 个人 Skill 未启用 | 不进入工具列表 |
| 无权限绑定 | 403 |
| 版本回滚 | 新会话用旧版本；运行中不变 |

---

## 13. 测试

- Agent CRUD/可见性/协作者/转移。
- 绑定校验/不可用原因。
- Skill 上传/解析/版本/回滚/路径穿越。
- 个人 Skill 默认关闭/共享/偏好。
- 删除影响分析。
- 运行时加载 inline/on_demand/subagent。

---

## 14. 代码骨架

```python
class AgentService:
    async def create(self, cmd: CreateAgent, user: UserContext) -> Agent:
        self._check_permission(user, "agent:create")
        agent = Agent.create(cmd, tenant=user.tenant_id, owner=user.user_id)
        async with self.uow:
            await self.repo.add(agent)
            await self.audit.record("agent.created", agent, user)
        return agent

    async def delete(self, agent_id, user):
        agent = await self.repo.get_or_404(agent_id, user.tenant_id)
        self._assert_owner_or_admin(agent, user)
        impact = await self.impact.analyze(agent_id)
        async with self.uow:
            await self.repo.soft_delete(agent_id)
            await self.bindings.unbind_all(agent_id)
            await self.audit.record("agent.deleted", agent, user, impact)
```

---

## 15. 验收标准

- [ ] 创建 Agent → 绑定模型/Skill → 对话可用。
- [ ] 可见性/协作者/转移正确。
- [ ] 删除前展示影响，删除后解绑。
- [ ] Skill 上传/版本/回滚/调用闭环。
- [ ] 个人 Skill 默认关闭、共享/偏好生效。
- [ ] 不可用绑定有明确原因。
- [ ] 所有变更审计。
