# 55 Skill 上传与注册全流程

## 1. Skill 是什么

Skill 是**可版本化、可评估、可治理的能力包**，通常包含：

- `SKILL.md`：说明 + frontmatter（名称/描述/版本/沙箱要求/执行模式）。
- `manifest.json`：可选，工具/依赖/权限声明。
- `scripts/`：可选，需沙箱。
- `references/`、`assets/`、`tests/`：可选。

平台把 Skill 解析成「工具/子 Agent 能力」，供 Agent 绑定和 Runtime 调用。

---

## 2. 三条上传路径

| 路径 | 入口 | 适用 | 版本 |
|---|---|---|---|
| 平台 Skill 上传 | 管理端/建设者 | 团队共享 | 版本化 |
| 个人 Skill 上传 | 个人设置/对话 | 个人使用 | 版本化 |
| GitLab 同步 | 管理端配置 | 团队仓库 | 自动版本 |

> 「上传」本质是：解析 → 校验 → 存储 → 评估 → 发布 → 绑定。

---

## 3. 上传前准备

### 3.1 目录

```
my-skill/
  SKILL.md              # 必需
  manifest.json         # 可选
  scripts/              # 可选
  references/           # 可选
  assets/               # 可选
  tests/                # 可选
```

### 3.2 SKILL.md

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

正文建议：适用场景、输入、输出、步骤、边界、依赖、示例、失败处理。

### 3.3 manifest（可选）

```json
{
  "tools": [{ "name": "check_bom", "description": "...", "parameters": {} }],
  "requires": { "mcp": ["xbom-ebom-mcp"], "sandbox": true },
  "permissions": ["bom:read"],
  "entry": "scripts/main.py"
}
```

---

## 4. 全流程（10 步）

### Step 1：选择入口

- 平台：`/api/skills/upload`
- 个人：`/api/me/skills/upload`
- GitLab：`/api/gitlab-sync/run`

### Step 2：上传文件

- 支持单个 `SKILL.md` 或 ZIP。
- 限制：单包 ≤20MB、文件数 ≤500、无二进制可执行（或隔离）。
- 前端预校验；后端强校验。

### Step 3：解析

- 解析 frontmatter：name/display_name/description/version/sandbox/execution_mode。
- 解析 manifest：tools/requires/permissions/entry。
- 校验必填/格式/长度/版本号。
- 提取文件清单/哈希。

### Step 4：安全校验

| 检查 | 处理 |
|---|---|
| 路径穿越 | 拒绝 |
| 压缩炸弹 | 拒绝 |
| 超大文件 | 拒绝 |
| 可执行/脚本 | 标记风险，需沙箱 |
| 密钥/Token | 扫描/拒绝 |
| 恶意依赖 | 扫描/隔离 |
| 文件编码 | 统一 UTF-8 |

### Step 5：存储

- OSS：`/{tenant}/skills/{skill_id}/{version}/...`
- DB：`skill`、`skill_version`、`skill_file`。
- 事务 + 补偿；哈希校验。
- 版本不可变。

### Step 6：评估

- AI 评估：触发条件、输入输出、步骤、风险、依赖、示例。
- 输出评分/风险/建议。
- 高风险：人工审核/禁用。

### Step 7：发布

- 设置可见性（public/restricted/private）。
- 分类/标签。
- 当前版本指针。
- 审计。

### Step 8：绑定 Agent

- 选择 Skill → 固定版本/跟随最新。
- 校验：存在/未删/启用/权限/沙箱。
- 不可用原因展示。

### Step 9：测试调用

- 用测试 Agent/`/skills/{id}/invoke`。
- 验证：工具选择、参数、输出、超时、沙箱。
- 看调用链/日志。

### Step 10：迭代

- 新版本上传 → 评估 → 发布。
- 回滚到旧版本（切指针）。
- 下架/删除（先解绑）。
- 反馈/用量/失败分析。

---

## 5. 校验规则

| 项 | 规则 |
|---|---|
| name | 小写字母/数字/连字符，≤64 |
| description | 10–500 字 |
| version | semver |
| 文件路径 | 相对、无 `..`、无绝对路径 |
| 文件数 | ≤500 |
| 包大小 | ≤20MB |
| 脚本 | 声明沙箱；否则拒绝 |
| 依赖 | 明确声明；禁止隐式网络 |
| 权限 | 最小化；需审批（可选） |

