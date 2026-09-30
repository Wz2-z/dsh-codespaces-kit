# Codespaces 上的坑

> [English version](../en/troubleshooting.md)

> [← 回到 README](https://github.com/Wz2-z/dsh-codespaces-kit/blob/main/README.md) · 其他平台：[Windows](windows.md) / [SSH](ssh.md) / [dsh](dsh.md)

## GitHub 的端口转发地址打不开 dsh

**现象**：把 3080 端口设成 Public/Private 后访问 `https://xxx-3080.app.github.dev`，看到：

```
dsh web authentication required; reopen the URL printed by dsh web.
```

**原因**：dsh 的会话凭证（token → cookie）**绑定 authority `127.0.0.1:3080`**，换域名就对不上。

**解法**：本机执行 `gh codespace ports forward 3080:3080 -c <名称>`，再访问 dsh 打印的原始地址。
详细命令见 [SSH](ssh.md#隧道建不起来浏览器打不开)。

## 容器重建后环境没了

**现象**：改了 devcontainer / 点了 Rebuild 之后，dsh 要重装、`~/.dsh` 会话历史清空、deploy key 也没了。

**原因**：`/workspaces` 是**持久卷**，但 `$HOME` 会在容器重建时清空。

**解法**：

- 脚本放 `/workspaces/<repo>/.dsh-cloud/`，不要放 `~/`
- 重要成果 push 到仓库（自动同步会在改动静默下来后自己做一次）
- 别随便改 devcontainer 配置；真要改，先确认脚本都在持久卷里

## 不活跃会被删 + 怎么省额度

- Codespace 默认 **30 天不活跃会被自动删除**，`~/dsh-workspace`、`~/.dsh` 都会没
- 不用的时候去 <https://github.com/codespaces> 点 **Stop**
- 闲置时间改长一点（<https://github.com/settings/codespaces> → Default idle timeout）
- 用了多少额度：<https://github.com/settings/billing> 里的 Codespaces 一节，或装
  [`dsh-codespace-panel`](https://github.com/Wz2-z/dsh-codespaces-kit/tree/main/plugins/dsh-codespace-panel) 插件在侧边栏直接看

## `pkill -f "dsh web"` 把自己杀掉了

**现象**：SSH 里执行完，连接直接断，报 `shell closed: exit status 0xffffffff`。

**原因**：你执行的命令字符串本身包含 `dsh web`，`pkill -f` 连自己一起杀。

**解法**：按端口找 PID 再 kill：

```bash
PID=$(ss -ltnp 2>/dev/null | grep ':3080' | grep -o 'pid=[0-9]*' | head -1 | cut -d= -f2)
if [ -n "$PID" ]; then kill "$PID"; fi
```

或者直接用仓库里的 `tools/restart-dsh.sh`。

## 超长命令在 PTY 下被截断

**现象**：一次传一大段脚本，报 `syntax error near unexpected token '('` 之类的怪错。

**原因**：带 tty 的连接对一次性长命令有截断。

**解法**：用 base64 传文件，并且**不要开 tty**；长脚本先落到磁盘再执行。

## 云端的 `~/.nvm/nvm.sh` 可能不存在

**现象**：`nvm: command not found`，但 `node` 又装好了。

**原因**：Codespaces 的 nvm 在 `/usr/local/share/nvm`，`~/.nvm` 里只有 versions。

**解法**：脚本里直接用绝对路径，或多路径探测：

```bash
for d in "$HOME/.nvm/versions/node"/*/bin /usr/local/share/nvm/versions/node/*/bin; do
  if [ -x "$d/dsh" ]; then export PATH="$d:$PATH"; break; fi
done
```

## 空目录不会被同步

**现象**：在 dsh 里新建的文件夹，仓库里看不到。

**原因**：git 不跟踪空目录。

**解法**：同步脚本每次先给空目录放 `.gitkeep`（跳过 `node_modules` 和被忽略的目录）。
参考实现见 [云端三个脚本](../cloud-scripts.md)。
