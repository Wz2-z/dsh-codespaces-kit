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

## 配置在哪

`.dsh-cloud/sync.conf` —— **在工作区里**，所以它跟着仓库走（换电脑、重建容器都还在）：

```ini
enabled=on
mode=idle
idle_seconds=600
max_wait=1800
interval=300
tick=30
prefix=dsh
```

改完不用重启，守护进程每 `tick` 秒重读一次。

## 会不会丢东西

- `max_wait` 保证"一直在改"也不会超过 30 分钟没提交
- push 被别人顶掉时，会自动 `pull --rebase` 再推一次；仍然失败就把改动留在工作区，下一轮重试
- 真正的兜底还是**远端仓库**：`~/dsh-workspace` 只是克隆，`/workspaces` 是持久卷

---

[← 回到 README](../README.md)
