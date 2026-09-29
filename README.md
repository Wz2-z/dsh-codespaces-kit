# 用 GitHub Codespaces 部署 DeepSeek Harness（dsh）指南

> **公开版说明**：本指南不包含任何人的真实信息。文中 `<你的用户名>`、`<仓库名>`、`<codespace 名>`、`<名称>` 全部是占位符，请替换成你自己的；示例版本号写为 `v22.x.y` 之类。欢迎自由复制、修改、转发。
> 如果这份指南对你有用，照着 §2 把任务书丢给你的 AI 即可。

## 这个仓库里有什么

- `README.md`（本文件）—— 完整部署指南：人要做的事 + 直接给 AI 的任务书 + 技术细节 + 踩坑清单
- `plugins/dsh-codespace-panel/` —— dsh 插件：在 dsh 侧边栏显示 Codespaces 额度，并一键停止当前 Codespace
- `tools/restart-dsh.sh` —— 云端重启 dsh web 的小脚本（改完插件重启用得上）

## 安装 codespace-panel 插件（可选）

在**你自己的 dsh 云端容器**里执行（把内容拷进去，而不是在本地电脑上跑）：

```bash
# 1) 把插件取到容器里
git clone https://github.com/Wz2-z/dsh-codespaces-kit.git ~/dsh-public

# 2) 装进 dsh 的 web profile
cd ~/.dsh/profiles/web
pnpm add ~/dsh-public/plugins/dsh-codespace-panel

# 3) 让它在启动时加载：把 "dsh-codespace-panel" 加进 package.json 的
#    dsh.profile.bundles 数组，例如：
#      "bundles": ["@deepseek-ai/dsh-base", "@deepseek-ai/dsh-web-app", "dsh-codespace-panel"]
```

改完重启 dsh（`dsh web` 那个进程），刷新页面即可看到侧边栏底部的电池图标。

**凭据说明**：

- 额度数字：需要一个**经典 PAT**（Personal access token (classic)，勾选 `user` 权限），
  在面板里粘贴即可 —— 它存进 dsh 的凭据存储（`$DSH_HOME/.credentials.yaml`，0600），不会进仓库；
- 当前 Codespace 的状态与"一键停止"：用容器自带的平台令牌，**零配置**。

> clone 慢的话，也可以只把 `plugins/dsh-codespace-panel/` 这个文件夹拷进容器，再 `pnpm add <那个文件夹路径>`。


> 适用场景：想用官方 dsh，但**不想在本机跑 agent**、没有信用卡买云主机、或者想要一个完全隔离的云端环境。
> 成本：¥0（GitHub 免费额度：120 核·小时/月 ≈ 2 核 60 小时 + 15 GB 存储）
> 本机只需要装一个便携版 GitHub CLI，其余全部在云端。

---

## 零、先看懂这张图（30 秒）

```
你的电脑                               GitHub Codespaces（云端容器）
┌────────────────────┐                ┌──────────────────────────────┐
│ 浏览器              │                │  dsh web                     │
│  127.0.0.1:3080  ◄──┼── SSH 隧道 ───┼─► 监听 127.0.0.1:3080       │
│                    │                │                              │
│ gh CLI（便携版）    │                │  ~/dsh-workspace（工作区）   │
│  + SSH 密钥         │                │   = 你的私有仓库克隆          │
└────────────────────┘                │  每 5 分钟自动 commit + push │
                                      └──────────────────────────────┘
```

四个关键点：

1. **dsh 跑在云端容器里**，碰不到你本机文件（隔离）。
2. **必须用 SSH 隧道访问**（不能直接用 GitHub 的 `*.app.github.dev` 转发地址，原因见 §4.1）。
3. **工作区 = 一个私有 GitHub 仓库**，所以成果自动有版本备份。
4. **人只做 5 件事**，其余交给 AI。

---

# 第一部分：人要做的（约 15–20 分钟）

## 人需要准备什么

| 需要 | 说明 |
| --- | --- |
| GitHub 账号 | 13 岁以上可注册；未满 18 需家长知情同意。免费账号即可 |
| 一台电脑 | Windows 10/11（macOS/Linux 见 §6.1） |
| 网络 | 能访问 github.com 即可 |
| **不需要** | 信用卡、管理员权限、本地装 Node/Python |

## 第 1 步：建一个私有仓库（当"云端主机"）

打开 <https://github.com/new>：

- Repository name：随便，例如 `<仓库名>`
- 选 **Private**（务必私有：工作区里所有东西都会被推上来）
- 勾选 **Add a README file**
- Create repository

