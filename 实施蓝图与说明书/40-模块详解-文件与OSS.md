# 40 模块详解：文件与 OSS

## 1. 职责与边界

**负责**
- 上传策略、配额、类型校验。
- 文件元数据、目录、个人文件。
- 预签名 URL（预览/下载）。
- 会话附件、复用、引用。
- 回收站、版本、恢复。
- 盘点、孤儿、归属、回收、容量、发布门禁。

**不负责**：Skill 包解析（Skill）、沙箱工作目录（Execution）、消息内容（Conversation）。

---

## 2. 数据模型

| 表 | 关键字段 |
|---|---|
| `file_object` | file_id, tenant_id, object_key, bucket, size, content_type, hash, owner_id, status, version, is_deleted |
| `file_directory` | directory_id, tenant_id, owner_id, parent_id, name, path |
| `file_reference` | id, tenant_id, file_id, ref_type, ref_id |
| `file_recovery` | id, file_id, recovery_version, expire_time, status |
| `session_attachment` | id, session_id, message_id, file_id |
| `oss_inventory_run` | run_id, tenant_id, status, started_at, finished_at, stats(JSON) |
| `oss_governance_action` | id, tenant_id, file_id, action, reason, user_id, create_time |

---

## 3. 上传模式

| 模式 | 流程 | 优点 | 缺点 | 适用 |
|---|---|---|---|---|
| 预签名直传 | 后端签名 → 前端直传 OSS → 回调登记 | 不占后端带宽 | 需处理回调/一致性 | 默认 |
| 后端中转 | 前端→后端→OSS | 简单、可扫描 | 占带宽/内存 | 小文件/高安全 |
| 分片上传 | 初始化→分片→合并 | 大文件/断点 | 复杂 | >100MB |
| 外部 URL 导入 | 后端拉取 | 方便 | SSRF/合规 | 受控 |

**默认**：预签名直传；单文件 ≤50MB；单用户配额 5GB。

---

## 4. 上传策略

```json
{
  "max_file_size": 52428800,
  "allowed_types": ["image/*","application/pdf","text/*","application/vnd.openxmlformats-*"],
  "max_files_per_message": 10,
  "user_quota_bytes": 5368709120,
  "virus_scan": true,
  "retention_days": 30
}
```

- 前端预校验；后端强校验（Content-Type/魔数/大小）。
- 压缩包扫描（防炸弹）；可执行文件拒绝。
- 文件名展示用原名；对象 key 用 UUID。
- 异步病毒扫描；失败隔离/删除。

---

## 5. 签名 URL

```
GET /files/{id}/access-url?mode=preview|download
→ 校验权限 → 生成短 TTL URL（5–15min）
→ 返回 url/expires_at
```

- 预览/下载分离；下载带 `Content-Disposition`。
- 不在 URL 放用户 token。
- 批量：`POST /files/access-urls`。
- 防盗链/Referer 白名单（可选）。

---

## 6. 文件模式

| 模式 | 说明 | 生命周期 |
|---|---|---|
| 个人文件 | 用户目录 | 用户删除/配额 |
| 会话附件 | 绑定消息/会话 | 随会话/回收站 |
| 产物 Artifact | Agent 生成 | 会话/下载 |
| Skill 包 | 版本化 | 版本保留 |
| 头像/人设 | 公开资源 | 替换/删除 |
| 数据网页 | 版本化 | 下架/回滚 |
| 导出 | 临时 | 7 天 |

---

## 7. 回收站与恢复

```
删除 → is_deleted=1 + recovery(expire=30d)
→ 恢复（校验配额/同名）
→ 到期物理删除（OSS 生命周期兜底）
```

- 回收站按用户隔离；管理员可看全部。
- 恢复/彻底删除审计。
- 物理删除前二次确认。

---

## 8. 版本与恢复版本

- OSS 版本控制；业务 `version`/`recovery_version`。
- 覆盖生成新版本；保留最近 N/30 天。
- 恢复 = 复制为新对象；审计。
- 版本列表/下载/对比（可选）。

