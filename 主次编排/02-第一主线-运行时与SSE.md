# 02 第一主线：运行时与 SSE

> 定位：**T0 生死线**。它决定「一轮对话是否正确、可恢复、可取消」。
> 失败后果：丢消息、重复回答、刷新丢历史、并发双轮、无法停止。

---

## 1. 成败标准

| 标准 | 目标 |
|---|---|
| 首 token P95 | ≤3s |
| 完整响应 P95 | ≤30s（视任务） |
| SSE 续传成功率 | ≥99.9% |
| 并发双轮 | 0 |
| 取消生效 | ≤2s |
| 消息重复 | 0 |
| 崩溃后悬挂 | 0（有扫描/标记） |

---

## 2. 核心模型

```
Session 1 ── * Message
Session 1 ── * Turn
Turn 1 ── * ToolCall
Turn 1 ── 1 Trace
Message 1 ── * SSE Event
```

**不变量**
- 同一会话同一时刻最多一个活跃轮。
- 消息 `seq` 单调。
- `msg_end` 必发（成功/失败/取消）。
- 终态不可变。

---

## 3. Turn 状态机

```
received → queued → running → tool_wait → running → completed
                        │                     │
                        ├→ cancelled          └→ failed
                        └→ failed
```

| 状态 | 进入 | 退出 |
|---|---|---|
| received | 收到请求 | 获取锁/幂等 |
| queued | 等配额/模型 | 准入 |
| running | 开始 LLM | 工具/结束/取消 |
| tool_wait | 工具执行 | 结束/超时 |
| completed | 正常 | 终态 |
| cancelled | 用户/超时 | 终态 |
| failed | 不可恢复 | 终态 |

---

## 4. 并发与锁

```
SET t:{tenant}:lock:session:{sid} <turn_id> NX PX 30000
```

- 锁值 = `turn_id`（fencing token）。
- 运行中每 10s 续租；TTL 30s。
- 写入前校验 fencing token，防僵尸写入。
- 释放用 Lua 比较后删除。
- 冲突：409/排队；前端提示。

**多标签页**：服务端 `active_turn` 为准；非发起页只读。

---

## 5. 幂等

| 对象 | 幂等键 | 作用 |
|---|---|---|
| 消息 | `(tenant, session, client_message_id)` | 防重复提交 |
| Turn | `turn_id` | 状态 CAS |
| 工具 | `(turn_id, tool_call_id)` | 防重复副作用 |
| 回调 | `callback_token/task_id` | 防重复处理 |
| 取消 | `session/turn` | 重复取消安全 |

---

## 6. SSE 协议

```json
{
  "id": "123",
  "event": "token",
  "data": {
    "event_id": "evt_1",
    "turn_id": "turn_1",
    "message_id": "msg_1",
    "seq": 42,
    "version": 1,
    "delta": "你好"
  }
}
```

| 事件 | 说明 |
|---|---|
| msg_start | 开始 |
| token | 文本增量 |
| thinking | 思考增量 |
| tool_call_start/end | 工具 |
| artifact | 产物 |
| task_plan_updated | 计划 |
| sub_agent_progress | 子 Agent |
| msg_end | 结束 |
| error | 错误 |
| `: ping` | 心跳 |

**规则**：`id` 单调；`seq` 去重；`msg_end` 必达；大内容只发引用。

---

## 7. 续传

```
GET /active-turn → message_id/status
GET /live?message_id=... + Last-Event-ID
→ 订阅 sse:live:{mid}
→ 重放 sse:log:{mid}
→ tail 到 msg_end
→ truncated → 拉消息详情补齐
```

**Redis**
- `sse:log:{mid}` Stream（MAXLEN 2000，TTL 1h）。
- `sse:live:{mid}` Pub/Sub。
- `session:active_turn:{sid}` Hash。

**不持 DB 连接**：长连接只读 Redis。

---

## 8. 取消

```
client cancel
→ set cancel flag
→ close LLM stream
→ cancel tools (SIGTERM/timeout)
→ cascade sub-agents
→ write msg_end(cancelled)
→ release lock
```

- 协作式取消；工具检查标记。
- 取消后不再产生新副作用。
- 区分 user_cancel / timeout。
- 幂等。

---

## 9. 崩溃恢复

- 启动扫描 `running` 超时 Turn → 标记 failed。
- `tool_call` pending 超时 → 重试/失败。
- SSE ring buffer 保留 5–10min。
- 客户端重连拿已有内容 + 错误提示。

---

## 10. 失败模式

| 失败 | 行为 |
|---|---|
| 锁冲突 | 409/排队 |
| 配额拒绝 | 429 + reset |
| 模型超时 | 重试/备用/报错 |
| 工具超时 | 返回超时给模型 |
| 持久化失败 | 重试/后续补偿 |
| Redis 故障 | SSE 降级；锁降级 DB |
| 客户端断开 | 保留 buffer；可续 |
| 进程崩溃 | 标记失败；可重试 |

---

## 11. 观测

- `request_id → session_id → turn_id → message_id`。
- 阶段耗时：排队/上下文/LLM/工具/持久化。
- 指标：TTFT、完整延迟、错误、取消、续传、并发双轮。
- Trace：LLM/工具/子 Agent 树。

---

## 12. 实施顺序

1. 表：session/message/turn/tool_call。
2. 会话 CRUD。
3. SSE 发送 + 持久化。
4. 锁 + 幂等。
5. 续传/active-turn。
6. 取消。
7. 工具调用。
8. 子 Agent/计划。
9. 崩溃恢复。
10. 压测/故障注入。

---

## 13. 验收用例

- [ ] 多轮对话、流式、停止。
- [ ] 刷新/断网 30s 恢复。
- [ ] 并发同会话只有一个活跃轮。
- [ ] 重复提交不产生两条消息。
- [ ] 取消 2s 内生效。
- [ ] 工具失败不崩。
- [ ] 进程崩溃后无悬挂。
- [ ] `msg_end` 必达。
- [ ] 事件去重/顺序正确。
