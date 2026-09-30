# 目录结构

> [English version](en/directory-layout.md)

```
本机（Windows）
├── Desktop\DeepSeek Harness.lnk          启动
├── Desktop\更新 dsh.lnk                   更新
├── %LOCALAPPDATA%\dsh-cloud\gh\          便携版 GitHub CLI
└── %USERPROFILE%\.ssh\dsh_cs_key         连接 Codespace 的私钥

云端（Codespaces 容器）
├── /workspaces/<repo>/.dsh-cloud/        持久卷：start.sh / update.sh / sync.sh / sync.conf
├── /workspaces/<repo>/                   仓库本体（VS Code 打开的那个）
├── ~/dsh-workspace/                      工作区（仓库克隆，dsh 在这里干活）
├── ~/.dsh/                               dsh 配置、会话历史、API Key
└── ~/.ssh/dsh_deploy                     只对该仓库有写权限的 deploy key
```

---

[← 回到 README](https://github.com/Wz2-z/dsh-codespaces-kit/blob/main/README.md)
