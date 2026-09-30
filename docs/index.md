---
title: dsh on GitHub Codespaces
---

# dsh on GitHub Codespaces

在云端 Codespace 里跑官方 dsh，本机用一条 SSH 隧道访问，工作区自动备份到你的私有仓库。

**中文文档**就是这一套页面：从下面开始读。

> **English readers:** start here → **[English docs](en/)** (or the [English README](https://github.com/Wz2-z/dsh-codespaces-kit/blob/main/README.en.md)).

## 从这里开始

- [部署指南（主 README）](https://github.com/Wz2-z/dsh-codespaces-kit/blob/main/README.md) —— 30 秒了解 → 安装 → 配置 → 日常使用
- [一键安装脚本](https://github.com/Wz2-z/dsh-codespaces-kit/tree/main/install) —— `setup.ps1` / `setup.sh`，装完打印 `✅ Installation complete`
- [体检：doctor](doctor.md) —— 12 项检查，坏了看哪一行
- [生命周期](lifecycle.md) —— `status` / `setup` / `repair` / `update` / `uninstall`
- [安全模型](security-model.md) —— 创建了哪些 key/token/config，各自能干什么、怎么撤销

## 深入

- [自动同步](auto-sync.md) —— 空闲去抖、三种模式、提交信息、折叠窗口
- [插件](plugins.md) —— 额度面板、同步面板
- [排错手册](troubleshooting/windows.md) —— Windows / SSH / Codespaces / dsh 四类
- [给 AI 的任务书](ai-prompt.md) —— 复制一段话让 AI 帮你装
- [技术细节](ai-runbook.md) / [云端脚本](cloud-scripts.md) / [macOS·Linux](macos-linux.md) / [目录结构](directory-layout.md)

---

[GitHub 仓库](https://github.com/Wz2-z/dsh-codespaces-kit) · MIT / CC BY 4.0 · [@Wz2-z](https://github.com/Wz2-z)
