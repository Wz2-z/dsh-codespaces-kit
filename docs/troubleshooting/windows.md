# Windows 上的坑

> [English version](../en/troubleshooting.md)

> [← 回到 README](../../README.md) · 其他平台：[SSH](ssh.md) / [Codespaces](codespaces.md) / [dsh](dsh.md)

## `.bat` 里的中文变成 `????`

**现象**

```
FINDSTR: 无法打开 C:\Users\<你>\...\dsh????.txt
```

日志文件名里的中文全变成问号，脚本后面几步跟着一起报错。

**原因**

批处理文件按 ASCII 保存时，中文会被写成 `?`；再叠加 `%USERPROFILE%` 路径本身可能含中文
（例如 `C:\Users\张三\`），重定向就直接失败。

**解法**

- 批处理保持**纯 ASCII**：注释、日志文件名、临时文件名都用英文
- 路径一律用 `%USERPROFILE%`、`%LOCALAPPDATA%` 拼，不要把中文路径写死进去
- 需要中文界面时，让 AI 生成 `.ps1`（PowerShell 对 UTF-8 友好），或者启动后就 `chcp 65001`

## 桌面快捷方式的图标不对

**现象**：双击能跑，但图标是默认的 `.bat` 图标，不是 dsh 的 logo。

**原因**：`.lnk` 指向了 `.bat` 而不是图标文件，或图标路径失效。

**解法**：让 AI 重新生成快捷方式，`IconLocation` 指向本地 `.ico`
（`%LOCALAPPDATA%\dsh-cloud\icons\dsh.ico`），不要指向网上的图片。

## 没有管理员权限能装吗

**能。** 整条链路都是便携式的：

- 便携版 GitHub CLI 解压到 `%LOCALAPPDATA%\dsh-cloud\gh\`，不写系统目录、不动 `PATH`
- SSH 密钥放在 `%USERPROFILE%\.ssh\`
- 桌面快捷方式放在 `%USERPROFILE%\Desktop\`

唯一需要"点一下"的地方是浏览器里给 `gh` 授权（见 README 第 4 步）。

## 用户名含中文时要注意什么

`C:\Users\张三\` 这类路径本身没问题，但要注意：

- 脚本里**不要**手写这个中文路径，用 `%USERPROFILE%` 让系统自己展开
- `.bat` 一旦含中文就有上面那个问号的坑，所以日志、临时文件都用英文名
- 云端看到的本机路径只有你传给它的那部分，别把带中文的路径拼进命令字符串

## 私钥被拒绝（`Permission denied`）

这是 Windows OpenSSH 的常见问题，见 [SSH](ssh.md#load-key-permission-denied)。