---

## 9. 盘点与治理

```
创建盘点任务 → 拉 OSS 清单 → 与 DB 比对
→ missing/orphan/size mismatch → 报告
→ 人工核验/归属/回收 → 审计
```

| 状态 | 处理 |
|---|---|
| DB 有 + 引用有 | 正常 |
| DB 有 + 无引用 | 观察 → 回收 |
| 无 DB + 有对象 | 核验 → 补录/回收 |
| DB 有 + 无对象 | 告警/修复 |

**安全回收**：原因、影响、操作人、二次确认、可恢复版本、审计。

---

## 10. 容量与成本

| 指标 | 用途 |
|---|---|
| 总/已用容量 | 水位 |
| 按用户/类型 | 归因 |
| 增长趋势 | 扩容 |
| 孤儿/回收站/版本 | 可回收 |
| 流量/请求 | CDN/OSS 费用 |

**控制**：生命周期（临时 7d/回收站 30d/旧版本 30d）、冷热分层、压缩/去重、配额、告警。

---

## 11. 安全

- Bucket 私有；禁止公共读。
- 最小权限 RAM；应用只能访问指定前缀。
- 签名 URL 短 TTL；不记录完整 URL。
- 类型/大小/内容校验；病毒扫描。
- 对象 key 不可猜；防路径穿越。
- 跨租户路径前缀 + 权限校验。
- 日志脱敏；不记录文件内容。

---

## 12. API 清单

| 方法 | 路径 | 权限 |
|---|---|---|
| GET | `/files/upload-policy` | 登录 |
| GET | `/files` | 登录 |
| POST | `/files/uploads` | 登录 |
| GET | `/files/{id}` | 登录 |
| PATCH | `/files/{id}` | owner |
| POST | `/files/{id}/trash|restore` | owner |
| GET | `/files/{id}/access-url` | 登录 |
| POST | `/files/access-urls` | 登录 |
| GET/POST/PATCH/DELETE | `/file-directories*` | 登录 |
| GET | `/admin/oss/overview` | oss:file:govern |
| GET | `/admin/oss/files` | oss:file:govern |
| POST | `/admin/oss/files/{id}/reclaim` | oss:file:govern |
| POST | `/admin/oss/inventory-runs` | oss:file:govern |
| POST | `/admin/oss/release-gate/check` | oss:file:govern |

---

## 13. 失败与测试

| 场景 | 行为 |
|---|---|
| 上传超限 | 413 |
| 类型不符 | 415 |
| 病毒 | 隔离/删除 |
| 签名过期 | 403 |
| 跨用户访问 | 403 |
| 恢复冲突 | 409 |
| 盘点失败 | 重试/告警 |
| OSS 故障 | 重试/降级 |

**测试**：上传/预览/下载/回收/恢复/版本/盘点/孤儿/签名过期/路径穿越/跨租户。

---

## 14. 代码骨架

```python
async def presign_upload(user, req):
    policy = await upload_policy.get(user.tenant_id)
    policy.validate(req)
    key = f"{user.tenant_id}/files/{user.user_id}/{uuid4()}/{safe_name(req.name)}"
    url = await oss.presign_put(key, req.content_type, req.size, ttl=600)
    return {"upload_url": url, "object_key": key}

async def access_url(user, file_id, mode):
    f = await repo.get_or_404(file_id, user.tenant_id)
    assert_access(f, user)
    return await oss.presign_get(f.object_key, ttl=600, mode=mode)
```

---

## 15. 验收标准

- [ ] 文件不可公网直连；签名 URL 过期失效。
- [ ] 上传类型/大小/病毒校验。
- [ ] 删除可恢复；到期清理。
- [ ] 盘点发现孤儿/缺失；报告可导出。
- [ ] 回收有原因/审计/可恢复。
- [ ] 容量水位/发布门禁可阻断。
- [ ] 跨租户/跨用户不可访问。
