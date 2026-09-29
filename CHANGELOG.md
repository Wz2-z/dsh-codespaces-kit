# 更新日志

版本号规则：`MAJOR.MINOR.PATCH`（[语义化版本](https://semver.org/lang/zh-CN/)）。
发新版时改三处：本文件、[`VERSION`](VERSION)、`install/setup.ps1` 与 `install/setup.sh` 里的 `KIT_VERSION`。

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
