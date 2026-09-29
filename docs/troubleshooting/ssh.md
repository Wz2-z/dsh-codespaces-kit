# SSH 与隧道

> [← 回到 README](../../README.md) · 其他平台：[Windows](windows.md) / [Codespaces](codespaces.md) / [dsh](dsh.md)

这一类问题的共同点：**dsh 本身没事，是本机连不上云端，或者连上了但隧道没建起来。**

## `Load key ...: Permission denied`

**现象**

```
Load key "C:\Users\<你>\.ssh\dsh_cs_key": Permission denied
```

**原因**：私钥由**别人**（或 agent 沙箱）创建时，文件属主/ACL 不对，Windows OpenSSH 会拒绝加载。

**解法**：让**使用这台电脑的人**自己在 `%USERPROFILE%\.ssh\` 里生成：

```bat
ssh-keygen -t ed25519 -N "" -f "%USERPROFILE%\.ssh\dsh_cs_key" -C dsh-codespace
```

必要时再收一下权限（只留自己可读）：

```bat
icacls "%USERPROFILE%\.ssh\dsh_cs_key" /inheritance:r /grant:r "%USERNAME%:R"
```

## 连不上 Codespace

**按顺序查这三件事**：

1. `gh auth status` —— 有没有登录、scope 里有没有 `codespace`
2. Codespace 名字对不对：<https://github.com/codespaces> 复制完整名字（大小写敏感的随机串）
3. Codespace 是不是被关了 —— 关掉的会先被唤醒，第一次连接慢 30–60 秒很正常

```bash
gh codespace list
gh codespace ssh -c <codespace 名> -- -i <私钥路径> "echo ok"
```

## 隧道建不起来（浏览器打不开）

**正确的姿势**（两个窗口各干一件事）：

```bash
# 窗口 1：本机建隧道，保持开着
gh codespace ports forward 3080:3080 -c <codespace 名>
```

```bash
# 窗口 2：进容器把 dsh 拉起来，最后一行会打印带 token 的地址
gh codespace ssh -c <codespace 名> -- -i <私钥路径> "bash /workspaces/<repo>/.dsh-cloud/start.sh"
```

然后**打开打印出来的那个 `http://127.0.0.1:3080/?token=...`**。

> 不要用 `https://xxx-3080.app.github.dev`，那个地址一定会报
> `dsh web authentication required`，原因见 [Codespaces](codespaces.md#github-的端口转发地址打不开-dsh)。

## 隧道窗口关掉会怎样

浏览器会立刻打不开 dsh（页面显示 `127.0.0.1 拒绝了我们的连接请求`）。

**解法**：重新双击桌面「DeepSeek Harness」即可；云端 dsh 进程本身不会因为你关窗口而停。

## deploy key（自动同步用的那把钥匙）

云端工作区提交代码用的是**只对一个私有仓库有写权限**的 deploy key，不是账号级 token：

```bash
ssh-keygen -t ed25519 -N "" -f ~/.ssh/dsh_deploy -C dsh-deploy
cat ~/.ssh/dsh_deploy.pub     # 加到仓库 Settings → Deploy keys，勾选 Allow write access
```

让工作区固定用这把 key：

```bash
cd ~/dsh-workspace
git config core.sshCommand "ssh -i $HOME/.ssh/dsh_deploy -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new"
```

**不要**把私钥交给 agent：

- 本机私钥在 `%USERPROFILE%\.ssh\`
- 云端私钥在 `~/.ssh/dsh_deploy`
- 两者都只用于 SSH，不属于工作区，也不会被 push
