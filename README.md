# 用 GitHub Codespaces 部署 DeepSeek Harness（dsh）

在云端跑官方 dsh，本机只负责开一条 SSH 隧道 —— 成果自动备份到你自己的私有仓库。

版本 [`v1.0.0`](CHANGELOG.md) · 一键安装脚本在 [`install/`](install/)

| | |
| --- | --- |
| **适合谁** | 想用官方 dsh，但不想在本机跑 agent、没有信用卡买云主机、或者想要一个完全隔离的云端环境 |
| **成本** | 在账户自带的 Codespaces 使用额度内可**零额外费用**运行（免费账号：120 核·小时/月 ≈ 2 核 60 小时 + 15 GB 存储）；**超出额度可能产生费用**（按 GitHub 的计费标准） |
| **本机要装什么** | 一个便携版 GitHub CLI。不用管理员权限，不装 Node / Python |
| **要多久** | 第一次约 15–20 分钟，大部分时间是等 AI 干活 |

> **公开版说明**：本指南不含任何人的真实信息。文中 `<你的用户名>`、`<仓库名>`、`<codespace 名>`、`<名称>` 都是占位符，请替换成你自己的；示例版本号写成 `v22.x.y` 之类。

---

## 30 秒了解

```
你的电脑                               GitHub Codespaces（云端容器）
┌────────────────────┐                ┌──────────────────────────────┐
│ 浏览器              │                │  dsh web                     │
│  127.0.0.1:3080  ◄──┼── SSH 隧道 ───┼─► 监听 127.0.0.1:3080       │
│                    │                │                              │
│ gh CLI（便携版）    │                │  ~/dsh-workspace（工作区）   │
│  + SSH 密钥         │                │   = 你的私有仓库克隆          │
└────────────────────┘                │  静默一会儿自动 commit + push │
                                      └──────────────────────────────┘
```

四个关键点：

1. **dsh 跑在云端容器里**，碰不到你本机文件（隔离）。
2. **必须用 SSH 隧道访问**：GitHub 自带的 `*.app.github.dev` 转发地址打不开 dsh，
   原因见 [Troubleshooting · Codespaces](docs/troubleshooting/codespaces.md)。
3. **工作区 = 一个私有 GitHub 仓库**，成果自动有版本备份：改动停下来（默认 10 分钟）自动提交一次，
   提交信息按改动内容生成，见 [自动同步](docs/auto-sync.md)。
4. **人只做下面 5 步**（或者直接跑 [`install/`](install/) 里的一键脚本），其余交给 AI。

