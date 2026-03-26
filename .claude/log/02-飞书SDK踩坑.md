# 02 - 飞书 SDK 踩坑记录

## 背景

使用 `@larksuiteoapi/node-sdk`（实际安装版本 1.60.0）对接飞书 WebSocket 长连接。SDK 文档和实际 API 有多处不一致。

## 踩坑清单

### 1. WSClient 构造函数不接受 eventDispatcher

**文档写法**（错误）：
```ts
const wsClient = new lark.WSClient({ appId, appSecret, eventDispatcher })
```

**实际 API**：eventDispatcher 要传到 `start()` 里：
```ts
const wsClient = new lark.WSClient({ appId, appSecret, domain: DOMAIN })
void wsClient.start({ eventDispatcher })
```

### 2. LoggerLevel 是小写 + 数字值

**文档写法**（错误）：`lark.LoggerLevel.WARN`

**实际 API**：小写 `lark.LoggerLevel.warn`，且值是数字 2。

### 3. Domain 是数字枚举，不是字符串

**错误**：`domain: 'feishu'`

**正确**：
```ts
lark.Domain.Feishu  // = 0
lark.Domain.Lark    // = 1
```

需要手动映射：
```ts
const DOMAIN = DOMAIN_STR === 'lark' ? lark.Domain.Lark : lark.Domain.Feishu
```

### 4. client.bot 不存在

SDK 没有直接获取 bot 信息的 API。不能用 `client.bot.info()` 拿 bot open_id。

**解决方案**：通过 `sender_type === 'app'` 过滤 bot 自己的消息，不依赖 open_id 比对。从第一条消息的 mentions 中检测 bot open_id。

### 5. WSClient 静默丢弃 Card 事件（最坑）

`WSClient.handleEventData()` 内部有判断：
```ts
if (type !== MessageType.event) return  // 静默丢弃
```

飞书 Interactive Card 的按钮回调 type 是 `"card"`，不是 `"event"`，导致权限确认按钮的回调被静默丢弃。

**解决方案**：Monkey-patch `handleEventData`，在调用原方法前把 type header 从 `"card"` 改成 `"event"`：

```ts
const origHandleEventData = (wsClient as any).handleEventData?.bind(wsClient)
;(wsClient as any).handleEventData = async function (data: any) {
  const headers: Record<string, string> = {}
  for (const h of data?.headers ?? []) {
    headers[h.key] = h.value
  }
  if (headers.type === 'card') {
    for (const h of data.headers) {
      if (h.key === 'type') h.value = 'event'
    }
  }
  return origHandleEventData(data)
}
```

### 6. Bot 自消息过滤

Telegram 可以通过 `bot.id` 过滤自己发的消息。飞书没有直接的 bot info API。

**解决方案**：用 `sender.sender_type === 'app'` 判断是否是 bot 发的消息（所有应用消息的 sender_type 都是 `'app'`）。

## 验证方法

每个修复都通过 `bun --bun server.ts` 手动启动验证，观察：
1. `[info]: [ "client ready" ]` — SDK 初始化成功
2. `feishu channel: WebSocket connected` — WS 连接成功
3. 飞书发消息后 console 无报错 — 消息处理正常
