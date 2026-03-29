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
git clone https://github.com/Ceeon/claude-channel-feishu.git
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

## How Claude Code Channel Plugins Work

Claude Code's official channel plugins (like Telegram) go through a strict 5-step registration chain:

```
marketplace.json → plugin.json → settings.json (enabledPlugins)
→ installed_plugins.json → --channels flag → tengu_harbor_ledger (server-side allowlist)
```

All 5 steps must pass, or the plugin silently fails to load. The last step — `tengu_harbor_ledger` — is a **server-side allowlist** cached in `~/.claude.json` that Anthropic controls. Even if you manually inject your plugin into the official marketplace directory, Claude Code refreshes `marketplace.json` from GitHub on startup (overwriting your changes), and `tengu_harbor_ledger` is synced from Anthropic's servers (your plugin won't be on it).

### What doesn't work

| Approach | Result |
|----------|--------|
| `extraKnownMarketplaces` + `source: "directory"` | `${CLAUDE_PLUGIN_ROOT}` not resolved, MCP fails to start |
| User-level MCP server (`claude mcp add --scope user`) | Server starts, but no `<channel>` notifications — it's an MCP server, not a channel plugin |
| Project-level `.mcp.json` | Same — MCP tools work, but no channel capability |
| Symlink into official marketplace | `marketplace.json` overwritten on startup; `tengu_harbor_ledger` blocks it |

### What works: the three-flag approach

For third-party channel plugins, the only working local development path combines three CLI flags:

| Flag | What it does |
|------|-------------|
| `--mcp-config <path>` | Registers the MCP server (replaces marketplace + plugin.json + settings.json) |
| `--dangerously-load-development-channels server:<name>` | Bypasses `tengu_harbor_ledger` allowlist, enables `<channel>` notifications |
| `--plugin-dir <path>` | Loads skills from the plugin directory (e.g. `/feishu:access`) |

The MCP server must declare the `claude/channel` experimental capability:

```typescript
capabilities: {
  tools: {},
  experimental: {
    'claude/channel': {},
    'claude/channel/permission': {},
  },
}
```

And push inbound messages as `notifications/claude/channel`:

```typescript
mcp.notification({
  method: 'notifications/claude/channel',
  params: { content: messageText, meta: { chat_id, message_id, user, ts } },
})
```

See [.claude/log/01-插件注册机制.md](.claude/log/01-插件注册机制.md) for the full investigation with all failed attempts documented.

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

## Multiple Bots

Each bot gets its own state directory with separate credentials and access control:

```
~/.claude/channels/feishu-work/      ← Bot A
  ├── .env                            # FEISHU_APP_ID=cli_aaa
  ├── mcp.json
  └── access.json

~/.claude/channels/feishu-personal/  ← Bot B
  ├── .env                            # FEISHU_APP_ID=cli_bbb
  ├── mcp.json
  └── access.json
```

Each `mcp.json` must use a unique server name:

```json
{ "mcpServers": { "feishu-work": { "command": "bun", "args": ["run", "--cwd", "/path/to/plugin", "--shell=bun", "--silent", "start"] } } }
```

Then create separate aliases:

```bash
alias ccwork="FEISHU_STATE_DIR=~/.claude/channels/feishu-work claude \
  --mcp-config ~/.claude/channels/feishu-work/mcp.json \
  --dangerously-load-development-channels server:feishu-work \
  --plugin-dir /path/to/claude-channel-feishu"

alias ccme="FEISHU_STATE_DIR=~/.claude/channels/feishu-personal claude \
  --mcp-config ~/.claude/channels/feishu-personal/mcp.json \
  --dangerously-load-development-channels server:feishu-personal \
  --plugin-dir /path/to/claude-channel-feishu"
```

The plugin code is shared — `FEISHU_STATE_DIR` determines which bot's credentials are used.

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
