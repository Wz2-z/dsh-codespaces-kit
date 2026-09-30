> [← 回到 README](../README.md)
>
> 这一页是给 AI 看的执行清单，人不用逐条读。
> 正常安装时，把[任务书](ai-prompt.md)丢给 AI，它会照着这页做并逐条验收。

# 技术细节（AI 执行清单）

> [English version](en/ai-runbook.md)

## 1. 云端做这些

在 Codespace 的终端里（或在 AI 通过 SSH 连接后）：

```bash
# 1) 装 Node 22 与 dsh（Codespaces 的 nvm 可能在 /usr/local/share/nvm）
export NVM_DIR=/usr/local/share/nvm; . $NVM_DIR/nvm.sh
nvm install 22 && nvm alias default 22
npm install -g @deepseek-ai/dsh
node -v && dsh --version

# 2) 工作区 = 私有仓库克隆
cd ~ && git clone git@github.com:<你>/<仓库名>.git dsh-workspace

# 3) 脚本放持久卷（容器重建也不丢）
mkdir -p /workspaces/<仓库名>/.dsh-cloud
# start.sh / update.sh / sync.sh —— 见 [云端三个脚本](cloud-scripts.md)
```

**deploy key（只给这一个仓库写权限）**：

```bash
ssh-keygen -t ed25519 -N "" -f ~/.ssh/dsh_deploy -C dsh-deploy
cat ~/.ssh/dsh_deploy.pub
# 把这行公钥加到仓库 Settings -> Deploy keys，勾选 Allow write access；
# 或在能访问 GitHub API 的机器上：
# gh api -X POST /repos/<你>/<仓库名>/keys -f title="dsh-cloud autosync" -f key="<公钥>" -F read_only=false
```

```bash
# 让工作区用这把 key
cd ~/dsh-workspace
git config core.sshCommand "ssh -i $HOME/.ssh/dsh_deploy -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new"
git config user.name "dsh cloud"
git config user.email "dsh-cloud@users.noreply.github.com"
```

**dsh 权限预设**（追加到 `~/.dsh/profiles/web/cordis.patch.yml`）：

```yaml
- id: sandbox-policy
  name: "@deepseek-ai/dsh-sandbox-policy"
  config:
    mode: workspace-write
    workspaceRoot: !!js process.cwd()
- id: approval
  name: "@deepseek-ai/dsh-user-approval"
  config:
    policy: ask
- id: permission
  name: "@deepseek-ai/dsh-permission-presets"
  config:
    defaultPreset: workspace-write
    presets:
      read-only:
        sandbox: read-only
        approval: ask
      workspace-write:
        sandbox: workspace-write
        approval: ask
      danger-full-access:
        sandbox: danger-full-access
        approval: ask
```

## 2. 本机做这些（Windows）

```bat
:: 便携版 gh（不需要管理员权限）
set "DIR=%LOCALAPPDATA%\dsh-cloud"
curl.exe -sL -o "%DIR%\gh.zip" https://github.com/cli/cli/releases/download/vX.Y.Z/gh_X.Y.Z_windows_amd64.zip
powershell -NoProfile -Command "Expand-Archive -LiteralPath '%DIR%\gh.zip' -DestinationPath '%DIR%\gh' -Force"

:: 一次性授权（需要 codespace 权限）
"%DIR%\gh\bin\gh.exe" auth login --hostname github.com --git-protocol https --web --scopes codespace,repo,read:org,workflow

:: 生成 SSH 密钥（必须由当前用户生成）
ssh-keygen -t ed25519 -N "" -f "%USERPROFILE%\.ssh\dsh_cs_key" -C dsh-codespace

:: 启动：云端拉起 dsh（最后一行会打印带 token 的地址）
"%DIR%\gh\bin\gh.exe" codespace ssh -c <codespace 名> -- -i "%USERPROFILE%\.ssh\dsh_cs_key" "bash /workspaces/<仓库名>/.dsh-cloud/start.sh"

:: 本机建隧道（保持这个窗口开着）
start "dsh tunnel" /min cmd /c ""%DIR%\gh\bin\gh.exe" codespace ports forward 3080:3080 -c <codespace 名>"

:: 然后用打印出来的 http://127.0.0.1:3080/?token=... 打开浏览器
```

## 3. 验收标准（AI 必须逐条验证）

| 检查项 | 期望结果 |
| --- | --- |
| 云端 dsh 进程 | `ss -ltn` 里能看到 `:3080` 在监听 |
| 无 token 访问 | 返回 **401** |
| 带 token 访问 | 返回 **303**，并种下 `dsh-auth-*` cookie |
| 本机隧道 | `curl http://127.0.0.1:3080/` 返回 401（说明隧道通了） |
| 浏览器 | 用返回的 token 地址能进 dsh 界面 |
| git 备份 | 本地 `HEAD` == `git ls-remote origin refs/heads/main` |
| 空目录同步 | 新建一个空文件夹，等改动静默下来后仓库里出现它 + `.gitkeep` |

---

[← 回到 README](../README.md)
