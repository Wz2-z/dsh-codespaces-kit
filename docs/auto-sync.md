# 自动同步（智能批量）

> [← 回到 README](../README.md) · 相关：[云端三个脚本](cloud-scripts.md) · [dsh 排错](troubleshooting/dsh.md)

云端会把工作区的改动 **commit + push** 到你的私有仓库。默认不是"每 5 分钟一个 `auto sync`"，
而是**等改动停下来**再提交一次 —— 所以 history 里是一条条能看懂的提交，而不是一堵墙。

## 默认行为

| 设置 | 默认值 | 意思 |
| --- | --- | --- |
| `enabled` | `on` | 自动同步总开关 |
| `mode` | `idle` | 智能批量 |
| `idle_seconds` | `600` | 静默 10 分钟没有新改动 → 提交一次 |
| `max_wait` | `1800` | 就算一直在改，最多 30 分钟也兜底提交一次 |
| `tick` | `30` | 守护进程每 30 秒看一次 |
| `prefix` | `dsh` | 自动提交信息的前缀 |
| `squash_window_seconds` | `0` | 折叠窗口（默认关闭，见下文） |

```
改 改 改 II 改 改 改        ← AI 一直在改
            └────────────┘  静默 10 分钟
                        ↓
                  一次 commit（信息由改动内容生成）
```

## 提交信息长什么样

自动生成格式：`前缀: 动作 目录 (文件数)`

| 情况 | 提交信息 |
| --- | --- |
| 改了 `projects/plugincreate` 里 12 个文件 | `dsh: update projects/plugincreate (12 files)` |
| 只新增文件 | `dsh: add notes (3 files)` |
| 只删文件 | `dsh: remove tools/old (2 files)` |

正文（`git log` 里第二段）会列出具体文件名，`git log --oneline` 只看到上面那一行。

**想让信息更贴切**，两个办法：

1. **让 AI 自己写**（推荐）：在仓库根的 `AGENTS.md` 里加一段——

   ```markdown
   ## 收尾
   每完成一个任务，把这次改动的提交信息写到 `.dsh-cloud/commit-msg`
   （一行，例如 `feat: 面板加额度进度条`），然后正常结束。
   自动同步会用它作为 commit message。
   ```

2. **手动指定下一次**：`bash .dsh-cloud/sync.sh --message="fix: 修掉登录 401"`

## 三种模式

| 模式 | 什么时候提交 | 适合谁 |
| --- | --- | --- |
| `idle`（默认） | 静默 `idle_seconds` 之后 | 绝大多数人 |
| `interval` | 每 `interval` 秒一次 | 想要固定心跳、不介意 history 里多一些自动提交 |
| `manual` | 只有你跑 `--now` 才提交 | 想自己控制每一次提交 |

切换（写回 `sync.conf`，重启容器也保留）：

```bash
bash /workspaces/<repo>/.dsh-cloud/sync.sh --mode=interval --interval=300
bash /workspaces/<repo>/.dsh-cloud/sync.sh --mode=idle --idle=600
bash /workspaces/<repo>/.dsh-cloud/sync.sh --mode=manual
```

## 常用命令

| 想做什么 | 命令 |
| --- | --- |
| 看当前模式 / 有没有待提交 | `bash .dsh-cloud/sync.sh --status` |
| 只看"会提交什么、信息是什么"（不动 git） | `bash .dsh-cloud/sync.sh --plan` |
| 立刻提交一次 | `bash .dsh-cloud/sync.sh --now` |
| 暂停自动同步（改动仍留在工作区） | `bash .dsh-cloud/sync.sh --disable` |
| 重新打开 | `bash .dsh-cloud/sync.sh --enable` |
| 看最近同步了什么 | `tail -n 20 ~/dsh-sync.log` |

## 控制面在哪

三种看法，随便挑一个：

