# 用 GitHub Codespaces 部署 DeepSeek Harness（dsh）

在云端跑官方 dsh，本机只负责开一条 SSH 隧道 —— 成果自动备份到你自己的私有仓库。

| | |
| --- | --- |
| **适合谁** | 想用官方 dsh，但不想在本机跑 agent、没有信用卡买云主机、或者想要一个完全隔离的云端环境 |
| **成本** | ¥0（GitHub 免费额度：120 核·小时/月 ≈ 2 核 60 小时 + 15 GB 存储） |
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
└────────────────────┘                │  每 5 分钟自动 commit + push │
                                      └──────────────────────────────┘
```

四个关键点：

1. **dsh 跑在云端容器里**，碰不到你本机文件（隔离）。
2. **必须用 SSH 隧道访问**：GitHub 自带的 `*.app.github.dev` 转发地址打不开 dsh，
   原因见 [Troubleshooting · Codespaces](docs/troubleshooting/codespaces.md)。
3. **工作区 = 一个私有 GitHub 仓库**，所以成果自动有版本备份。
4. **人只做下面 5 步**，其余交给 AI。

---

## 快速安装（约 15–20 分钟）

### 准备

| 需要 | 说明 |
| --- | --- |
| GitHub 账号 | 13 岁以上可注册；未满 18 需家长知情同意。免费账号即可 |
| 一台电脑 | Windows 10/11；macOS / Linux 见 [本机适配](docs/macos-linux.md) |
| 网络 | 能访问 github.com 即可 |
| **不需要** | 信用卡、管理员权限、本地装 Node / Python |

### 第 1 步：建一个私有仓库（当"云端主机"）

打开 <https://github.com/new>：

- Repository name：随便，例如 `<仓库名>`
- 选 **Private**（务必私有：工作区里所有东西都会被推上来）
- 勾选 **Add a README file**
- Create repository

### 第 2 步：建 Codespace

1. 打开 <https://github.com/codespaces> → **New codespace**
2. Repository：选刚建的 `<仓库名>`
3. Region：**East US**（在美国就选这个，延迟最低）
4. Machine type：**2-core**（默认，够用）
5. 点 **Create codespace**，等 1–2 分钟，会打开一个浏览器里的 VS Code

顺手改一下闲置时间，否则 30 分钟就休眠：
<https://github.com/settings/codespaces> → **Default idle timeout** → 240 分钟

### 第 3 步：把任务书发给 AI

复制 [给 AI 的任务书](docs/ai-prompt.md)（一整段），把里面 `<...>` 的占位符换成你自己的信息，
发给 AI（Codex / dsh / 任何 coding agent 都行），然后按它的提示操作。

### 第 4 步：配合 AI 做一次性授权

AI 会让你运行一次 `gh auth login`，屏幕上会出现一个**一次性验证码**，你需要：

1. 打开 <https://github.com/login/device>
2. 粘贴验证码 → **Authorize**

这一步是让本机的 GitHub CLI 能访问你的 Codespace（授权范围包含 `codespace`、`repo`）。只做一次。

### 第 5 步：以后就双击

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

安装方法见 [插件](docs/plugins.md)。

> 插件在 dsh 宿主进程内运行，权限等于你的云端账号 —— 优先装下载量高、来源清楚的；不确定的先在 `read-only` 权限下试跑。

---

## 日常使用

| 想做什么 | 怎么做 |
| --- | --- |
| 启动 | 双击桌面「DeepSeek Harness」 |
| 升级 dsh | 双击桌面「更新 dsh」 |
| 立刻同步一次 | 云端执行 `bash /workspaces/<repo>/.dsh-cloud/sync.sh --once` |
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
| `docs/ai-prompt.md` | 给 AI 的任务书（复制这段） |
| `docs/ai-runbook.md` | 技术细节：云端 / 本机命令 + 验收标准 |
| `docs/cloud-scripts.md` | 云端三个脚本（`start.sh` / `update.sh` / `sync.sh`）精简版参考 |
| `docs/macos-linux.md` | macOS / Linux 本机怎么用 |
| `docs/plugins.md` | 插件怎么装（含 `dsh-codespace-panel`） |
| `docs/directory-layout.md` | 本机与云端的目录结构 |
| `docs/troubleshooting/` | 排错手册：Windows / SSH / Codespaces / dsh |
| `plugins/dsh-codespace-panel/` | dsh 插件：Codespaces 额度面板 + 一键停止 |
| `tools/restart-dsh.sh` | 云端重启 dsh web 的小脚本（改完插件重启用得上） |

---

**一句话总结**：云端跑 agent、隧道回本机、仓库做备份、脚本做自动化。
把[任务书](docs/ai-prompt.md)丢给 AI，再按它的提示点几次按钮，就能得到同样的环境。

## 许可证

- **代码**（`plugins/`、`tools/`）：[MIT](LICENSE)
- **文档**（本 README 等说明文字）：[CC BY 4.0](LICENSE-docs)，可自由复制、修改、转发，保留署名即可。

- **作者**：[@Wz2-z](https://github.com/Wz2-z)
