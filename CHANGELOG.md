# 更新日志

版本号规则：`MAJOR.MINOR.PATCH`（[语义化版本](https://semver.org/lang/zh-CN/)）。
发新版时改三处：本文件、[`VERSION`](VERSION)、`install/setup.ps1` 与 `install/setup.sh` 里的 `KIT_VERSION`。

## [1.3.0] - 2026-09-29

自动同步有"看得见"的控制面了：一个 dsh 插件 + 一个 Windows 桌面控制台。

**新插件 `plugins/dsh-sync-panel/`**（独立包，不属于 codespace-panel）

- dsh 侧边栏底部多一个同步按钮，点开是一个面板：模式、是否暂停、守护进程在不在跑、
  待提交文件、最近一次提交、折叠窗口、`~/dsh-sync.log` 的尾巴
- 面板上直接操作：立即提交 / 暂停 / 恢复 / 切换 `idle|interval|manual` / 折叠窗口开或关
- 两条 EXACT 路由（`/sync-panel/summary`、`/sync-panel/action`）都要求自定义请求头
  `x-sync-panel: 1`；Host 半边不碰 git 凭据、不碰 API Key，只是代跑 `sync.sh`
- 隔离测试：客户端半边 10 项（假 React/假 ctx 跑 `apply`）、Host 半边 17 项（真机跑真实 `.dsh-cloud`）

**Windows 桌面控制台**

- `outputs/同步控制台.bat` + 桌面快捷方式「dsh 同步」：状态、立即提交、暂停/恢复、
  切模式、折叠窗口开关、看日志 —— 不用开终端（.bat 内容是纯 ASCII，避免中文变 `????`）

**其他**

- 控制面在哪写进了 [docs/auto-sync.md](docs/auto-sync.md)（命令 / `sync.conf` / 日志 / 面板）
- 修正一处文档错误：`sync.conf` 在持久卷上，**不在仓库里**，换电脑要重设

## [1.2.4] - 2026-09-29

- **重跑安装器后会重建同步守护进程**：`sync.sh` / `start.sh` 是被覆盖重写的，
  而正在运行的那个 `bash` 可能还停在旧文件的字节偏移上。现在重写脚本后先停掉旧进程，
  再由 `start.sh` 拉起新的（真机上重复安装三次才暴露出来的）
- 顺带：安装器输出的"配置自动同步"一节会告诉你它保留了已有的 `sync.conf`

## [1.2.3] - 2026-09-29

两个"重复跑安装器"时才暴露的问题。

- **不再覆盖你调过的 `sync.conf`**：以前重跑安装器会把 `mode` / `squash_window_seconds`
  这些设置重置回默认值。现在只在文件不存在时生成，已有的原样保留
  （README 里"重跑只刷新脚本、不动你的设置"这句这才算数）
- **折叠失败不再卡住**：`git commit --amend` 失败（比如净改动为空的边界情况）时，
  以前会当成"折叠成功"继续，改动可能一直提交不上去。现在失败就退回正常新增提交

## [1.2.2] - 2026-09-29

`tools/squash-autosync.sh` 换掉了 rebase 方案 —— 在真实仓库上它直接失败了。

- **现象**：`fixup` 折叠时，如果某条提交刚好把上一条抵消（加一行 / 立刻删一行），
  中间态变成空提交，`git commit --amend` 报 *"would make it empty"*，rebase 停下
- **改法**：按"段"重放。每段连续自动提交用「该段最后一条的 tree」建一条新提交，
  其余提交原样重建；没有 rebase 就没有中间态空提交这回事
- 整段净改动为 0 → 整段跳过（不留空提交）
- 重建后强制校验 **最终文件树 == 原 HEAD 的 tree**，不一致就中止、不推送
- 回归测试补齐：加一行/删一行、整段净零、落单自动提交、手工提交原样保留
  （隔离测试 13/13，最终 tree 逐字节相同）

## [1.2.1] - 2026-09-29

文件名里带特殊字符（空格、引号、非 ASCII）时，`git` 会把路径**加引号转义**输出，
结果这些引号被写进了提交信息（真实的仓库里就抓到了这个：`dsh: update "tools/dsh-cloud,…`）。

- `sync.sh` 生成提交信息、组织正文时改用 `-z` 输出再转换，不再受 git 引号影响
- `tools/squash-autosync.sh` 的预览与合并信息同样处理

## [1.2.0] - 2026-09-29

两件关于"历史别太碎"的事。

**1. `sync.sh --squash-window=秒`（折叠窗口）**

- 上一条提交也是自动提交、且在这段时间内 → 新改动**并进上一条**，而不是新开一条
- 默认 `0`（关闭，不重写历史）；开启后用 `push --force-with-lease`，被别人顶掉时
  自动退回"正常新增一条提交"，不会丢改动
- 老版本 `sync.conf` 里没有这个键也能用：`--squash-window=1800` 会自动把键补进配置

**2. `tools/squash-autosync.sh`（整理旧历史）**

把过去那些连续的 `auto-sync` 提交合并成一条，手工提交原样保留：

```bash
bash tools/squash-autosync.sh                 # 默认只预览
bash tools/squash-autosync.sh --apply --push  # 改历史 + force-with-lease 推送
```

- 只合并**连续段**（≥2 条），落单的自动提交不动
- 合并后信息按改动内容重新生成，例如 `dsh: update projects/x, notes (23 files) — 合并 9 次自动同步`
- 默认先建备份分支 `backup/pre-squash-<时间戳>`；有 merge 提交时直接拒绝
- 隔离测试验过：合并后**最终文件树逐字节不变**（同一次测试里还校验了手工提交、备份分支）

## [1.1.1] - 2026-09-29

一个真机跑出来的安装器问题 + 一个顺手升级问题。

- **不再"顺手升级" dsh**：原来只按 PATH 判断有没有装过，而 Codespaces 里 dsh 常常在
  `~/.nvm/versions/node/v22.x.y/bin/`，非交互 SSH 的 PATH 里没有它 —— 结果安装器又装了一份新版。
  现在优先**沿用正在运行的那个 dsh 的运行时**，其次在常见 nvm 前缀里找已装好的，
  真的没有才安装。实测：从"又装了一个 0.2.0-rc.2"变成"沿用它原来的 0.1.7-rc.2"。
- **deploy key 能自动登记了**：非交互 SSH 会话里 `gh` 没登录，登记必然失败。
  现在会从 `/workspaces/.codespaces/shared/.env` 读 Codespace 自带的平台令牌，
  只 export 到环境变量（不打印、不落盘）后调用 API；仍然失败才提示你手动加。

## [1.1.0] - 2026-09-29

自动同步从"每 5 分钟一个 `auto sync`"改成**智能批量**。

**新行为**

- 默认 `idle` 模式：改动停下来 `idle_seconds`（默认 600 秒）之后才提交一次；
  一直有人改也会在 `max_wait`（默认 1800 秒）后兜底提交，不会整天不提交
- 提交信息自动生成，例如 `dsh: update projects/plugincreate (12 files)`，
  正文列出改动文件；AI 或人也可以用 `.dsh-cloud/commit-msg` 指定一次提交信息
- 三种模式可切换：`idle`（智能批量）/ `interval`（固定周期，旧行为）/ `manual`（只手动）
- `sync.sh --status / --plan / --now / --enable / --disable` 是新的控制面；
  配置在 `.dsh-cloud/sync.conf`（跟着仓库走，换电脑也一样）
- push 被拒时自动 `pull --rebase` 重试一次，失败就留到下一轮，不丢改动

细节见 [docs/auto-sync.md](docs/auto-sync.md)。

## [1.0.0] - 2026-09-29

第一个正式版本：把"照着文档手搓"变成"跑一个脚本"。

**一键安装**

- `install/cloud-setup.sh` —— 云端 8 步流水线：检查 GitHub CLI → 检查 Codespace → 检查 Node →
  安装 dsh → 配置 workspace → 生成 deploy key → 配置自动同步 → 验证，
  幂等、支持 `--dry-run`，结束打印 `✅ Installation complete`
- `install/setup.ps1`（Windows）/ `install/setup.sh`（macOS、Linux）—— 本机侧：
  便携版 gh → 一次浏览器授权 → 选取或新建 Codespace → 把云端脚本送进容器执行 →
  建隧道验证 → 放桌面启动器
- 三个云端脚本（`start.sh` / `update.sh` / `sync.sh`）改由 `cloud-setup.sh` 生成，
  带 Node 路径与仓库信息，容器重建后重跑一次即可

**文档结构**

- 主 README 从 514 行压到 187 行，只回答"我要做哪几步"
- 拆出 `docs/`：任务书、技术细节、云端脚本、插件、macOS/Linux、目录结构
- 新增 `docs/troubleshooting/`：按 Windows / SSH / Codespaces / dsh 分类，
  每个坑都写成「现象 → 原因 → 解法」

**其他**

- 新增版本号（本文件 + `VERSION`）
- 仓库结构与许可说明整理进 README 末尾