## 第 2 步：建 Codespace

1. 打开 <https://github.com/codespaces> → **New codespace**
2. Repository：选刚建的 `<仓库名>`
3. Region：**East US**（在美国就选这个，延迟最低）
4. Machine type：**2-core**（默认，够用）
5. 点 **Create codespace**，等 1–2 分钟，会打开一个浏览器里的 VS Code

顺手改一下闲置时间，否则 30 分钟就休眠：
<https://github.com/settings/codespaces> → **Default idle timeout** → 240 分钟

## 第 3 步：把任务书发给 AI

复制 §2 的「给 AI 的任务书」，把里面 `<...>` 的占位符换成你自己的信息，发给 AI（Codex / dsh / 任何 coding agent 都行），然后按它的提示操作。

## 第 4 步：配合 AI 做一次性授权

AI 会让你运行一次 `gh auth login`，屏幕上会出现一个**一次性验证码**，你需要：

1. 打开 <https://github.com/login/device>
2. 粘贴验证码 → **Authorize**

这一步是让本机的 GitHub CLI 能访问你的 Codespace（授权范围包含 `codespace`、`repo`）。只做一次。

## 第 5 步：以后就双击

AI 会在桌面放两个快捷方式（图标是 dsh 官方 logo）：

- **DeepSeek Harness**：启动（唤醒 Codespace → 拉起 dsh → 建隧道 → 打开浏览器）
- **更新 dsh**：把云端 dsh 升级到最新版

使用期间不要关那个最小化的 `dsh tunnel` 黑窗口。

## 第一次进 dsh 界面后要做的

1. 设置 → 模型 → DeepSeek 卡片 → 粘贴你的 **DeepSeek API Key**（建议单独申请一个低额度的 key）
2. 选择模型：`deepseek-flash`（支持图片）或 `deepseek-v4-pro`（纯文本，更强）
3. 选择工作区：`~/dsh-workspace`（或它的子目录）

---

# 第二部分：给 AI 的任务书（复制这段）

```text
我要用 GitHub Codespaces 在云端部署 DeepSeek Harness（dsh），请帮我配置好云端和本机。

【我的信息】
- GitHub 用户名：<你的用户名>
- 已建好的私有仓库：<你的用户名>/<仓库名>
- Codespace 名称：<从 https://github.com/codespaces 复制>
- 本机系统：Windows 11，普通用户（不是管理员）
- 我使用 DeepSeek 官方 API Key（自己充值）付费用量

【目标】
1. 我在本机双击一个脚本，就能打开云端 dsh 的 Web UI，不需要手动敲命令
2. 云端工作区 = 我那个私有仓库的克隆，改动自动 commit + push 备份
3. 不改本机系统设置、不需要管理员权限、不装全局软件（用便携版）
4. 权限保持最保守：新会话默认 workspace-write + ask，不启用 auto review

【请你完成】
A. 云端（Codespaces 容器内）
   - 装 Node 22（>=22.19）和 @deepseek-ai/dsh
   - 在 /workspaces/<repo>/.dsh-cloud/ 放三个脚本：
     start.sh（确保 dsh 在跑，最后一行输出带 token 的访问地址）
     update.sh（升级 dsh 到最新版并重启）
     sync.sh（每 5 分钟自动 commit + push 工作区，含空目录 .gitkeep 处理）
   - 配一把只对 <你的用户名>/<仓库名> 有写权限的 deploy key（不要用账号级 token）
   - 把 dsh 工作区克隆到 ~/dsh-workspace，git 使用这把 deploy key
   - 写 dsh 权限预设：defaultPreset=workspace-write，presets 里保留 read-only，
     并把 danger-full-access 的审批策略从 never 改成 ask
B. 本机（Windows）
   - 下载便携版 GitHub CLI 到 %LOCALAPPDATA%\dsh-cloud（解压即用，不装到系统）
   - 引导我做一次 gh auth login（scope 需要 codespace,repo,read:org,workflow）
   - 在 %USERPROFILE%\.ssh 下生成 SSH 密钥（必须由我这个用户生成，否则 Windows ssh 会拒绝）
   - 写两个脚本 + 桌面快捷方式（图标用 dsh 官方图标）：
     启动脚本：检查/唤醒 Codespace → 触发云端 start.sh → gh codespace ports forward 3080:3080
               → 用返回的 token 地址打开浏览器
     更新脚本：触发云端 update.sh → 同样建隧道并打开浏览器
C. 验证并告诉我结果
   - 云端 dsh 启动正常（不带 token 访问返回 401，带 token 返回 303）
   - 本机隧道能打开 dsh 界面
   - 工作区能 push 成功（本地 HEAD == 远端 main）

【已知的坑，请务必照做】
1. GitHub 的 *.app.github.dev 端口转发地址打不开 dsh —— dsh 的登录凭证绑定
   127.0.0.1:3080，必须在本机用 gh codespace ports forward 3080:3080 -c <名称>
   建隧道，再用 dsh 打印的带 token 地址访问。
2. Windows 批处理文件保持纯 ASCII，路径用 %USERPROFILE%，不要把中文文件名写进 .bat。
3. SSH 私钥必须由"使用这台电脑的人"在 %USERPROFILE%\.ssh 里生成；
   别人（或 agent 沙箱）生成的密钥，Windows 的 ssh 会报 Permission denied。
4. 不要用 pkill -f "dsh web"（命令自身包含该字符串，会把自己杀掉）；
   改用按端口找 PID：ss -ltnp | grep :3080，然后 kill 那个 PID。
5. 空文件夹不会被 git 跟踪，同步脚本要先给空目录放 .gitkeep 再 add。
6. 云端 /workspaces 是持久卷，$HOME 在容器重建后会清空 —— 脚本必须放 /workspaces。
7. 一次性长命令在 PTY 下可能被截断，改文件请用 base64 传输并避免 tty。
8. dsh 是否"识图"取决于模型：deepseek-v4-pro 是纯文本，deepseek-flash 支持图片
   （改的是模型声明的 inputModalities，不是某个全局 image 参数）。

【交付给我】
- 桌面两个快捷方式（启动 / 更新）
- 一份"我下次自己怎么用"的简短说明
- 云端脚本存进我的仓库（tools/dsh-cloud/），这样换电脑也能用
```

