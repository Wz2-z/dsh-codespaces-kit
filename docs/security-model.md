# 安装安全模型：这套工具到底创建了什么

> [English version](en/security-model.md)

> [← 回到 README](https://github.com/Wz2-z/dsh-codespaces-kit/blob/main/README.md) · 相关：[生命周期](lifecycle.md) · [doctor](doctor.md)

一句话：**没有账号级 PAT、没有 GitHub App、没有云厂商账号、没有 sudo 改动。**
它只在你本机放了两个东西（便携版 gh + 一把 SSH 私钥），在容器里放了一把
只对一个仓库可写的 deploy key，别的都在 GitHub 自己的机制里。

随时可以看当前实际情况：

```
dsh-codespaces audit        # 凭据 / 权限清单（不显示任何密钥内容）
dsh-codespaces audit -Json  # 给脚本用
```

## 创建了什么

| 东西 | 在哪 | 能干什么 | 怎么撤销 |
| --- | --- | --- | --- |
| **便携版 GitHub CLI** | 本机 `%LOCALAPPDATA%\dsh-cloud\gh\`（macOS/Linux 为 `~/.local/share/dsh-cloud`） | 一个可执行文件而已；不装到系统、不改 `PATH`、不要管理员 | 直接删目录（`dsh-codespaces uninstall -Yes -PurgeLocal`） |
| **GitHub 登录令牌** | 本机 gh 的配置目录（`ghconfig\hosts.yml`，**明文**） | 你在 GitHub 上能做的事它都能做：读写你的仓库、管理你的 Codespaces | `gh auth logout -h github.com`；或在 GitHub → Settings → Applications 里撤销该 token |
| **SSH 私钥** `dsh_cs_key` | 本机 `%USERPROFILE%\.ssh\` | **只能 SSH 登录你自己的 Codespace**；不能读写仓库、不能改 GitHub 设置 | 删本机两个文件；GitHub → Settings → SSH and GPG keys 里删掉对应公钥 |
| **deploy key** `dsh_deploy` | 容器 `~/.ssh/`，公钥登记在**你那个仓库**的 Deploy keys | **只对这一个仓库有写权限**（用来做自动同步）；碰不到你其它仓库 | 仓库 Settings → Deploy keys 删掉 `dsh-cloud-autosync`；或 `dsh-codespaces uninstall -Yes -Cloud -RevokeDeployKey` |
| **Codespaces 平台令牌** | 容器 `/workspaces/.codespaces/shared/.env`（GitHub 自己放的） | 容器里的 git/gh 用它访问你的仓库；**随容器销毁自动失效** | 不用你撤销；删掉 Codespace 就没了 |
| **DeepSeek API Key** | 容器 `~/.dsh/.credentials.yaml`（权限 0600） | 只有容器里的 dsh 用它调 DeepSeek；**不进仓库、不上传到别处** | 在 DeepSeek 控制台吊销该 key；文件随 Codespace 消失 |
| **同步配置** `.dsh-cloud/` | 容器 `/workspaces/<仓库>/.dsh-cloud/`（持久卷） | `start.sh` / `update.sh` / `sync.sh` / `sync.conf`，**不含任何凭据** | `dsh-codespaces uninstall -Yes -Cloud -PurgeCloud` |
| **桌面快捷方式 + `.bat`** | 本机桌面与 `%LOCALAPPDATA%\dsh-cloud\`（`start-dsh.bat` / `update-dsh.bat` / 管理台 `console.ps1` + `status`·`doctor`·`audit`·`update`·`uninstall`） | 只是启动器和菜单，里面**没有密钥**（只有路径和 Codespace 名字） | `dsh-codespaces uninstall -Yes -Local` |

## 没有创建什么

- ❌ 账号级 Personal Access Token（你看到的那个 PAT 只有 `dsh-codespace-panel` 面板在本地存一份，用来读额度，存在 dsh 的凭据存储里，不进仓库）
- ❌ GitHub App / OAuth App / 任何第三方授权
- ❌ 云厂商账号（AWS/GCP/腾讯云…），这里没有服务器，只有 GitHub Codespaces
- ❌ 系统级改动：不写系统目录、不动 `PATH`、不要管理员/root、不装全局软件（除了容器里的 Node 与 dsh）
- ❌ 你的仓库内容之外的任何数据：同步只推 `~/dsh-workspace` 那一个仓库

## 谁在哪儿看得到什么

| 位置 | 能看到 | 看不到 |
| --- | --- | --- |
| 你的本机 | 便携版 gh、gh 的登录令牌、SSH 私钥、桌面启动器 | DeepSeek API Key、deploy key 私钥 |
| Codespace 容器 | deploy key 私钥、DeepSeek API Key、平台令牌、`.dsh-cloud` 脚本 | 你本机的 SSH 私钥、本机 gh 的令牌 |
| 你的 GitHub 账号 | Codespaces、仓库里的 deploy key 公钥、gh 的授权记录 | DeepSeek API Key |
| 你的仓库（远端） | 你推进去的文件 | 任何密钥（除非你自己把它写进文件） |

## 风险与边界

- **agent 在容器里跑**：它能碰到容器里的一切，包括 `~/.dsh/.credentials.yaml`（DeepSeek Key）
  和 `~/.ssh/dsh_deploy`（只对一个仓库可写）。所以不要把别的凭据放进容器。
- **工作区里不要放密码**：`~/dsh-workspace` 里的东西都会被推到仓库。
- **插件等于宿主权限**：dsh 插件跑在同一个进程里，能读容器里的文件。装之前看清楚来源；
  不确定的先在 `read-only` 权限下试。
- **gh 的令牌是明文**：放在本机 `ghconfig/hosts.yml` 里。想更安全就改用系统钥匙串
  （`gh auth login` 时选 keyring），或者用完 `gh auth logout`。

## 撤销与卸载

```bash
dsh-codespaces uninstall                                  # 只看清单，什么也不做
dsh-codespaces uninstall -Yes -Local -Cloud               # 删快捷方式 + 停云端同步与 dsh
dsh-codespaces uninstall -Yes -Cloud -PurgeCloud -RevokeDeployKey
dsh-codespaces uninstall -Yes -Local -PurgeLocal -Cloud -DeleteCodespace   # 全清（不可恢复）
```

它会明确列出"动了什么 / 没动什么"；**默认永远只是预览**，要真删必须 `-Yes` 且给出范围。
