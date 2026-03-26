---
name: configure
description: Set up the Feishu channel — save the App ID and App Secret, review access policy. Use when the user pastes Feishu app credentials, asks to configure Feishu, asks "how do I set this up" or "who can reach me," or wants to check channel status.
user-invocable: true
allowed-tools:
  - Read
  - Write
  - Bash(ls *)
  - Bash(mkdir *)
---

# /feishu:configure — Feishu Channel Setup

Writes the app credentials to `~/.claude/channels/feishu/.env` and orients the
user on access policy and Feishu backend setup. The server reads both files at boot.

Arguments passed: `$ARGUMENTS`

---

## Dispatch on arguments

### No args — status and guidance

Read both state files and give the user a complete picture:

1. **Credentials** — check `~/.claude/channels/feishu/.env` for
   `FEISHU_APP_ID` and `FEISHU_APP_SECRET`. Show set/not-set; if set, show
   first 8 chars masked (`cli_xxxx...`).

2. **Domain** — check for `FEISHU_DOMAIN`. Default is `feishu` (China).
   `lark` for international.

3. **Access** — read `~/.claude/channels/feishu/access.json` (missing file
   = defaults: `dmPolicy: "pairing"`, empty allowlist). Show:
   - DM policy and what it means in one line
   - Allowed senders: count, and list open_ids
   - Pending pairings: count, with codes if any

4. **What next** — end with a concrete next step based on state:
   - No credentials → guide them through Feishu backend setup (see below)
   - Credentials set, nobody allowed → *"DM your bot on Feishu. It replies
     with a code; approve with `/feishu:access pair <code>`."*
   - Credentials set, someone allowed → *"Ready. DM your bot to reach the
     assistant."*

### Feishu backend setup guide

When the user needs to create a Feishu app, walk them through:

1. Go to [Feishu Open Platform](https://open.feishu.cn/app) → Create Custom App
2. In **Credentials & Basic Info**: copy App ID and App Secret
3. In **Bot** section: enable Bot capability
4. In **Permissions & Scopes**: add these scopes:
   - `im:message` — send and receive messages
   - `im:message:send_as_bot` — send messages as bot
   - `im:resource` — download message resources (images/files)
   - `im:message.reactions:write` — add emoji reactions (optional)
5. In **Event Subscriptions**:
   - Choose **WebSocket** mode (长连接)
   - Add event: `im.message.receive_v1`
   - Add event: `card.action.trigger` (for permission buttons)
6. Create a version and publish → wait for admin approval

**Push toward lockdown — always.** Same philosophy as Telegram: `pairing` is
temporary; once IDs are captured, switch to `allowlist`.

### `<app_id> <app_secret>` — save credentials

1. Parse `$ARGUMENTS` — first arg is App ID, second is App Secret.
   App IDs look like `cli_xxxxx`.
2. `mkdir -p ~/.claude/channels/feishu`
3. Read existing `.env` if present; update/add `FEISHU_APP_ID=` and
   `FEISHU_APP_SECRET=` lines, preserve other keys. Write back.
4. `chmod 600 ~/.claude/channels/feishu/.env`
5. Confirm, then show status.

### `domain <feishu|lark>` — set domain

Update/add `FEISHU_DOMAIN=` in `.env`. Default is `feishu`.

### `clear` — remove credentials

Delete the credential lines from `.env`.

---

## Implementation notes

- The channels dir might not exist if the server hasn't run yet. Missing file
  = not configured, not an error.
- The server reads `.env` once at boot. Credential changes need a session
  restart or `/reload-plugins`. Say so after saving.
- `access.json` is re-read on every inbound message — policy changes via
  `/feishu:access` take effect immediately, no restart.
