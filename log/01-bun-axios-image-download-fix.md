# 2026-04-15 · 飞书图片下载 Bun+axios 兼容性 fix

## 症状

用户在飞书发图片，channel 消息到达 Claude Code 时**没有 `image_path` 属性**，
只有 `(image)` 占位文本。Claude 这边没法 Read 附件 → 看不到图。

正常情况下 `server.ts` 应把图下载到 `~/.claude/channels/feishu/inbox/` 并在
channel meta 里塞 `image_path`。

## 根因

`downloadImage()` 里调用 lark SDK：
```ts
const resp = await client.im.messageResource.get({ ... })
await resp.writeFile(path)
```

SDK 内部走 axios 流式下载。Bun 跑 axios 时在这个流式响应上会死——抛
`Error: The socket connection was closed unexpectedly`，大约 30 秒后超时。

注意：
- 同样走 axios 的 POST（如 `client.im.message.create` 发消息）是正常的
- 只有流式 GET（`messageResource.get` / `file.get`）在 Bun 下坏
- `try/catch` 把错误吞掉了，只写 stderr，外部看不到

## 修复

`server.ts:409` 的 `downloadImage()` 改为：
1. 用 `client.tokenManager.getTenantAccessToken({})` 拿 token（这个走 axios POST，正常）
2. 用 Bun 原生 `fetch()` 直接打 `https://open.feishu.cn/open-apis/im/v1/messages/{id}/resources/{key}?type=image`
3. `await res.arrayBuffer()` 拿 buffer → `writeFileSync` 落盘

绕开了 axios 的流式处理。

## 排查过程踩的坑

1. **stderr 看不到**：MCP server 的 stderr 没地方捞，`try/catch` 吞错误后只写 stderr 等于
   黑洞。最后加了 `image-debug.log` 落盘才拿到真实 stack trace。
2. **`/mcp` 重连 ≠ 重启 bun 进程**：改完代码 `/mcp` reconnect 之后，bun 进程还是老的，
   新代码没加载。必须 `kill <bun pid>` 然后再 `/mcp`，Claude Code 才会重新 spawn。
3. **判断新代码是否生效**：最快方法是在新代码里加一个独一无二的 log 前缀
   （比如 `NEW downloadImage v2 entry`），从 log 里一眼看出跑的是新是老。

## TODO（给后来的）

- `downloadFileAttachment`（server.ts:736 的 `download_attachment` 工具处理）也走 SDK
  流式下载，八成同样坏，还没验证。如果碰到文件附件下载失败，同样办法改。
- 可以把 `image-debug.log` 机制保留着，出问题有个地方捞。
