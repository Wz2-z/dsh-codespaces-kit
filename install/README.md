# 一键安装

> [← 回到 README](../README.md) · 版本：[`1.0.0`](../CHANGELOG.md)

对应 README 里的**路线 A**。两个入口，选一个：

| 你在哪 | 用什么 | 干什么 |
| --- | --- | --- |
| 本机（Windows） | `setup.ps1` | 便携版 gh → 授权 → 选/建 Codespace → 驱动云端 → 建隧道 → 桌面启动器 |
| 本机（macOS / Linux） | `setup.sh` | 同上（用系统里已装的 gh） |
| Codespaces 容器里 | `cloud-setup.sh` | 8 步流水线：Node → dsh → workspace → deploy key → sync → 验证 |

装完（或任何时候）可以体检：

```
Windows           powershell -ExecutionPolicy Bypass -File doctor.ps1
macOS / Linux     ./dsh-codespaces.sh doctor     # 或 bash doctor.sh
```

## 本机一键（推荐）

**Windows**（普通用户权限，不需要管理员）：

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

两个脚本都支持 `--dry-run`：只检查、只打印，不写文件、不改配置。

## 只装云端（Codespace 已经建好）

在 Codespaces 的终端里：

```bash
curl -fsSL https://raw.githubusercontent.com/Wz2-z/dsh-codespaces-kit/main/install/cloud-setup.sh -o ~/cloud-setup.sh
bash ~/cloud-setup.sh --dry-run    # 先看它打算做什么
bash ~/cloud-setup.sh              # 真正执行
```

也可以用 `curl … | bash` 的写法，但**先存下来看一眼再跑**更稳妥 —— 这个脚本会：

- 往 `~/.ssh/` 写一把新密钥，并把公钥登记成**只对一个仓库可写**的 deploy key
- 往 `/workspaces/<repo>/.dsh-cloud/` 写 `start.sh` / `update.sh` / `sync.sh` / `sync.conf`
- 拉起 dsh 和同步守护进程，并做一次 `sync --now`

它**不会**碰你的 `~/.dsh/.credentials.yaml`（API Key）、不会改本机任何设置；
`~/.dsh/profiles/web/cordis.patch.yml` 里的权限预设也只在缺失时补，不会覆盖你改过的值。

## 流水线

```
[1/8] 检查 GitHub CLI        没有就下便携版（Windows）/ 提示怎么装（macOS、Linux）
[2/8] 检查 Codespace         没有就按 -Repo / --repo 建一个
[3/8] 检查 Node              需要 22+，缺了就用 nvm 装
[4/8] 安装 dsh               npm install -g @deepseek-ai/dsh
[5/8] 配置 workspace         ~/dsh-workspace = 你仓库的克隆
[6/8] 生成 deploy key        只对这一仓库可写，并登记到 Deploy keys
[7/8] 配置 sync              .dsh-cloud/{start,update,sync}.sh + sync.conf（默认智能批量）
[8/8] 验证                   3080 返回 401、HEAD == 远端、打印带 token 的地址
                             → ✅ Installation complete
```

任何一步失败都会停下并打印 `✗ 原因`，把那一行上面几行贴给 AI 就能接着修。

## 它是幂等的

- 已经装过 dsh / 已经 clone 过工作区 / 已经有 deploy key：跳过，不重复动作
- 重跑只会把 `.dsh-cloud/` 三个脚本刷新成最新版本（当前正在跑的 dsh 不会被重启）
- 容器重建（`$HOME` 被清空）之后，在容器里重跑一次 `cloud-setup.sh` 就能恢复
  —— 脚本和同步逻辑都在持久卷 `/workspaces` 里，仓库内容在远端

## 发新版时

1. 改 [`VERSION`](../VERSION) 和本目录两个脚本里的 `KIT_VERSION`
2. 在 [`CHANGELOG.md`](../CHANGELOG.md) 顶部加一节
3. 打 tag：`git tag -a v1.0.1 -m "v1.0.1" && git push origin v1.0.1`
