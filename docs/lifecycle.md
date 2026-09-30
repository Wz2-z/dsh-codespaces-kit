# 生命周期：status / doctor / setup / repair / update / uninstall

> [English version](en/lifecycle.md)

> [← 回到 README](https://github.com/Wz2-z/dsh-codespaces-kit/blob/main/README.md) · 相关：[安全模型](security-model.md) · [自动同步](auto-sync.md)

```
dsh-codespaces status      一眼看清现在（几秒，不查隧道时最快）
dsh-codespaces doctor      12 项体检：本机 + 云端
dsh-codespaces audit       凭据 / 权限清单：有什么、能干什么、怎么撤销
dsh-codespaces setup       第一次安装（幂等，重复跑只补缺的）
dsh-codespaces repair      = setup + doctor（缺什么补什么，然后复查）
dsh-codespaces update      升级云端 dsh 并重建隧道
dsh-codespaces uninstall   卸载 / 撤销（默认只预览）
```

Windows 用 `install\dsh-codespaces.bat <命令>`，macOS/Linux 用 `install/dsh-codespaces.sh <命令>`；
参数会原样传给对应的 `*.ps1` / `*.sh`。

Windows 上还有一份图形化的**管理台**（`console.ps1` + `console.bat`），把这些命令做成了菜单：
`[1]` 打开 dsh / `[2]` 状态 / `[3]` 体检 / `[4]` 自动同步 / `[5]` 更新 dsh / `[A]` 权限清单 /
`[R]` 修复 / `[U]` 卸载 / `[L]` 同步日志，`[E]` 切中文 / English。
`setup.ps1` 会把它连同它调用的脚本一起装进 `%LOCALAPPDATA%\dsh-cloud\` 并建「dsh 管理台」快捷方式；
在 clone 下来的仓库里双击 `install\console.bat` 是同一个界面。

## 什么时候用哪个

| 情况 | 用哪个 |
| --- | --- |
| 刚装完，想知道是不是都好了 | `doctor` |
| 日常看一眼：同步在不在跑、上次推到什么时候 | `status` |
| 担心"它到底拿了我什么权限" | `audit` |
| 新电脑 / 新容器 | `setup` |
| 某天突然连不上、同步停了 | `repair`（先补再查），不行再 `doctor` 看具体哪项坏了 |
| dsh 出新版本 | `update` |
| 不想用了 | `uninstall` |

## `status` 长什么样

```
╭──────────────────────────────────────────────────────────────────╮
│ dsh-codespaces status                                     v1.7.2 │
│ codespace                     your-codespace-name-here-gxq9gv9gx │
╰──────────────────────────────────────────────────────────────────╯

│ Codespace   Running   your-codespace…（Available）
│ Tunnel      Healthy   127.0.0.1:3080 → 401（需要 token，正常）
│ DSH         Healthy   0.1.7-rc.2 · pid 62857 · HTTP 401
│ Auto sync   Running   idle · on · daemon pid 90277 · 静默 600s · 折叠 1800s
│ Last check            32 秒前
│ Last push             1 分钟前 · dsh: add projects/plugincreate (6 files)
│ Last commit           19a6c79 · 12 分钟前 · dsh: add projects/plugincreate (6 files)
│ Pending files           0
│ In sync               yes（本地 19a6c79 / 远端 19a6c79）
```

几个状态词的意思：

- `Healthy` 隧道通、dsh 需要 token（401 正常）；`Down` 完全连不上；`Degraded` 通但不太对（比如 dsh 放行了无 token 请求）
- `Running` 同步守护进程在跑且没暂停；`Paused` 跑着但 `enabled=off`；`Stopped` 没在跑
- `Last check` 是同步守护进程**最后一次活动**的时间（不是"检查过没变化"的精确时间，够用）
- `Last push` 取自 `~/dsh-sync.log` 里最后一次 `pushed` / `folded`

`--quick`（bash）/ `-Quick`（PowerShell）跳过隧道检查，1～2 秒出结果；`--json` / `-Json` 给脚本用；
`-Lang zh|en`（Windows 的 `status` / `doctor` / `audit`，默认 `zh`）切换输出语言。

## `repair` 做什么

就是**再跑一遍安装器**（它是幂等的）然后跑一次体检：

1. 本机：缺便携版 gh 就补，缺桌面启动器就重建（已经有的不动）
2. 云端：缺 dsh 就装，工作区不在就 clone，缺 deploy key 就生成，`.dsh-cloud` 脚本缺失或被改坏就重写，
   同步守护进程没跑就拉起；**不会覆盖你改过的 `sync.conf`**
3. 收尾：跑一次 `doctor` 告诉你现在几项通过

所以"哪里不对先 repair 一下"基本能解决大部分问题；剩下看 `doctor` 的 `✗` 那一行。

## `uninstall` 的范围

默认只预览。要执行得同时给 `-Yes` 和范围开关：

| 开关 | 作用 |
| --- | --- |
| `-Local` / `--local` | 删桌面快捷方式（以及 `-PurgeLocal` 时的便携版 gh + SSH 私钥） |
| `-Cloud` / `--cloud` | 停同步守护进程与 dsh web（`-PurgeCloud` 时删 `.dsh-cloud`） |
| `-RevokeDeployKey` | 从仓库撤销 deploy key（平台令牌常常没权限，会告诉你去网页删） |
| `-DeleteCodespace` | 删除整个 Codespace（**不可恢复**） |

它**永远不会自动动**：你的 GitHub 登录、仓库内容、DeepSeek API Key（删 Codespace 才没）。