---

# 第三部分：技术细节（AI 执行清单）

## 3.1 云端做这些

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
# start.sh / update.sh / sync.sh —— 见 §6.2
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

## 3.2 本机做这些（Windows）

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

## 3.3 验收标准（AI 必须逐条验证）

| 检查项 | 期望结果 |
| --- | --- |
| 云端 dsh 进程 | `ss -ltn` 里能看到 `:3080` 在监听 |
| 无 token 访问 | 返回 **401** |
| 带 token 访问 | 返回 **303**，并种下 `dsh-auth-*` cookie |
| 本机隧道 | `curl http://127.0.0.1:3080/` 返回 401（说明隧道通了） |
| 浏览器 | 用返回的 token 地址能进 dsh 界面 |
| git 备份 | 本地 `HEAD` == `git ls-remote origin refs/heads/main` |
| 空目录同步 | 新建一个空文件夹，5 分钟内仓库里出现它 + `.gitkeep` |

---

# 第四部分：踩过的坑（照做能省几小时）

## 4.1 GitHub 端口转发地址打不开 dsh

把 Codespaces 的 3080 端口设成 Public/Private 后用 `https://xxx-3080.app.github.dev` 访问，会看到：

```
dsh web authentication required; reopen the URL printed by dsh web.
```

原因：dsh 的会话凭证（token → cookie）**绑定 authority `127.0.0.1:3080`**，换域名就对不上。
解法：本机执行 `gh codespace ports forward 3080:3080 -c <名称>`，然后访问 dsh 打印的原始地址。

## 4.2 Windows 批处理里的中文变成问号

.bat 若按 ASCII 保存，中文文件名会变成 `????`，于是报 `FINDSTR: 无法打开 ...dsh????.txt`。
解法：批处理保持**纯 ASCII**，用 `%USERPROFILE%` 拼路径，日志文件名也用英文。

## 4.3 SSH 私钥被拒绝：Load key ...: Permission denied

