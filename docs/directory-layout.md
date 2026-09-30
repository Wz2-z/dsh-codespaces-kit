# 目录结构

> [English version](en/directory-layout.md)

```
本机（Windows）
├── Desktop\DeepSeek Harness.lnk          启动（setup.ps1 创建）
├── Desktop\更新 dsh.lnk                   更新（同上）
├── %LOCALAPPDATA%\dsh-cloud\
│   ├── gh\                               便携版 GitHub CLI（gh\bin\gh.exe）
│   ├── ghconfig\                         gh 的登录令牌（明文，可 logout）
│   ├── start-dsh.bat / update-dsh.bat    快捷方式真正指向的两个脚本
│   └── *-log.txt                         启动 / 更新时的输出
├── <kit>\install\console.ps1             管理台（console.bat 是启动器，菜单式）
└── %USERPROFILE%\.ssh\dsh_cs_key         连接 Codespace 的私钥

云端（Codespaces 容器）
├── /workspaces/<repo>/.dsh-cloud/        持久卷：start.sh / update.sh / sync.sh / sync.conf
├── /workspaces/<repo>/                   仓库本体（VS Code 打开的那个）
├── ~/dsh-workspace/                      工作区（仓库克隆，dsh 在这里干活）
├── ~/.dsh/                               dsh 配置、会话历史、API Key
├── ~/dsh-web.log / ~/dsh-sync.log        运行日志（`~` 在容器重建时会清空）
└── ~/.ssh/dsh_deploy                     只对该仓库有写权限的 deploy key
```

---

[← 回到 README](https://github.com/Wz2-z/dsh-codespaces-kit/blob/main/README.md)
