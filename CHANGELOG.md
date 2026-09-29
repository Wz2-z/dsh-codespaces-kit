# 更新日志

版本号规则：`MAJOR.MINOR.PATCH`（[语义化版本](https://semver.org/lang/zh-CN/)）。
发新版时改三处：本文件、[`VERSION`](VERSION)、`install/setup.ps1` 与 `install/setup.sh` 里的 `KIT_VERSION`。

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