私钥如果由别的用户（或 agent 沙箱）创建，Windows OpenSSH 会拒绝加载。
解法：让**使用者本人**在 `%USERPROFILE%\.ssh\` 里用 `ssh-keygen` 生成；必要时执行
`icacls <key> /inheritance:r /grant:r "%USERNAME%:R"`。

## 4.4 云端的 ~/.nvm/nvm.sh 可能不存在

Codespaces 的 nvm 可能在 `/usr/local/share/nvm`，而 `~/.nvm` 里只有 versions。
解法：脚本里直接写绝对路径 `$HOME/.nvm/versions/node/v22.x.y/bin`，或做多路径探测（见 §6.2）。

## 4.5 pkill -f "dsh web" 把自己杀掉了

SSH 里执行的命令字符串本身包含 `dsh web`，`pkill -f` 会连自己一起杀，
表现为 `shell closed: exit status 0xffffffff`。
解法：按端口找 PID 再 kill：

```bash
PID=$(ss -ltnp 2>/dev/null | grep ':3080' | grep -o 'pid=[0-9]*' | head -1 | cut -d= -f2)
if [ -n "$PID" ]; then kill "$PID"; fi
```

## 4.6 超长命令在 PTY 下被截断

一次性传一大段脚本时，带 tty 的连接可能截断命令，报 `syntax error near unexpected token '('`。
解法：用 base64 传文件，并且**不要开 tty**。

## 4.7 空目录不会被同步

git 不跟踪空目录，新建的文件夹不会出现在仓库里。
解法：同步脚本每次先给空目录放 `.gitkeep`（跳过 `node_modules` 和被忽略的目录）。

## 4.8 容器重建会丢 $HOME

Codespaces 的 `/workspaces` 是持久卷，但容器重建（改 devcontainer、Rebuild）会清空 `$HOME`：
dsh 需要重装、`~/.dsh` 会话历史会丢（脚本仍在 `/workspaces`，deploy key 需要重建）。
解法：脚本放 `/workspaces`；重要成果 push 到仓库；不要随便改 devcontainer 配置。

## 4.9 "dsh 不能识图"其实是模型问题

dsh 支持图片输入，但取决于模型声明的模态：

| 模型 | 输入模态 | 结论 |
| --- | --- | --- |
| `deepseek-flash` | text + image | 能看图（1M 上下文） |
| `deepseek-v4-pro` | text | 纯文本 |

切换模型即可；只有自建/中转网关的视觉模型才需要在「设置 → 模型 → 自定义设置 → 模型选项 → 输入类型」
勾选"图片"（保存为 `input` 或 `inputModalities`）。

---

# 第五部分：日常维护与常见问题

| 想做什么 | 怎么做 |
| --- | --- |
| 启动 | 双击桌面「DeepSeek Harness」 |
| 升级 dsh | 双击桌面「更新 dsh」 |
| 立刻同步一次 | 云端执行 `bash /workspaces/<repo>/.dsh-cloud/sync.sh --once` |
| 省额度 | <https://github.com/codespaces> 点 **Stop** |
| 看用了多少额度 | <https://github.com/settings/billing> 里的 Codespaces 一节 |
| 换电脑用 | 让 AI 按 §2 的 B 部分生成一个便携版启动脚本，拷到新电脑双击即可（首次要授权一次 gh） |
| 排查问题 | 云端 `~/dsh-web.log`、`~/dsh-sync.log`、`~/dsh-update.log`；本机启动脚本旁边的日志文件 |

**数据保留**：Codespace 默认 **30 天不活跃会被自动删除**（`~/dsh-workspace`、`~/.dsh` 都会没），
所以工作区必须 push 到仓库。会话历史（`~/.dsh`）不在仓库里，想备份要额外做。

**安全提醒**：

- 工作区里**不要放密钥、密码**，所有文件都会被推到仓库。
- 插件在 dsh 宿主进程内运行，权限等于你的云端账号 —— 优先装下载量高、来源清楚的；
  不确定的插件先在 `read-only` 权限下试跑。
- 主目录里的 `~/.dsh/.credentials.yaml`（API Key）和 `~/.ssh` 私钥不要交给 agent。
- 想更省心，可以只给 dsh 一个低额度、可随时吊销的 API Key。

---

# 第六部分：附录

## 6.1 macOS / Linux 本机

```bash
brew install gh            # 或 sudo apt install gh
gh auth login --hostname github.com --git-protocol https --web --scopes codespace,repo,read:org,workflow
ssh-keygen -t ed25519 -N "" -f ~/.ssh/dsh_cs_key -C dsh-codespace
gh codespace ssh -c <名称> -- -i ~/.ssh/dsh_cs_key "bash /workspaces/<repo>/.dsh-cloud/start.sh"
gh codespace ports forward 3080:3080 -c <名称> &     # 保持在后台运行
# 打开上一条命令最后一行打印的 http://127.0.0.1:3080/?token=... 地址
```

## 6.2 云端三个脚本（精简版参考）

`start.sh`：确保 dsh 在跑 → 拉起同步循环 → 最后一行打印访问地址

```bash
#!/usr/bin/env bash
set -u
LOG="$HOME/dsh-web.log"; SYNC="/workspaces/<repo>/.dsh-cloud/sync.sh"
NODE_BIN="$HOME/.nvm/versions/node/v22.x.y/bin"
ensure_dsh() {
  if [ -x "$NODE_BIN/dsh" ]; then export PATH="$NODE_BIN:$PATH"; return 0; fi
  for d in "$HOME/.nvm/versions/node"/*/bin "$HOME/nvm/current/bin" /usr/local/share/nvm/versions/node/*/bin; do
    if [ -x "$d/dsh" ]; then export PATH="$d:$PATH"; return 0; fi
  done
  npm install -g @deepseek-ai/dsh >>"$LOG.install" 2>&1 || true
  command -v dsh >/dev/null 2>&1
}
ensure_dsh || { echo "STATE:NO_DSH"; exit 1; }
mkdir -p "$HOME/dsh-workspace"
if ! curl -s -o /dev/null -m 3 http://127.0.0.1:3080/; then
  (setsid nohup bash -c "cd $HOME/dsh-workspace && exec dsh web" >"$LOG" 2>&1 </dev/null &)
  sleep 20
