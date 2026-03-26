# claude-channel-feishu

Feishu (Lark) channel plugin for [Claude Code](https://docs.anthropic.com/en/docs/claude-code). Send messages to your Feishu bot and Claude Code replies — just like the official Telegram channel, but for Feishu.

## Features

- **Full channel integration** — messages flow from Feishu into your Claude Code session as `<channel>` notifications
- **Access control** — pairing codes, allowlists, group policies (mirrors the Telegram plugin's security model)
- **Permission relay** — tool-use permission requests forwarded to Feishu as interactive cards with Allow/Deny buttons
- **Rich messages** — text, images, files, rich text (post), audio, stickers
- **Group chat** — mention-based triggering with per-group allowlists
- **Skills** — `/feishu:access` and `/feishu:configure` for managing access and credentials

## Prerequisites

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) (CLI)
- [Bun](https://bun.sh/) runtime
- A Feishu (or Lark) custom app with Bot capability

## Setup

### 1. Create a Feishu App

1. Go to [Feishu Open Platform](https://open.feishu.cn/app) (or [Lark Developer](https://open.larksuite.com/app) for international)
2. Create a Custom App
3. Enable **Bot** capability
4. Add permissions:
   - `im:message` — receive messages
   - `im:message:send_as_bot` — send messages
   - `im:resource` — download images/files
   - `im:message.reactions:write` — emoji reactions (optional)
5. In **Event Subscriptions**, choose **WebSocket** mode, then add:
   - `im.message.receive_v1`
   - `card.action.trigger` (for permission buttons)
6. Create a version → publish → wait for admin approval

### 2. Clone and Install

```bash
git clone https://github.com/chengfeng-git/claude-channel-feishu.git
cd claude-channel-feishu
bun install
```

### 3. Configure Credentials

```bash
mkdir -p ~/.claude/channels/feishu
cat > ~/.claude/channels/feishu/.env << 'EOF'
FEISHU_APP_ID=cli_xxxxx
FEISHU_APP_SECRET=xxxxx
EOF
chmod 600 ~/.claude/channels/feishu/.env
```

Or use the built-in skill after launching Claude Code:
```
/feishu:configure cli_xxxxx your_app_secret
```

### 4. Create MCP Config

```bash
cat > ~/.claude/channels/feishu/mcp.json << EOF
{
  "mcpServers": {
    "feishu": {
      "command": "bun",
      "args": ["run", "--cwd", "$(pwd)", "--shell=bun", "--silent", "start"]
    }
  }
}
EOF
```

### 5. Launch Claude Code

Three flags are needed:

| Flag | Purpose |
|------|---------|
| `--mcp-config` | Register the feishu MCP server |
| `--dangerously-load-development-channels server:feishu` | Enable the channel (bypasses official allowlist) |
| `--plugin-dir` | Load skills (`/feishu:access`, `/feishu:configure`) |

```bash
claude \
  --mcp-config ~/.claude/channels/feishu/mcp.json \
  --dangerously-load-development-channels server:feishu \
  --plugin-dir /path/to/claude-channel-feishu
```

Recommended: create a shell alias:

```bash
alias ccfeishu="FEISHU_STATE_DIR=~/.claude/channels/feishu claude \
  --mcp-config ~/.claude/channels/feishu/mcp.json \
  --dangerously-load-development-channels server:feishu \
  --plugin-dir /path/to/claude-channel-feishu"
```

### 6. Pair Your Account

1. DM your Feishu bot — it replies with a pairing code
2. In your Claude Code session, run: `/feishu:access pair <code>`
3. Done. Messages now flow through.

## Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `FEISHU_APP_ID` | Yes | — | Feishu app ID (`cli_xxxxx`) |
| `FEISHU_APP_SECRET` | Yes | — | Feishu app secret |
| `FEISHU_DOMAIN` | No | `feishu` | `feishu` for China, `lark` for international |
| `FEISHU_STATE_DIR` | No | `~/.claude/channels/feishu` | State directory (access.json, .env, inbox) |
| `FEISHU_ACCESS_MODE` | No | — | Set to `static` to freeze access.json at boot |

## MCP Tools

The server exposes 4 tools to Claude Code:

| Tool | Description |
|------|-------------|
| `reply` | Send a message to a Feishu chat. Supports threading (`reply_to`) and file attachments (`files`) |
| `react` | Add an emoji reaction to a message |
| `download_attachment` | Download a file/image from a Feishu message to the local inbox |
| `edit_message` | Edit a previously sent message (no push notification) |

## Skills

| Skill | Description |
|-------|-------------|
| `/feishu:access` | Manage access control — pair users, edit allowlists, set DM/group policy |
| `/feishu:configure` | Set up credentials, check status, view setup guide |

## Access Control

Access control mirrors the official Telegram plugin:

- **`pairing` mode** (default) — unknown senders get a one-time code; approve in terminal with `/feishu:access pair <code>`
- **`allowlist` mode** — only pre-approved `open_id`s can reach you
- **`disabled` mode** — all DMs dropped

Group chats require explicit opt-in via `/feishu:access group add <chat_id>`.

## Architecture

```
Feishu Cloud ←→ WebSocket (WSClient) ←→ server.ts (MCP Server) ←→ stdio ←→ Claude Code
                                              ↕
                                    ~/.claude/channels/feishu/
                                    ├── .env          (credentials)
                                    ├── access.json   (ACL state)
                                    ├── approved/     (pairing confirmations)
                                    └── inbox/        (downloaded files)
```

The server runs as an MCP server with `claude/channel` capability. It:
1. Connects to Feishu via WebSocket long connection (no public IP needed)
2. Receives messages, applies access control (gate)
3. Forwards allowed messages as `notifications/claude/channel` to Claude Code
4. Exposes tools for Claude to reply, react, send files back

## Known Issues / SDK Quirks

See [.claude/log/02-飞书SDK踩坑.md](.claude/log/02-飞书SDK踩坑.md) for detailed notes. Key issues:

- **WSClient silently drops card events** — the SDK's `handleEventData` only processes `type === "event"`, but card actions arrive as `type === "card"`. This plugin monkey-patches it.
- **No bot info API** — bot self-messages are filtered by `sender_type === 'app'` instead of `open_id` comparison.
- **LoggerLevel casing** — SDK exports `lark.LoggerLevel.warn` (lowercase), not `WARN`.

## Combining with Other Channels

You can run Feishu alongside the official Telegram channel:

```bash
claude \
  --channels plugin:telegram@claude-plugins-official \
  --mcp-config ~/.claude/channels/feishu/mcp.json \
  --dangerously-load-development-channels server:feishu \
  --plugin-dir /path/to/claude-channel-feishu
```

## License

Apache-2.0
