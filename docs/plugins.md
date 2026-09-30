# 插件

> [English version](en/plugins.md)

> [← 回到 README](https://github.com/Wz2-z/dsh-codespaces-kit/blob/main/README.md)

dsh 的插件跑在**宿主进程**里，权限等于你的云端账号。所以原则是：
**来源清楚、能看懂在干什么的才装；不确定的先在 `read-only` 权限下试跑。**

## dsh-codespace-panel（在侧边栏看额度 + 一键停止）

完整说明见 [`plugins/dsh-codespace-panel/`](https://github.com/Wz2-z/dsh-codespaces-kit/tree/main/plugins/dsh-codespace-panel)（含截图、路由、设计约束）。

**装法**：在**你自己的 dsh 云端容器**里执行（不是在本地电脑上跑）：

```bash
# 1) 把插件取到容器里
git clone https://github.com/Wz2-z/dsh-codespaces-kit.git ~/dsh-public

# 2) 装进 dsh 的 web profile
cd ~/.dsh/profiles/web
pnpm add ~/dsh-public/plugins/dsh-codespace-panel
```

```bash
# 3) 让它在启动时加载：把 "dsh-codespace-panel" 加进 package.json 的
#    dsh.profile.bundles 数组，例如：
#      "bundles": ["@deepseek-ai/dsh-base", "@deepseek-ai/dsh-web-app", "dsh-codespace-panel"]
```

改完重启 dsh（`dsh web` 那个进程，或直接用仓库里的 `tools/restart-dsh.sh`），
刷新页面即可看到侧边栏底部的电池图标。

> clone 慢的话，也可以只把 `plugins/dsh-codespace-panel/` 这个文件夹拷进容器，再 `pnpm add <那个文件夹路径>`。

**凭据说明**：

- 额度数字：需要一个**经典 PAT**（Personal access token (classic)，勾选 `user` 权限），
  在面板里粘贴即可 —— 它存进 dsh 的凭据存储（`$DSH_HOME/.credentials.yaml`，0600），不会进仓库；
- 当前 Codespace 的状态与"一键停止"：用容器自带的平台令牌，**零配置**。

## dsh-sync-panel（在侧边栏看/管自动同步）

和上面那个是**两个独立插件**，互不依赖，可以只装一个。

面板里能看到：当前模式（`idle` / `interval` / `manual`）、是否已暂停、守护进程在不在跑、
待提交的文件、最近一次提交、折叠窗口、以及 `~/dsh-sync.log` 的最后几行；
按钮有：立即提交、暂停、恢复、切换模式、折叠窗口开关。

**装法**（和上面一样，换名字即可）：

```bash
git clone https://github.com/Wz2-z/dsh-codespaces-kit.git ~/dsh-public
cd ~/.dsh/profiles/web
pnpm add ~/dsh-public/plugins/dsh-sync-panel
# 再把 "dsh-sync-panel" 加进 package.json 的 dsh.profile.bundles
```

细节见 [`plugins/dsh-sync-panel/README.md`](https://github.com/Wz2-z/dsh-codespaces-kit/blob/main/plugins/dsh-sync-panel/README.md)。

## 装之前值得问自己的三件事

1. 这个插件会不会读到我的 API Key / 私钥？（`~/.dsh/.credentials.yaml`、`~/.ssh`）
2. 它会不会往仓库里写东西？（工作区里的文件都会被 push 到你的私有仓库）
3. 出问题能不能卸掉？——`pnpm remove <包名>` + 把 `dsh.profile.bundles` 里的那一行删掉

插件的报错多半出现在 dsh 的启动日志里；侧边栏按钮不出现时，
见 [dsh 排错 · 插件装了但侧边栏没出现](troubleshooting/dsh.md#插件装了但侧边栏没出现)。