fi
if [ -x "$SYNC" ] && ! pgrep -f 'dsh-cloud/sync.sh' >/dev/null 2>&1; then
  (setsid nohup bash "$SYNC" 300 >/dev/null 2>&1 </dev/null &)
fi
echo "STATE:$(curl -s -o /dev/null -w '%{http_code}' -m 3 http://127.0.0.1:3080/ || true)"
grep -a -o 'http://127.0.0.1:3080[^ ]*' "$LOG" | tail -n 1
```

`update.sh`：升级并重启

```bash
#!/usr/bin/env bash
export PATH="$HOME/.nvm/versions/node/v22.x.y/bin:$PATH"
echo "BEFORE:$(dsh --version 2>/dev/null || echo unknown)"
npm install -g @deepseek-ai/dsh@latest >>"$HOME/dsh-update.log" 2>&1 || { echo UPDATE:FAILED; exit 1; }
echo "AFTER:$(dsh --version 2>/dev/null || echo unknown)"
PID=$(ss -ltnp 2>/dev/null | grep ':3080' | grep -o 'pid=[0-9]*' | head -1 | cut -d= -f2)
if [ -n "$PID" ]; then kill "$PID"; sleep 2; fi
bash /workspaces/<repo>/.dsh-cloud/start.sh
```

`sync.sh`：自动提交推送（含空目录处理）

```bash
#!/usr/bin/env bash
set -u
WORK="$HOME/dsh-workspace"; LOG="$HOME/dsh-sync.log"
keep_empty_dirs() {
  find "$WORK" \( -name .git -o -name node_modules \) -prune -o -type d -empty -print0 2>/dev/null |
    while IFS= read -r -d '' d; do
      rel="${d#"$WORK"/}"
      if ! git -C "$WORK" check-ignore -q -- "$rel"; then : >"$d/.gitkeep"; fi
    done
}
sync_once() {
  cd "$WORK" || return 1
  keep_empty_dirs
  if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
    git add -A
    git -c user.name="dsh cloud" -c user.email="dsh-cloud@users.noreply.github.com" \
      commit -q -m "auto-sync $(date '+%Y-%m-%d %H:%M:%S')" >>"$LOG" 2>&1
    if git push -q origin HEAD >>"$LOG" 2>&1; then
      echo "$(date -Is) pushed" >>"$LOG"
    else
      echo "$(date -Is) push FAILED" >>"$LOG"
    fi
  fi
}
case "${1:-300}" in
  --once) sync_once; exit $? ;;
  *) INTERVAL="$1" ;;
esac
while true; do sleep "$INTERVAL"; sync_once; done
```

## 6.3 目录结构

```
本机（Windows）
├── Desktop\DeepSeek Harness.lnk          启动
├── Desktop\更新 dsh.lnk                   更新
├── %LOCALAPPDATA%\dsh-cloud\gh\          便携版 GitHub CLI
└── %USERPROFILE%\.ssh\dsh_cs_key         连接 Codespace 的私钥

云端（Codespaces 容器）
├── /workspaces/<repo>/.dsh-cloud/        持久卷：start.sh / update.sh / sync.sh
├── /workspaces/<repo>/                   仓库本体（VS Code 打开的那个）
├── ~/dsh-workspace/                      工作区（仓库克隆，dsh 在这里干活）
├── ~/.dsh/                               dsh 配置、会话历史、API Key
└── ~/.ssh/dsh_deploy                     只对该仓库有写权限的 deploy key
```

---

**一句话总结**：云端跑 agent、隧道回本机、仓库做备份、脚本做自动化。
把 §2 的任务书丢给 AI，再按它的提示点几次按钮，就能得到同样的环境。