装完想确认一切正常？跑一次体检：[`dsh-codespaces doctor`](#体检dsh-codespaces-doctor) —— 本机 + 云端 12 项检查。

---

## 快速安装（约 15–20 分钟）

### 准备

| 需要 | 说明 |
| --- | --- |
| GitHub 账号 | 13 岁以上可注册；未满 18 需家长知情同意。免费账号即可 |
| 一台电脑 | Windows 10/11；macOS / Linux 见 [本机适配](docs/macos-linux.md) |
| 网络 | 能访问 github.com 即可 |
| **不需要** | 信用卡、管理员权限、本地装 Node / Python |

### 路线 A：一键脚本（推荐）

**Windows**（普通用户权限即可）：

```powershell
irm https://raw.githubusercontent.com/Wz2-z/dsh-codespaces-kit/main/install/setup.ps1 -OutFile setup.ps1
notepad setup.ps1        # 想先看一眼就打开它
powershell -ExecutionPolicy Bypass -File setup.ps1 -Repo 你的用户名/仓库名
```

**macOS / Linux**：

```bash
curl -fsSLO https://raw.githubusercontent.com/Wz2-z/dsh-codespaces-kit/main/install/setup.sh
less setup.sh            # 想先看一眼
bash setup.sh --repo=你的用户名/仓库名
```

脚本自己会走完这条流水线：

```
检查 GitHub CLI → 检查 Codespace → 检查 Node → 安装 dsh →
配置 workspace → 生成 deploy key → 配置 sync → 验证
```

最后打印 `✅ Installation complete`，并在桌面放好启动器。想先看看它打算做什么：
加 `-DryRun`（PowerShell）/ `--dry-run`（bash）。细节见 [install/README.md](install/README.md)。

### 路线 B：手动五步（想全程自己点）

#### 第 1 步：建一个私有仓库（当"云端主机"）

打开 <https://github.com/new>：

- Repository name：随便，例如 `<仓库名>`
- 选 **Private**（务必私有：工作区里所有东西都会被推上来）
- 勾选 **Add a README file**
- Create repository

#### 第 2 步：建 Codespace

1. 打开 <https://github.com/codespaces> → **New codespace**
2. Repository：选刚建的 `<仓库名>`
3. Region：**East US**（在美国就选这个，延迟最低）
4. Machine type：**2-core**（默认，够用）
5. 点 **Create codespace**，等 1–2 分钟，会打开一个浏览器里的 VS Code

顺手改一下闲置时间，否则 30 分钟就休眠：
<https://github.com/settings/codespaces> → **Default idle timeout** → 240 分钟

#### 第 3 步：把任务书发给 AI

复制 [给 AI 的任务书](docs/ai-prompt.md)（一整段），把里面 `<...>` 的占位符换成你自己的信息，
发给 AI（Codex / dsh / 任何 coding agent 都行），然后按它的提示操作。

#### 第 4 步：配合 AI 做一次性授权

AI 会让你运行一次 `gh auth login`，屏幕上会出现一个**一次性验证码**，你需要：

1. 打开 <https://github.com/login/device>
2. 粘贴验证码 → **Authorize**

这一步是让本机的 GitHub CLI 能访问你的 Codespace（授权范围包含 `codespace`、`repo`）。只做一次。

#### 第 5 步：以后就双击

AI 会在桌面放两个快捷方式（图标是 dsh 官方 logo）：

- **DeepSeek Harness**：启动（唤醒 Codespace → 拉起 dsh → 建隧道 → 打开浏览器）
- **更新 dsh**：把云端 dsh 升级到最新版

使用期间不要关那个最小化的 `dsh tunnel` 黑窗口。

---

## 配置

### 第一次进 dsh 界面后要做的

1. 设置 → 模型 → DeepSeek 卡片 → 粘贴你的 **DeepSeek API Key**
   （建议单独申请一个低额度、可随时吊销的 key）
2. 选择模型：`deepseek-flash`（支持图片）或 `deepseek-v4-pro`（纯文本，更强）
3. 选择工作区：`~/dsh-workspace`（或它的子目录；别选主目录，那里有 API Key 和私钥）

### 权限（默认已经是最保守的）

- 新会话默认 `workspace-write` + `ask`：能改工作区，敏感操作要你点确认
- 需要更严时可以切到 `read-only`
- `danger-full-access` 的审批策略是 `ask`（不是 `never`）

具体 YAML 见 [技术细节 · 云端](docs/ai-runbook.md)。

### 可选插件

| 插件 | 干什么 |
| --- | --- |
| [`dsh-codespace-panel`](plugins/dsh-codespace-panel/) | 在 dsh 侧边栏看 Codespaces 额度，并一键停止当前 Codespace |
| [`dsh-sync-panel`](plugins/dsh-sync-panel/) | 在 dsh 侧边栏看自动同步状态，并能暂停/恢复/立即提交/切换模式 |

安装方法见 [插件](docs/plugins.md)。

> 插件在 dsh 宿主进程内运行，权限等于你的云端账号 —— 优先装下载量高、来源清楚的；不确定的先在 `read-only` 权限下试跑。

---

## 日常使用

| 想做什么 | 怎么做 |
| --- | --- |
| 启动 | 双击桌面「DeepSeek Harness」 |
| 升级 dsh | 双击桌面「更新 dsh」 |
| 立刻同步一次 | 云端执行 `bash /workspaces/<repo>/.dsh-cloud/sync.sh --now` |
| 看同步状态 / 待提交的改动 | 点侧边栏的同步按钮，或 `bash .dsh-cloud/sync.sh --status` |
| 换同步模式（智能批量 / 固定周期 / 只手动） | `bash .dsh-cloud/sync.sh --mode=idle\|interval\|manual` |
| 暂停 / 恢复自动同步 | `bash .dsh-cloud/sync.sh --disable` / `--enable` |
| 省额度 | <https://github.com/codespaces> 点 **Stop** |
| 看用了多少额度 | <https://github.com/settings/billing> 里的 Codespaces 一节（或装上面的插件） |
| 换电脑用 | 让 AI 按任务书的 B 部分生成便携版启动脚本，拷到新电脑双击即可（首次要授权一次 `gh`） |
| 排查问题 | 云端 `~/dsh-web.log`、`~/dsh-sync.log`、`~/dsh-update.log`；本机启动脚本旁边的日志文件 |

**数据保留**：Codespace 默认 **30 天不活跃会被自动删除**（`~/dsh-workspace`、`~/.dsh` 都会没），
所以工作区必须 push 到仓库。会话历史（`~/.dsh`）不在仓库里，想备份要额外做。

**安全提醒**：

- 工作区里**不要放密钥、密码**，所有文件都会被推到仓库。
- 主目录里的 `~/.dsh/.credentials.yaml`（API Key）和 `~/.ssh` 私钥不要交给 agent。

---

## 体检：`dsh-codespaces doctor`

任何时候觉得"哪里不对"，先跑这个：

```powershell
# Windows（也可以双击桌面「dsh 体检」）
powershell -ExecutionPolicy Bypass -File install\doctor.ps1
```

```bash
# macOS / Linux
bash install/doctor.sh
# 或者：./install/dsh-codespaces.sh doctor
```

```
GitHub CLI               ✓  gh version 2.101.0 (2026-09-15)
GitHub authentication    ✓  已登录：<你的账号>
Codespace                ✓  your-codespace（Available）
DSH                      ✓  0.1.7-rc.2（/home/codespace/.nvm/versions/node/v22.x.y/bin）
SSH key                  ✓  ~/.ssh/dsh_cs_key（可读，ssh-ed25519）
Workspace                ✓  干净，HEAD=1a2b3c4（与远端一致）
Deploy key               ✓  ed25519，能读写 <你的仓库>
Auto sync                ✓  守护进程 pid 12345 · 模式 idle · 最近一条日志 …
Sync config              ✓  mode=idle · 静默 600s · 折叠 1800s
dsh web                  ✓  监听 127.0.0.1:3080，需要 token（401 = 正常）
Tunnel                   ✓  127.0.0.1:3080 → 401（需要 token，正常）
Launcher                 ✓  桌面有 DeepSeek Harness / 更新 dsh

12/12 checks passed
```

- 前 4 项是本机侧，中间 6 项由本机把 `install/cloud-doctor.sh` 送进容器执行，最后 2 项是本机侧的隧道与启动器
- `✓` 正常 / `!` 警告（能用，看一眼）/ `✗` 坏了（上面写着怎么修）；有 `✗` 时退出码为 1
- `-NoTunnel`（PowerShell）/ `--no-tunnel`（bash）跳过隧道检查；`-Json` / `--json` 输出 JSON
- 每一项对应的修法见 [docs/doctor.md](docs/doctor.md)

## 生命周期与安全清单

同一个入口下还有四个命令，覆盖"从装到卸"：

```
dsh-codespaces status      一眼看清现在（Codespace / Tunnel / DSH / 同步 / 上次推送 / 待提交）
dsh-codespaces audit       凭据与权限清单：创建了哪些 key/token/config，各自能干什么
dsh-codespaces repair      重新跑一遍安装（幂等）再体检，适合"哪里不对"
dsh-codespaces update      升级云端 dsh 并重建隧道
dsh-codespaces uninstall   卸载 / 撤销（默认只预览，要 -Yes + 范围开关才动手）
```

`status` 的输出长这样：

```
Codespace       Running   your-codespace（Available）
Tunnel          Healthy   127.0.0.1:3080 → 401（需要 token，正常）
DSH             Healthy   0.1.7-rc.2 · pid 62857 · HTTP 401
Auto sync       Running   idle · on · daemon pid 54889 · 静默 600s · 折叠 1800s
Last check      32 seconds ago
Last push       1 minute ago · dsh: add projects/plugincreate (6 files)
Pending files   0
In sync         yes（本地 19a6c79 / 远端 19a6c79）
```

- 生命周期细节：[docs/lifecycle.md](docs/lifecycle.md)
- **它到底创建了什么、各自能干什么、怎么撤销**：[docs/security-model.md](docs/security-model.md)
  （一句话：没有账号级 PAT、没有 GitHub App、没有云厂商账号、没有 sudo 改动）

---

## Troubleshooting

正常安装不需要读这一节。出问题时按现象找：

| 现象 | 去哪看 |
| --- | --- |
| `.bat` 里的中文变成 `????`、路径含中文、桌面快捷方式不对 | [Windows](docs/troubleshooting/windows.md) |
| `Load key ...: Permission denied`、连不上 Codespace、隧道建不起来 | [SSH](docs/troubleshooting/ssh.md) |
| `*.app.github.dev` 打不开、容器重建后环境没了、额度/休眠、命令被截断、空目录不同步 | [Codespaces](docs/troubleshooting/codespaces.md) |
| 提示 `dsh web authentication required`、能不能识图、插件不生效、权限太宽 | [dsh](docs/troubleshooting/dsh.md) |

每个文件都是「**现象 → 原因 → 解法**」三段式，可以单独转发给 AI 让它照着修。

---

## 仓库里有什么

| 路径 | 内容 |
| --- | --- |
| `README.md` | 本文件：快速安装 + 配置 + 日常使用 |
| `install/` | 一键安装：`setup.ps1`（Windows）/ `setup.sh`（macOS、Linux）/ `cloud-setup.sh`（云端 8 步） |
| `docs/ai-prompt.md` | 给 AI 的任务书（复制这段） |
| `docs/ai-runbook.md` | 技术细节：云端 / 本机命令 + 验收标准 |
| `docs/cloud-scripts.md` | 云端三个脚本（`start.sh` / `update.sh` / `sync.sh`）精简版参考 |
| `docs/auto-sync.md` | 自动同步怎么工作：三种模式、提交信息、配置项 |
| `docs/doctor.md` | 体检的 12 项分别是什么、坏了怎么修 |
| `docs/lifecycle.md` | status / setup / repair / update / uninstall 各自的用法 |
| `docs/security-model.md` | 创建了哪些 key/token/config，各自权限与撤销方式 |
| `docs/macos-linux.md` | macOS / Linux 本机怎么用 |
| `docs/plugins.md` | 插件怎么装（含 `dsh-codespace-panel`） |
| `docs/directory-layout.md` | 本机与云端的目录结构 |
| `docs/troubleshooting/` | 排错手册：Windows / SSH / Codespaces / dsh |
| `plugins/dsh-codespace-panel/` | dsh 插件：Codespaces 额度面板 + 一键停止 |
| `plugins/dsh-sync-panel/` | dsh 插件：自动同步面板（模式 / 待提交 / 立即提交 / 暂停） |
| `tools/restart-dsh.sh` | 云端重启 dsh web 的小脚本（改完插件重启用得上） |
| `tools/squash-autosync.sh` | 把历史上连续的 `auto-sync` 提交合并掉（默认只预览，会建备份分支） |
| `VERSION` / `CHANGELOG.md` | 版本号与更新日志 |

---

**一句话总结**：云端跑 agent、隧道回本机、仓库做备份、脚本做自动化。
把[任务书](docs/ai-prompt.md)丢给 AI，再按它的提示点几次按钮，就能得到同样的环境。

## 许可证

- **代码**（`plugins/`、`tools/`）：[MIT](LICENSE)
- **文档**（本 README 等说明文字）：[CC BY 4.0](LICENSE-docs)，可自由复制、修改、转发，保留署名即可。

- **作者**：[@Wz2-z](https://github.com/Wz2-z)
