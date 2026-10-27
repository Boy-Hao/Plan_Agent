# 76 MCP 协议与工具生态

## 1. MCP 是什么

MCP（Model Context Protocol）用 JSON-RPC 标准化「模型 ↔ 工具/资源/提示词」：

```
Client（Runtime） ⇄ Server（工具提供方）
  initialize
  tools/list
  tools/call
  resources/list / resources/read
  prompts/list / prompts/get
  notifications
```

平台把 MCP Server 的工具发现出来，转成模型可调用的工具。

---

## 2. 传输

| 传输 | 说明 | 适用 |
|---|---|---|
| stdio | 本地进程 | 开发/单机 |
| SSE | 旧版远程 | 兼容 |
| Streamable HTTP | 远程推荐 | 生产 |

**生产建议**：HTTP + 认证 + 网关；不要让 Runtime 直接 stdio 启动任意命令。

---

## 3. 生命周期

```
连接 → initialize（协议版本/能力）
→ tools/list（发现）
→ tools/call（执行）
→ 关闭/重连
```

- 协议版本协商；不兼容拒绝。
- `initialize` 返回 server info/capabilities。
- 工具列表可缓存（TTL/版本）。
- 断线重连；工具变更通知（如支持）。

---

## 4. 工具定义

```json
{
  "name": "query_bom",
  "description": "查询指定车型的 BOM 行",
  "inputSchema": {
    "type": "object",
    "properties": {"model": {"type": "string"}},
    "required": ["model"]
  }
}
```

**要求**
- 名称稳定/唯一；冲突加前缀。
- 描述简洁，说明何时用/不用。
- Schema 完整（类型/枚举/范围/必填）。
- 结果结构稳定；错误可读。

---

## 5. 调用

```json
{
  "jsonrpc": "2.0",
  "id": "1",
  "method": "tools/call",
  "params": {"name": "query_bom", "arguments": {"model": "D11"}}
}
```

响应：
```json
{
  "jsonrpc": "2.0",
  "id": "1",
  "result": {"content": [{"type": "text", "text": "..."}], "isError": false}
}
```

- 超时/重试/取消。
- 结果大小限制；大结果落 OSS。
- 错误映射（auth/timeout/schema/server）。
- 结果脱敏。

---

## 6. 认证

| 方式 | 说明 |
|---|---|
| Bearer | `Authorization: Bearer ${sys_mcp_token}` |
| API Key | `X-API-Key: ${sys_mcp_key}` |
| OAuth | 平台代管/刷新 |
| mTLS | 内网 |

**规则**
- Header 只存变量引用模板；真实值加密。
- 日志只出现变量名。
- 轮换不重启 Agent；下次调用生效。
- 禁止密钥写 URL/query。

---

## 7. 多 Server 与命名

- 一个 Agent 可挂多个 MCP Server。
- 工具名冲突：`alias__tool`。
- 工具暴露：all/selected。
- 工具数量上限；Top-K/检索。
- 单个 Server 故障不影响其他。

---

## 8. 安全

| 风险 | 控制 |
|---|---|
| SSRF | URL 白名单；禁内网/元数据 |
| 工具投毒 | 审核/签名/版本锁定 |
| 结果注入 | 标记为数据；不作为指令 |
| 越权 | 工具级 scope + Agent 授权 |
| 密钥泄露 | 变量引用/加密/脱敏 |
| 滥用 | 限流/配额/超时 |
| 供应链 | 服务方评估/镜像扫描 |

**红线**：MCP Server 不能直接访问平台 DB；不能执行任意本地命令（stdio 仅开发）。

---

## 9. 缓存与性能

| 对象 | 缓存 | TTL |
|---|---|---|
| 工具列表 | Redis | 5min |
| 工具 Schema | 本地 | 5min |
| 调用结果 | 可选 | 短 |
| 连接 | 连接池 | — |

- 工具列表变化 → 通知/失效。
- 连接复用；超时/熔断。
- 大结果流式/分页。

---

## 10. 可观测

| 指标 | 说明 |
|---|---|
| 连接成功率 | 健康 |
| tools/list 延迟 | 发现 |
| 调用成功率/延迟 | 执行 |
| 错误分类 | auth/timeout/schema/server |
| 工具使用分布 | 生态 |
| 结果大小 | 成本 |

---

## 11. 失败模式

| 失败 | 行为 |
|---|---|
| 连接失败 | 标记不可用；跳过 |
| 认证失败 | 提示更新密钥 |
| 超时 | 返回超时；重试 1 次 |
| Schema 不匹配 | 拒绝；记录 |
| 工具删除 | 下次发现移除 |
| 结果过大 | 截断/OSS |
| 5xx | 熔断 30s |

---

## 12. 测试

- 连接/初始化/版本。
- tools/list 解析。
- tools/call 成功/失败/超时。
- 认证/轮换。
- 多 Server/命名冲突。
- 结果大小/脱敏。
- 故障降级。

---

## 13. 实施顺序

1. HTTP/SSE 客户端 + 初始化。
2. tools/list + 工具注册。
3. tools/call + 结果压缩。
4. 认证/变量引用。
5. 多 Server/暴露/过滤。
6. 缓存/健康/熔断。
7. 安全/审计/测试。

---

## 14. 验收标准

- [ ] HTTP/SSE 接入可用。
- [ ] 工具发现/调用/错误映射。
- [ ] 认证变量不落明文。
- [ ] 多 Server/命名/暴露。
- [ ] 故障不阻塞整轮。
- [ ] 可观测/审计。
- [ ] 安全（SSRF/注入）通过。
