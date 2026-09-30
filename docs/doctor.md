# dsh-codespaces doctor

> [English version](en/doctor.md)

> [← 回到 README](../README.md) · 相关：[自动同步](auto-sync.md) · [排错手册](troubleshooting/codespaces.md)

装完、换电脑、或者"感觉哪里不对"的时候跑一次：

```powershell
# Windows
powershell -ExecutionPolicy Bypass -File install\doctor.ps1
```

```bash
# macOS / Linux
bash install/doctor.sh
```

它把**本机**和**容器里**两边的状态合成一张表，最后给一句 `N/M checks passed`。

## 12 项检查

| 检查 | 在哪边看 | ✓ 代表 | 常见修法 |
| --- | --- | --- | --- |
| GitHub CLI | 本机 | 找得到 `gh` 并报出版本 | `install/setup.ps1` 会装便携版；或自己 `brew install gh` |
| GitHub authentication | 本机 | `gh auth status` 通过 | `gh auth login --scopes codespace,repo,read:org,workflow` |
| Codespace | 本机 | 有一个可用的 Codespace | 没有就 `gh codespace create -R owner/repo`（或 `dsh-codespaces setup`） |
| DSH | 容器 | 找得到 dsh 并报出版本 | 跑 `install/cloud-setup.sh` |
| SSH key | 本机 | 私钥存在**且** `ssh-keygen` 读得出来 | 让**本人**重新生成；Windows 上用 `icacls` 只留自己可读 |
| Workspace | 容器 | 工作区干净、HEAD 和远端一致 | 有未提交改动等自动同步，或 `sync.sh --now` |
| Deploy key | 容器 | `~/.ssh/dsh_deploy` 能读写仓库 | 公钥加到仓库 Settings → Deploy keys（勾 write） |
| Auto sync | 容器 | 守护进程在跑、没暂停 | `bash .dsh-cloud/start.sh`；暂停过就 `sync.sh --enable` |
| Sync config | 容器 | `sync.conf` 里有合法的 mode | 跑 `cloud-setup.sh` 生成默认值 |
| dsh web | 容器 | 3080 在监听且需要 token（401） | `bash .dsh-cloud/start.sh`；看 `~/dsh-web.log` |
| Tunnel | 本机 | `127.0.0.1:3080` 能通 | 双击桌面启动器；或 `gh codespace ports forward 3080:3080` |
| Launcher | 本机 | 桌面有启动器 | `install/setup.ps1` / `setup.sh` 重新生成 |

## 三种状态的读法

- `✓` **ok** —— 这一项没问题
- `!` **warn** —— 能用，但值得看一眼（比如"自动同步被暂停了"、"网络不通所以没验证 token"）
- `✗` **fail** —— 这一项坏了，上面通常写着下一步做什么

只要没有 `✗`，退出码就是 0；有 `✗` 时退出码是 1（方便写进脚本或 CI）。

## 参数

| 参数 | 作用 |
| --- | --- |
| `-Base <目录>`（Windows） | 一整套东西放在一起的目录（里面应有 `gh\bin\gh.exe` 和 `ghconfig\`） |
| `-Gh <路径>` / `--key <路径>` | 手动指定 gh / 私钥 |
| `-Key <路径>` | 手动指定私钥 |
| `-NoTunnel` / `--no-tunnel` | 跳过隧道检查（快一点，但看不到 Tunnel 那一项的真实结果） |
| `-Json` / `--json` | 输出 JSON，给别的脚本用 |

## 它不做什么

- 不改任何配置、不重启 dsh、不提交代码 —— 只读检查（隧道那一项会临时开一个端口转发，查完就关）
- 不发任何东西到 GitHub 之外；云端那半只是在本机跑仓库里的脚本

## 写 .bat / .ps1 时踩过的两个坑

自己写启动器时容易撞上这两条（都在这套脚本里踩过）：

1. **`.bat` 必须是 CRLF 行尾**：LF 行尾的批处理里 `goto 标签` 会报
   *"The system cannot find the batch label specified"* —— 用 LF 编辑器的同学注意。
2. **中文输出要先 `chcp 65001`**：容器里的脚本输出是 UTF-8，而中文 Windows 控制台默认 936，
   直接 `type` 出来就是 `妯″紡锛歩dle` 这种乱码。在 `.bat` 开头加
   `chcp 65001 >nul`，`.ps1` 里加 `[Console]::OutputEncoding = [Text.Encoding]::UTF8`。
   （`.ps1` 文件本身要存成**带 BOM 的 UTF-8**，否则 PowerShell 5.1 会按 GBK 读中文。）
