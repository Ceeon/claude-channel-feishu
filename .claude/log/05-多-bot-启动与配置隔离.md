<!--
input: ccf/ccqq 启动异常、多 bot 串扰、消息进入 Claude 异常
output: 多 bot 排障过程与最终设计结论
pos: 多 bot 配置隔离的调查日志

架构守护者：一旦我被修改，请同步更新：
1. 本文件的头部注释
2. README.md 的多 bot 章节
3. ../memory/01-多-bot-隔离原则.md
-->

# 05 - 多 bot 启动与配置隔离

## 背景

本地维护两套启动别名：

- `ccf`
- `ccqq`

目标是“一套 bot 对应一个 Claude Code 会话”，并且无论从哪个工作目录启动，都会稳定加载正确的 Feishu channel。

## 现象

### 1. `ccqq` 交互启动时报错

启动头部出现：

```text
Listening for channel messages from:
server:feishuqq
server:feishuqq · no MCP server configured with that name
```

### 2. `ccf` 和 `ccqq` 语义上想代表两套 bot，但运行行为像同一套 bot

表面上有两个 state dir：

- `~/.claude/channels/feishu`
- `~/.claude/channels/feishu-qq`

但排查时发现两边 `.env` 曾一度是同一组 `FEISHU_APP_ID` / `FEISHU_APP_SECRET`。

### 3. “能收到消息”与“Claude 看得到消息”是两层不同问题

如果 Feishu 端已经把消息送进本地 bridge，只能说明：

- WebSocket 连接通了
- bot 凭证基本可用
- `notifications/claude/channel` 之前的输入链路没有完全断

但消息能否出现在 Claude 会话里，还要继续经过 access gate 和当前会话绑定的 bot / sender / group 规则。

## 排查结论

### 1. 最初的 `no MCP server configured` 不是飞书权限问题

根因有两层：

- `ccqq` 的 alias 一开始缺少 `--mcp-config`
- 交互模式同时还读到了旧 schema 的 `~/.mcp.json` 与项目级 `.mcp.json`，导致 UI 头部出现误导性报错

修复后，`ccqq -p` 可以正常工作，交互模式也不再报 `server:feishuqq · no MCP server configured with that name`。

### 2. 多 bot 最稳的模型不是“分发”，而是“隔离”

推荐模型：

```text
1 bot = 1 Claude Code 进程 = 1 state dir = 1 mcp server name = 1 独立凭证
```

也就是：

- 每个 bot 自己的 `.env`
- 每个 bot 自己的 `access.json`
- 每个 bot 自己的 `mcp.json`
- 每个 bot 自己的 shell alias

共享的只有插件代码仓库本身。

### 3. “能收到消息但 Claude 看不到”通常优先查 gate，不先查启动

如果消息已经到本地，但 Claude 会话中没出现，优先检查：

- 当前 alias 对应的 `FEISHU_STATE_DIR`
- 该 state dir 下的 `access.json`
- sender 的 `open_id` 是否被允许
- group 的 `chat_id` 是否被允许
- 当前会话实际连的是哪一个 `FEISHU_APP_ID`

换句话说，“能收到消息”说明启动链路大概率没断；下一步通常不是改 alias，而是核对 bot 身份和 access gate。

## 最终落地方案

### 1. alias 强制隔离 MCP 配置

`ccf` 与 `ccqq` 都采用：

- `--strict-mcp-config`
- `--mcp-config <bot 自己的 mcp.json>`
- `--dangerously-load-development-channels server:<bot 自己的 server name>`

这样可以避免用户级或项目级 `.mcp.json` 干扰 channel 注册。

### 2. 每个 bot 的 `mcp.json` 都显式声明

每个 `mcp.json` 都使用 Claude 2.1.87 可识别的结构：

```json
{
  "mcpServers": {
    "feishu-work": {
      "command": "bun",
      "args": ["run", "--cwd", "/path/to/claude-channel-feishu", "--shell=bun", "--silent", "start"],
      "env": {
        "FEISHU_STATE_DIR": "/Users/you/.claude/channels/feishu-work",
        "MCP_SERVER_NAME": "feishu-work"
      },
      "type": "stdio"
    }
  }
}
```

关键字段：

- `mcpServers`
- `type: "stdio"`
- `FEISHU_STATE_DIR`
- `MCP_SERVER_NAME`

### 3. 多 bot 不依赖“消息分发逻辑”

只要确实是两个不同 Feishu App：

- 发给 bot A 的消息进入 `ccf`
- 发给 bot B 的消息进入 `ccqq`

不需要在 `server.ts` 里实现额外的消息分发器。

## 这次修改涉及的范围

仓库内：

- `README.md`
- `skills/access/SKILL.md`
- `skills/configure/SKILL.md`

本机配置：

- `~/.zshrc`
- `~/.mcp.json`
- `~/.claude/channels/feishu/mcp.json`
- `~/.claude/channels/feishu-qq/mcp.json`
- 相关 state dir 下的 `.env`

## 给下一次排障的检查顺序

1. 先区分“启动失败”还是“消息已到本地但没进 Claude”。
2. 启动失败时，看 alias / `mcp.json` / `--strict-mcp-config`。
3. 已经能收到消息时，看 `FEISHU_APP_ID`、`FEISHU_STATE_DIR` 与 `access.json`。
4. 做多 bot 时，优先验证两边是否真的是两套不同凭证，而不是只换了目录名。
