#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  scripts/trace-channel-startup.sh feishu
  scripts/trace-channel-startup.sh feishuqq

What it records:
  1. Raw interactive terminal output via script(1)
  2. Claude Code --debug log
  3. A short summary extracted from both logs

The script launches Claude interactively. Reproduce the startup header, then
exit Claude normally or press Ctrl+C. Logs are saved under /tmp by default.

Optional env vars:
  TRACE_ROOT   Override trace output root (default: /tmp/claude-channel-trace)
EOF
}

if [[ $# -ne 1 ]]; then
  usage
  exit 1
fi

if ! command -v script >/dev/null 2>&1; then
  echo "script(1) is required but not found" >&2
  exit 1
fi

bot="$1"
case "$bot" in
  feishu)
    server_name="feishu"
    state_dir="$HOME/.claude/channels/feishu"
    mcp_config="$state_dir/mcp.json"
    plugin_dir="$HOME/.claude/plugins/cache/claude-plugins-official/feishu/0.0.1"
    ;;
  feishuqq)
    server_name="feishuqq"
    state_dir="$HOME/.claude/channels/feishu-qq"
    mcp_config="$state_dir/mcp.json"
    plugin_dir="$HOME/.claude/plugins/cache/claude-plugins-official/feishuqq/0.0.1"
    ;;
  *)
    usage
    exit 1
    ;;
esac

timestamp="$(date +%Y%m%d-%H%M%S)"
trace_root="${TRACE_ROOT:-/tmp/claude-channel-trace}"
trace_dir="$trace_root/$timestamp-$server_name"
tty_log="$trace_dir/tty.log"
debug_log="$trace_dir/claude-debug.log"
summary_log="$trace_dir/summary.txt"
context_log="$trace_dir/context.txt"

mkdir -p "$trace_dir"

cat >"$context_log" <<EOF
timestamp=$timestamp
server_name=$server_name
state_dir=$state_dir
mcp_config=$mcp_config
plugin_dir=$plugin_dir
cwd=$(pwd)
EOF

echo "Trace dir: $trace_dir"
echo "Recording Claude startup for server:$server_name"
echo "Reproduce the header, then exit Claude normally or press Ctrl+C."
echo

set +e
FEISHU_STATE_DIR="$state_dir" \
script -q "$tty_log" \
  claude \
  --debug \
  --debug-file "$debug_log" \
  --strict-mcp-config \
  --mcp-config "$mcp_config" \
  --dangerously-load-development-channels "server:$server_name" \
  --plugin-dir "$plugin_dir"
status=$?
set -e

{
  echo "# Claude Channel Startup Trace"
  echo
  echo "exit_status=$status"
  echo "server_name=$server_name"
  echo "trace_dir=$trace_dir"
  echo
  echo "## Terminal matches"
  rg -n "Listening for channel messages from:|server:${server_name}|no MCP server configured" "$tty_log" || true
  echo
  echo "## Debug matches"
  rg -n \
    "MCP server \"${server_name}\"|Successfully connected|Connection established|Connection failed|STDIO connection dropped|JSON Parse error|FEISHU_APP_ID and FEISHU_APP_SECRET required|Channel notifications registered|Server stderr" \
    "$debug_log" || true
} | tee "$summary_log"

echo
echo "Saved files:"
echo "  $context_log"
echo "  $tty_log"
echo "  $debug_log"
echo "  $summary_log"