1. **dsh 侧边栏的同步按钮**（装了 [`dsh-sync-panel`](../plugins/dsh-sync-panel/) 就有）——
   点开就是模式、待提交、最近提交、日志，外加暂停/恢复/立即提交/切模式；
2. **Windows 桌面快捷方式「dsh 同步」**（`outputs/同步控制台.bat`）—— 菜单式，不用开终端；
3. **命令行**（最全，容器里的 `sync.sh`）。

命令行里的东西：

| 想看什么 | 在哪 |
| --- | --- |
| 模式 / 待提交 / 最近提交 | 容器里执行 `bash .dsh-cloud/sync.sh --status` |
| 所有可调参数 | `/workspaces/<仓库名>/.dsh-cloud/sync.conf` |
| 每次同步到底干了什么 | `~/dsh-sync.log`（`pushed` / `folded` / `skipped` / `FAILED`） |
| dsh 自己的日志 | `~/dsh-web.log`（启动）、`~/dsh-update.log`（升级） |

**怎么进这个终端**，两条路：

1. GitHub → <https://github.com/codespaces> → 打开你的 Codespace（浏览器里的 VS Code）→ Terminal；
2. 或者在你自己的电脑上（Windows，用安装器放的便携版 gh）：

```bat
"%LOCALAPPDATA%\dsh-cloud\gh\bin\gh.exe" codespace ssh -c <codespace 名> ^
  -- -i "%USERPROFILE%\.ssh\dsh_cs_key" "bash /workspaces/<仓库名>/.dsh-cloud/sync.sh --status"
```

## 配置在哪

`/workspaces/<仓库名>/.dsh-cloud/sync.conf`，在 **Codespaces 的持久卷**上：
容器重建（`$HOME` 被清空）它也还在，但它**不在你的仓库里** —— 换电脑或删掉 Codespace
就没了，重新跑一次 `install/cloud-setup.sh` 会生成默认值，再用 `--mode=` / `--squash-window=`
设一遍即可（安装器不会覆盖你已经改过的 `sync.conf`）。

```ini
enabled=on
mode=idle
idle_seconds=600
max_wait=1800
interval=300
tick=30
prefix=dsh
squash_window_seconds=0
```

改完不用重启，守护进程每 `tick` 秒重读一次。

## 折叠窗口（可选）：同一批改动只留一条提交

把 `squash_window_seconds` 设成正数（比如 `1800`）之后：如果**上一条提交也是自动提交**、
且它在窗口时间内，新改动会**并进那一条**，而不是又开一条。

```bash
bash .dsh-cloud/sync.sh --squash-window=1800    # 30 分钟内的工作算一批
bash .dsh-cloud/sync.sh --squash-window=0       # 关掉（默认）
```

代价：**会改写历史**，所以推送用的是 `push --force-with-lease`。
如果远端被别的电脑推过（lease 不匹配），它会自动退回"新增一条提交"，不会丢东西。
多台电脑同时用同一个仓库时，建议保持关闭。

## 整理旧历史

以前跑过老版本（每 5 分钟一条 `auto-sync`）的话，可以用仓库里的工具把那些提交合并掉：

```bash
bash tools/squash-autosync.sh                   # 先预览会怎么合并
bash tools/squash-autosync.sh --apply           # 本地改历史（自动建备份分支）
bash tools/squash-autosync.sh --apply --push    # 顺便 force-with-lease 推上去
```

只合并**连续**的自动提交，手工写的提交原样保留；合并后的信息会按改动内容重新生成。

## 会不会丢东西

- `max_wait` 保证"一直在改"也不会超过 30 分钟没提交
- push 被别人顶掉时，会自动 `pull --rebase` 再推一次；仍然失败就把改动留在工作区，下一轮重试
- 折叠窗口推送失败时退回正常提交（改动不丢）
- 真正的兜底还是**远端仓库**：`~/dsh-workspace` 只是克隆，`/workspaces` 是持久卷

---

[← 回到 README](../README.md)