**错误示例**：缺少 SKILL.md、frontmatter 非法、版本重复、路径穿越、包过大、脚本未声明沙箱。

---

## 6. 版本与回滚

```
v1 上传 → 发布 → Agent 绑定 v1
v2 上传 → 评估 → 发布 → 新会话用 v2（或手动切换）
v2 有问题 → 回滚到 v1（切 current_version）
```

- 版本不可变；哈希/文件保留。
- Agent 绑定可固定/最新；建议固定。
- 回滚不影响运行中的轮次。
- 版本差异可查看。

---

## 7. 三种执行模式

| 模式 | 加载 | 适用 | 配置 |
|---|---|---|---|
| inline | 说明注入提示词 | 轻量规则 | `execution_mode=inline` |
| on_demand | 按需读取 | 中等复杂 | `on_demand` |
| subagent | 独立子会话 | 复杂/长任务 | `subagent` |

**沙箱要求**：`required/optional/none`；required 必须绑定可用沙箱。

---

## 8. 个人 Skill

| 能力 | 规则 |
|---|---|
| 创建 | 从对话/上传 |
| 默认 | 关闭，手动启用 |
| 配额 | 数量/大小限制 |
| 生效 | 本人 + 本人 Agent |
| 共享 | 指定用户；接收方加入/启停 |
| 治理 | 管理员禁用/风险/审计 |
| 转正 | 另存为平台 Skill（审核） |

**偏好**：`(user_id, agent_id, skill_id)` 启用/禁用。

---

## 9. GitLab 同步

### 配置

- base_url、project_id、branch、directory、token（加密）。
- 目录约定：每个含 `SKILL.md` 的子目录 = 一个 Skill。

### 流程

```
预览 → 新增/更新/跳过/冲突
→ 执行 → 解析/校验/存储/版本
→ 结果明细 → 失败重试
```

### 冲突

- 平台已存在同名：更新/跳过/另存。
- 平台手动改过：标记冲突，人工确认。
- 记录 commit/branch/时间/操作人。

---

## 10. 安全

- 上传扫描（脚本/依赖/密钥/路径/炸弹）。
- 脚本只在沙箱；默认无网络/白名单。
- 权限显式声明；未声明不得访问。
- 引用外部内容标注来源，防注入。
- 下载鉴权 + 短签名 URL。
- 个人 Skill 不进公共目录（除非转正）。
- 删除保护：被绑定/共享时提示。

---

## 11. API 清单

| 方法 | 路径 | 说明 |
|---|---|---|
| POST | `/skills/upload` | 平台上传 |
| GET | `/skills` | 列表/分组 |
| GET/PUT/DELETE | `/skills/{id}` | 详情/更新/删除 |
| GET | `/skills/{id}/versions` | 版本 |
| POST | `/skills/{id}/rollback` | 回滚 |
| POST | `/skills/{id}/evaluate` | 评估 |
| GET | `/skills/{id}/evaluation` | 评估结果 |
| POST | `/skills/{id}/invoke` | 调用 |
| GET | `/skills/{id}/download` | 下载 |
| POST | `/me/skills/upload` | 个人上传 |
| GET | `/me/skills` | 我的 Skill |
| PUT | `/me/skills/{id}/enabled` | 启停 |
| POST | `/me/skills/{id}/sharing` | 共享 |
| POST | `/gitlab-sync/run` | 同步 |

---

## 12. 数据模型

```sql
skill(skill_id, tenant_id, name, description, execution_mode,
      sandbox_requirement, category_id, owner_id, source, is_private,
      current_version, status, is_deleted)
skill_version(id, skill_id, version_number, content_hash, manifest,
              object_prefix, create_user_id)
skill_file(id, skill_id, version_id, path, size, content_type, hash)
personal_skill(skill_id, owner_id, current_version, enabled, governance_status, risk_level)
personal_skill_share(share_id, skill_id, owner_id, target_user_id, enabled)
```

---

## 13. 验收标准

- [ ] 单文件/ZIP 上传成功并可解析。
- [ ] 非法包被拒绝（路径/大小/脚本/编码）。
- [ ] 版本/回滚/下载可用。
- [ ] 评估输出评分/风险/建议。
- [ ] 绑定 Agent 后调用成功（inline/on_demand/subagent）。
- [ ] 个人 Skill 默认关闭/共享/偏好生效。
- [ ] GitLab 同步可预览/重试/冲突处理。
- [ ] 所有变更审计。
