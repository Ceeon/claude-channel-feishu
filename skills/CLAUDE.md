<!--
input: 需要修改或理解插件附带的 skills
output: skills 目录导航
pos: 项目 skills 子树导航节点

架构守护者：一旦我被修改，请同步更新：
1. 本文件的头部注释
2. ../CLAUDE.md
3. 目录中的 skill 清单
-->

# Skills

这里是插件附带的 Claude skills，主要负责本地配置与路由模式。

## Navigation

↑ parent: [项目根](../CLAUDE.md)
↓ children:
- [`access/`](access/) - `/feishu:access`，管理群聊 mention 模式、权限卡片接收人和投递体验配置
- [`configure/`](configure/) - `/feishu:configure`，管理凭证、状态目录与启动说明
→ related:
- [`../README.md`](../README.md) - 面向用户的安装与使用说明

## Notes

- skill 只负责配置入口，不负责消息桥接本身。
- 实际 channel 能力来自根目录的 `server.ts`。
