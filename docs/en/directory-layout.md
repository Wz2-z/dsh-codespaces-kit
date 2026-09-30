# Directory layout

[← English docs](index.md) · [中文](../directory-layout.md)

```
Host (Windows)
├── Desktop\DeepSeek Harness.lnk     start
├── Desktop\<control panel>.lnk      status / checkup / sync / update / uninstall
├── %LOCALAPPDATA%\dsh-cloud\gh\     portable GitHub CLI
└── %USERPROFILE%\.ssh\dsh_cs_key    key used to SSH into the Codespace

Container (Codespaces)
├── /workspaces/<repo>/.dsh-cloud/   persistent volume: start.sh / update.sh / sync.sh / sync.conf (+ your own public-sync.sh)
├── /workspaces/<repo>/              the repo checkout (the folder VS Code opens)
├── ~/dsh-workspace/                 the workspace (a clone) where dsh does its work
├── ~/.dsh/                          dsh config, session history, credentials
└── ~/.ssh/dsh_deploy                deploy key with write access to that one repo
```
