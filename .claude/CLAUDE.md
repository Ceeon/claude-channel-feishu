<!--
input: 项目内部调查、设计与文档沉淀需求
output: .claude 子树导航
pos: 项目级 Agent 文档中心

架构守护者：一旦我被修改，请同步更新：
1. 本文件的头部注释
2. ../CLAUDE.md
3. 本目录子节点的 CLAUDE.md
-->

# 项目文档中心

这里存放调查过程、关键结论与本地 Agent 配置。

## Navigation

↑ parent: [项目根](../CLAUDE.md)
↓ children:
- [`log/`](log/CLAUDE.md) - 排障过程、技术决策与实验记录
- [`memory/`](memory/CLAUDE.md) - 从日志提炼出的长期有效结论
→ related:
- [`../README.md`](../README.md) - 面向人类的安装与使用文档

## Notes

- `settings.local.json` 是本地 Claude 会话设置，不是插件发布内容。
- `log/` 记录过程，`memory/` 记录结论；同一个问题通常先写 `log` 再提炼 `memory`。
- 当前 Feishu channel 入站策略是开放投递；访问控制文档只保留路由配置与历史排障语境。
