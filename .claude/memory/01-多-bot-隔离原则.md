---
trigger: 新增第二个 Feishu bot，或排查“channel 能启动 / 能收到消息，但 Claude 会话里没有对应消息”
related: [README.md](../../README.md), [多 bot 排障日志](../log/05-多-bot-启动与配置隔离.md)
created: 2026-03-31
---

# 多 bot 隔离原则

Feishu channel 的多 bot 方案应按“隔离”设计，不按“分发”设计。

## 核心原则

`1 bot = 1 Claude Code 进程 = 1 state dir = 1 mcp server name = 1 独立凭证`

共享的只有插件代码仓库，不共享下面这些运行态信息：

- `FEISHU_APP_ID`
- `FEISHU_APP_SECRET`
- `FEISHU_STATE_DIR`
- `access.json`
- `MCP_SERVER_NAME`

## 直接推论

- 如果两个 alias 用的是同一组 `FEISHU_APP_ID/SECRET`，那它们不是两个 bot，只是同一个 bot 的两个本地实例。
- 如果消息“能收到但 Claude 看不到”，优先查 access gate 和 bot 身份，不优先查启动链路。
- 为了避免用户级或项目级 MCP 配置串进来，启动时使用 `--strict-mcp-config`。

## 最稳的启动形式

```bash
alias ccwork="FEISHU_STATE_DIR=~/.claude/channels/feishu-work claude \
  --strict-mcp-config \
  --mcp-config ~/.claude/channels/feishu-work/mcp.json \
  --dangerously-load-development-channels server:feishu-work \
  --plugin-dir /path/to/claude-channel-feishu"
```

`mcp.json` 里至少要有：

- `mcpServers`
- 唯一的 server name
- `type: "stdio"`
- `env.FEISHU_STATE_DIR`
- `env.MCP_SERVER_NAME`

## 一句判断

“能收到消息”只能证明 bot 和 bridge 基本活着，不能证明这条消息一定会进入当前 Claude 会话。
