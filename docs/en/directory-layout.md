# Directory layout

[← English docs](index.md) · [中文](../directory-layout.md)

```
Host (Windows)
├── Desktop\DeepSeek Harness.lnk     start (created by setup.ps1)
├── Desktop\dsh 管理台.lnk           menu: open dsh / status / checkup / sync / update / uninstall
├── %LOCALAPPDATA%\dsh-cloud\
│   ├── gh\                          portable GitHub CLI (gh\bin\gh.exe)
│   ├── ghconfig\                    gh's login token (plaintext; `gh auth logout` clears it)
│   ├── start-dsh.bat / update-dsh.bat   the two launcher scripts
│   ├── console.ps1 / console.bat    the control panel (+ the status/doctor/audit/update/uninstall it calls)
│   └── *-log.txt                    output of the last start / update
└── %USERPROFILE%\.ssh\dsh_cs_key    key used to SSH into the Codespace

Container (Codespaces)
├── /workspaces/<repo>/.dsh-cloud/   persistent volume: start.sh / update.sh / sync.sh / sync.conf (+ your own public-sync.sh)
├── /workspaces/<repo>/              the repo checkout (the folder VS Code opens)
├── ~/dsh-workspace/                 the workspace (a clone) where dsh does its work
├── ~/.dsh/                          dsh config, session history, credentials
├── ~/dsh-web.log / ~/dsh-sync.log   runtime logs (`~` is wiped when the container is rebuilt)
└── ~/.ssh/dsh_deploy                deploy key with write access to that one repo
```
