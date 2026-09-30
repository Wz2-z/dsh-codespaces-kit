# 更新日志

版本号规则：`MAJOR.MINOR.PATCH`（[语义化版本](https://semver.org/lang/zh-CN/)）。
发新版时改三处：本文件、[`VERSION`](VERSION)、`install/` 下所有脚本里的版本串
（`KIT_VERSION` / `$KitVersion` / `console.ps1` 的 `$Version`）。

## [1.7.2] - 2026-09-30

管理台进安装器 + 文档追上 v1.7.0 / v1.7.1 已经上线的功能。

**安装器（Windows）**：`setup.ps1` 现在把管理台一起装好，装完就和手动配好的一样 ——
桌面两个快捷方式「DeepSeek Harness」+「dsh 管理台」。

- `%LOCALAPPDATA%\dsh-cloud\` 里多放 8 个文件：`console.ps1`（管理台）、`console.bat`（启动器）
  以及它调用的 `status.ps1` / `doctor.ps1` / `audit.ps1` / `update.ps1` / `uninstall.ps1` / `cloud-setup.sh`
  （管理台按同目录找这些脚本，所以必须放一起）
- 取文件的顺序：本地这份 `install\` 里有就直接拷（clone 下来跑的场合），只有一份 `setup.ps1` 时
  按 `raw.githubusercontent` 取；某一个没拿到就 `!` 提示并在桌面回退成原来的「更新 dsh」，
  下次重跑 `setup.ps1` 会补上（不会留一个点不开的快捷方式）
- 桌面快捷方式从「DeepSeek Harness」+「更新 dsh」改成 **「DeepSeek Harness」+「dsh 管理台」**；
  老机器上已有的「更新 dsh」快捷方式不动（doctor 两个都认）
- 顺手：`%LOCALAPPDATA%\dsh-cloud\icons\dsh.ico` 存在时，快捷方式会带上这个图标
  （仓库里不带图标文件，保持 MIT/CC 的干净）

**文档**：

- README（中文 / 英文）与 `install/README.md` 的版本号更到 **`v1.7.2`**（之前还停在 v1.7.0 / 1.0.0），
  `status` 示例里的版本号一并更新
- 把仓库自带的 **Windows 管理台**（`install/console.ps1` + `console.bat`）写进文档：
  主 README 补了菜单清单和日常入口，`docs/lifecycle.md` / `docs/en/lifecycle.md` 加了命令对照，
  `install/README.md` 补了用法、行为和 `-Action` / `-Lang` 参数
- `-Lang zh|en`（v1.7.0 加的）补进 `docs/doctor.md` / `docs/en/doctor.md` 的参数表和
  lifecycle 的参数说明
- doctor 的 Launcher 一项改成现在的判定：**启动入口 + 维护入口（`dsh 管理台` 或 `更新 dsh`）**，
  并且会检查快捷方式指向的脚本还在不在（v1.4.2 的行为，文档这次才对齐）
- 清掉过期的路径引用：`docs/auto-sync.md` 的「桌面快捷方式 dsh 同步 / `outputs/同步控制台.bat`」
  改成管理台 `[4] 自动同步`；`docs/directory-layout.md` 的本机布局改成 `%LOCALAPPDATA%\dsh-cloud\`；
  `docs/security-model.md` / `docs/en/security-model.md` 里的 `outputs\` 一并更正
- `install/README.md` 顶部版本号从 `1.0.0` 更正为当前版本；发版清单改成
  "`install/` 下所有脚本里的版本串（`KIT_VERSION` / `$KitVersion` / `console.ps1` 的 `$Version`）都要改"
- **管理台修一处硬编码**：`install/console.ps1` 里的 `$CloudDir` 原来写死成作者的仓库路径，
  现在默认按 Codespace 所属仓库名推 `/workspaces/<repo>/.dsh-cloud`（`gh codespace list
  --json name,repository`），推不出来会去容器里 `ls -d /workspaces/*/.dsh-cloud` 找一次；
  也可以用新的 `-CloudDir` 参数手动指定。找不到时「打开 dsh」「自动同步」会打印一句提示而不是静默失败
  —— 换别人的仓库名也能直接用管理台

## [1.7.1] - 2026-09-29

修一个我自己引入的启动器 bug（v1.7.0 里）：

- `install/console.bat` 只会找同目录的 `console.ps1`，而旧机器上那份叫 `dsh-console.ps1`，
  于是双击报 *The argument ... console.ps1 to the -File parameter does not exist*
- 现在按 `console.ps1` → `dsh-console.ps1` 的顺序找，两个名字都能用；
  两个都找不到时打印"把 kit 的 `install/console.ps1` 拷到同目录"并停下来，而不是抛一段 PowerShell 报错
- 你机器上现在是这样：`outputs\console.ps1`（真正的面板）+ `outputs\dsh-console.bat`（启动器，
  桌面快捷方式指的就是它）

## [1.7.0] - 2026-09-29

控制台双语 + 版本号修正。

- **管理台支持中文 / English 切换**：菜单里多了一项 `[E] 语言 / language`，
  选完立即换界面并记住选择（存在同目录的 `.console-lang`）；
  面板顶部、菜单、子菜单、确认提示都会跟着切换
- `status` / `doctor` / `audit` 都新增 `-Lang zh|en`（默认 `zh`），控制台会把选择透传下去：
  `status` 的标签、状态词、时间（"32 秒前" / "32 seconds ago"）都会跟着变；
  `audit` 连云端那份清单也会切成英文（`cloud-audit.sh --lang=en`）
- 控制台本身做成 kit 的一部分：`install/console.ps1` + `install/console.bat`，
  自动找 `%LOCALAPPDATA%\dsh-cloud` 或仓库旁的 `<base>\gh\bin\gh.exe`，别人装完也能直接用同款面板
- 修正中文 README 顶部一直没更新的版本号（还写着 v1.0.0，改成 v1.7.0），
  文档里的 `status` 示例版本号也一并更新

## [1.6.0] - 2026-09-29

英文版 + 文档站（GitHub Pages）。

- **英文文档全套**：`README.en.md` + `docs/en/`（index / doctor / lifecycle / security-model /
  auto-sync / plugins / troubleshooting / ai-prompt / ai-runbook / macos-linux / directory-layout /
  cloud-scripts），中文文档顶部都加了 `English version` 链接
- **GitHub Pages**：<https://wz2-z.github.io/dsh-codespaces-kit/>（中文首页）
  与 <https://wz2-z.github.io/dsh-codespaces-kit/en/>（English）
  —— `docs/_config.yml` 里启用 `jekyll-relative-links`，文档之间的相对链接在网页上也能点
- 中文 `docs/` 与英文 `docs/en/` 保持同样的结构，方便对照

## [1.5.1] - 2026-09-29

界面统一成"框线 + 颜色"的一套观感（Windows 控制台里也正常，不需要 Windows Terminal）：

- `status` 顶部加了框线标题（版本 + Codespace），下面每行左边一条竖线，
  状态列按**显示宽度**对齐（中文算两格，不再错位）；时间改成本地化的"39 分钟前"
- 本机的管理台改成用 PowerShell 画界面（`dsh-console.ps1`），菜单项同样按显示宽度对齐，
  `.bat` 只留一行启动器 —— 也顺手避开了 `.bat` 里 CRLF / `chcp` 那两个坑
- `status` / `doctor` / `audit` 三份输出的状态色统一：绿=好、黄=要留意、红=坏了

## [1.5.0] - 2026-09-29

补齐生命周期 + 安全清单 + 统一可观测性。

**生命周期**（`install/dsh-codespaces.bat` / `.sh` 一个入口）：

```
status  doctor  audit  setup  repair  update  uninstall
```

- **status**：一屏看清 `Codespace / Tunnel / DSH / Auto sync / Last check / Last push /
  Last commit / Pending files / In sync`；`-Quick` 跳过隧道检查
- **audit**：凭据与权限清单（本机 + 云端），只报"有什么、在哪、能干什么"，**不打印任何密钥内容**
- **repair**：= 重跑一遍幂等的安装 + 再体检；不会覆盖你改过的 `sync.conf`
- **update**：升级云端 dsh 并重建隧道（Windows 版顺便打开浏览器）
- **uninstall**：默认**只预览**；`-Yes` + `-Local/-Cloud/-PurgeLocal/-PurgeCloud/
  -RevokeDeployKey/-DeleteCodespace` 指定范围才动手，并且明确说"不会动什么"
  （GitHub 登录、仓库内容、DeepSeek API Key）

**安全模型**：[docs/security-model.md](docs/security-model.md) 把每个 key/token/config 的
位置、能力、撤销方式列成一张表；[docs/lifecycle.md](docs/lifecycle.md) 写清什么时候用哪个命令。

**云端脚本**：`cloud-status.sh` / `cloud-audit.sh` / `cloud-uninstall.sh` 三个只读（或需 `--yes`）
的小脚本，由本机命令通过 stdin 送进容器执行。

## [1.4.2] - 2026-09-29

`doctor` 的 Launcher 那一项太死板：只认 `更新 dsh.lnk`，所以把「更新 / 同步 / 体检」
合并成一个「dsh 管理台」之后，它报 *只有 DeepSeek Harness，缺 更新 dsh*。

- 启动入口仍必须有；维护入口改成 **`dsh 管理台` 或 `更新 dsh` 任一即可**
  （`dsh 同步` / `dsh 体检` 算可选项）
- 新增：解析每个快捷方式的 `TargetPath`，**指向的 .bat 不在了就报 warn**（挪过目录会撞上）

## [1.4.1] - 2026-09-29

Windows 启动器上的两个真实事故（都在用的时候撞出来的）：

- **`.bat` 里的 `goto` 找不到标签**：批处理写成 LF 行尾时，`goto 标签` 会报
  *"The system cannot find the batch label specified"*。生成的 `.bat` 一律写成 **CRLF**。
- **中文输出变 `妯″紡锛歩dle`**：容器输出是 UTF-8，中文 Windows 控制台默认 936。
  `dsh-codespaces.bat` / 桌面控制台开头都加 `chcp 65001 >nul`；`.ps1` 存成带 BOM 的 UTF-8。
- 这两条写进 [docs/doctor.md](docs/doctor.md)，自己写启动器时能少踩一次。

## [1.4.0] - 2026-09-29

**`dsh-codespaces doctor` 成为核心命令**：一条命令看清整条链路。

- `install/doctor.ps1`（Windows）/ `install/doctor.sh`（macOS、Linux）= 本机侧，
  加上 `install/cloud-doctor.sh`（送进容器跑）= 云端侧，合成 12 行表格：
  GitHub CLI / GitHub authentication / Codespace / DSH / SSH key / Workspace /
  Deploy key / Auto sync / Sync config / dsh web / Tunnel / Launcher
- 三档状态：`✓` 正常、`!` 警告（能用但值得看一眼）、`✗` 坏了；有 `✗` 时退出码 1
- `install/dsh-codespaces.bat` / `install/dsh-codespaces.sh` 作为统一入口：
  `dsh-codespaces doctor` / `dsh-codespaces setup`
- 只读检查（隧道那一项临时开一次端口转发，查完就关）；`-NoTunnel` 跳过，`-Json` 给脚本用
- 踩到的两个细节：PowerShell 5.1 管道会把脚本按 ASCII 重编码（中文变 `?`），
  改成用 `cmd <` 直接喂文件；`gh` 连不上网时也会报 "token invalid"，现在区分开
- README 的成本措辞改成："在账户自带的 Codespaces 额度内可零额外费用运行，超出额度可能产生费用"
- 细节见 [docs/doctor.md](docs/doctor.md)

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
