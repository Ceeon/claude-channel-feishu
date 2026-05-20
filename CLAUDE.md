<!--
input: 项目根目录上下文
output: 面向 Agent 的导航入口与文档约定
pos: claude-channel-feishu 的根导航节点

架构守护者：一旦我被修改，请同步更新：
1. 本文件的头部注释
2. README.md
3. .claude/CLAUDE.md
-->

# claude-channel-feishu

Feishu Channel 插件的根导航节点。先看这里，再决定进入源码、skills 还是排障文档。

## Navigation

↓ children:
- [`.claude/`](.claude/CLAUDE.md) - 调查日志、关键记忆、Agent 文档网络
- [`skills/`](skills/CLAUDE.md) - `/feishu:access` 与 `/feishu:configure` 的路由配置说明
→ related:
- [`README.md`](README.md) - 面向人类的安装、配置与多 bot 使用说明

## Working Notes

- 运行时核心代码在 [`server.ts`](server.ts)。
- 当前入站策略是开放投递：私聊不 pairing，群聊默认 @ 触发，不按 sender allowlist 拦截。
- 多 bot 方案依赖“共享代码 + 独立状态目录 + 独立凭证 + 独立 server name”。
- 遇到启动问题先看 `.claude/log/05-多-bot-启动与配置隔离.md`，遇到长期原则先看 `.claude/memory/01-多-bot-隔离原则.md`。
