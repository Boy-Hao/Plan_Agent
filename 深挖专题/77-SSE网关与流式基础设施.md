# 77 SSE 网关与流式基础设施

## 1. 为什么单独做网关

SSE 长连接与普通 API 的生命周期完全不同：

- 连接可能持续几分钟；
- 不能占 DB 连接；
- 需要跨副本广播/续传；
- 内存/文件描述符/网络是主要瓶颈；
- 代理/负载均衡容易缓冲。

**结论**：SSE 网关独立部署，只依赖 Redis，不碰 DB。

---

## 2. 架构

```
Client
  ↓ HTTPS
Ingress/LB（关闭缓冲）
  ↓
SSE Gateway（多副本，无状态）
  ├─ 订阅 Redis Pub/Sub（live）
  ├─ 读取 Redis Stream（log/catch-up）
  ├─ 心跳
  └─ 背压/限流
  ↓
Redis（Stream/PubSub/active_turn）
```

---

## 3. 数据模型

| Key | 类型 | 用途 |
|---|---|---|
| `t:{tenant}:sse:log:{message_id}` | Stream | 事件日志，续传 |
| `t:{tenant}:sse:live:{message_id}` | Pub/Sub | 实时广播 |
| `t:{tenant}:session:active_turn:{session_id}` | Hash | 当前轮 |
| `t:{tenant}:sse:conn:{node}` | Set | 连接登记（可选） |

**Stream 限制**：`MAXLEN ~ 2000`，TTL 1h；事件 id 单调。

---

## 4. 连接生命周期

```
1. 鉴权（一次）
2. 解析 message_id / active_turn
3. 订阅 live
4. 重放 log（Last-Event-ID 之后）
5. tail 到 msg_end
6. 心跳/保活
7. 关闭/注销
```

**不持 DB 连接**；鉴权只查一次 Redis/本地。

---

## 5. 事件

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

- `id` 单调递增（Stream ID）。
- `seq` 业务顺序/去重。
- `version` schema 版本。
- 大内容只发引用。

---

## 6. 续传

```
GET /live?message_id=... 
Header: Last-Event-ID: <id>

1. 订阅 live
2. XRANGE log (last, +)
3. 发送
4. 继续 tail
5. 若 log 已截断 → 发 truncated
6. 客户端拉消息详情补齐
```

**关键**：先订阅再重放，避免漏事件；重放去重。

---

## 7. 广播/多副本

- 任意副本都能服务。
- 生产者 `XADD` + `PUBLISH`。
- 消费者订阅 Pub/Sub；断线用 Stream 补。
- 不需要 sticky session。
- 副本故障：客户端重连到其他副本。

---

## 8. 背压

| 问题 | 策略 |
|---|---|
| 生产快于消费 | 批量合并（30–60ms） |
| 慢客户端 | 丢弃最旧/合并 |
| 内存高 | 每连接缓冲上限 |
| 网络慢 | 降低发送频率 |
| Ring 满 | 标记 truncated |

**原则**：宁可丢弃中间 token，不可拖垮网关；`msg_end` 必须送达。

---

## 9. 心跳

- 每 15s 发 `: ping`。
- 客户端 30s 无事件重连。
- 代理空闲超时 > 心跳间隔。
- 心跳不写 Stream（避免膨胀）。

---

## 10. 代理/网络

| 问题 | 配置 |
|---|---|
| 缓冲 | `X-Accel-Buffering: no`；`proxy_buffering off` |
| 超时 | `proxy_read_timeout 3600s` |
| 压缩 | 谨慎；小包收益低 |
| HTTP/2 | 复用连接 |
| 负载均衡 | 不要求 sticky |
| WAF | 放行长连接 |

---

## 11. 容量

```
连接数 = 峰值并发会话 × 1.2
内存 = 连接数 × 每连接缓冲(16–32KB)
```

- 单节点 5–8 万连接（按内存/配置）。
- 连接数 >70% 扩容。
- 文件描述符/端口/带宽。
- 压测：5k/10k 连接。

---

## 12. 失败模式

| 失败 | 行为 |
|---|---|
| Redis 故障 | 降级/重连/提示 |
| 网关副本挂 | 客户端重连其他副本 |
| 生产者断 | 客户端保留最后事件 |
| ring 截断 | truncated + 拉详情 |
| 慢客户端 | 丢弃/合并 |
| 代理缓冲 | 首 token 卡；改配置 |

---

## 13. 安全

- 建连鉴权一次；token 过期关闭。
- 租户隔离：key 带 tenant；校验 message 归属。
- 不泄露他人消息。
- 限流：每用户连接数/事件数。
- 日志不记录正文。

---

## 14. 可观测

| 指标 | 说明 |
|---|---|
| 连接数/断连 | 容量 |
| 首事件延迟 | 体验 |
| 续传成功率 | 质量 |
| 事件速率 | 负载 |
| 丢弃/截断 | 背压 |
| 内存/CPU | 资源 |

---

## 15. 测试

- 正常流/断线重连/刷新。
- Last-Event-ID 续传。
- ring 截断。
- 多副本切换。
- 慢客户端/背压。
- 5k 连接压测。
- Redis 故障。
- 代理缓冲。

---

## 16. 实施顺序

1. 单副本 SSE + Stream/PubSub。
2. 续传/active_turn。
3. 心跳/断线。
4. 独立网关部署。
5. 背压/限流。
6. 多副本/压测。
7. 故障注入。

---

## 17. 验收标准

- [ ] 断线 30s 续传不丢/不重。
- [ ] 多副本可服务。
- [ ] 不持 DB 连接。
- [ ] 代理不缓冲。
- [ ] 背压/限流有效。
- [ ] 5k 连接稳定。
- [ ] 监控/告警齐全。
