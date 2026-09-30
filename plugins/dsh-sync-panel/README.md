# dsh-sync-panel

作者：[@Wz2-z](https://github.com/Wz2-z) · 许可：MIT · [English](README.en.md)

在 dsh 侧边栏底部放一个**同步按钮**：点开就能看到自动同步的状态，并且能直接操作它 ——
不用再跑到容器终端里敲 `sync.sh --status`。

## 面板里有什么

- **徽章**：当前模式（`idle` / `interval` / `manual`）、同步中还是已暂停、守护进程在不在跑
- **待提交**：几个文件、具体是哪几个（最多 6 个）
- **最近提交**：`af51acc dsh: update projects/x (12 files)`
- **折叠窗口 / 静默阈值**：当前生效的秒数
- **最近日志**：`~/dsh-sync.log` 的最后几行（`pushed` / `folded` / `skipped` / `FAILED`）
- **按钮**：立即提交、暂停、恢复、切换模式（idle / interval / manual）、折叠窗口开/关

## 语言

界面跟 **dsh 的语言**走（`ctx.locale`）：dsh 说中文就是中文，说 English 就是 English，不用另设开关。
两套文案都在 `client.js` 里（`zh` / `en` 两张表，键一一对应），插件列表里的标题与说明来自
`locale/zh.json` 与 `locale/en.json`。

Host 半边只回错误码（`no-sync-script` / `bad-mode` / `bad-action` …），具体措辞由客户端挑；
唯一例外是 `command-failed` —— 它带的是 `sync.sh` 自己的输出，会原样显示（那部分文案在云端脚本里）。

## 装法

在**你自己的 dsh 云端容器**里执行：

```bash
# 1) 把插件取到容器里
git clone https://github.com/Wz2-z/dsh-codespaces-kit.git ~/dsh-public

# 2) 装进 dsh 的 web profile
cd ~/.dsh/profiles/web
pnpm add ~/dsh-public/plugins/dsh-sync-panel

# 3) 让它在启动时加载：把 "dsh-sync-panel" 加进 package.json 的 dsh.profile.bundles
#    "bundles": ["@deepseek-ai/dsh-base", "@deepseek-ai/dsh-web-app", "dsh-sync-panel"]
```

改完重启 dsh（`dsh web` 那个进程），刷新页面即可看到侧边栏底部多出来的同步图标。

## 两半的分工

| 半边 | 做什么 |
| --- | --- |
| Host（`index.js`） | 两条 EXACT 路由：`GET /sync-panel/summary` 读状态；`POST /sync-panel/action` 代跑 `sync.sh --disable/--enable/--now/--mode=/--squash-window=` |
| Client（`client.js`） | 一个恒定尺寸的 footer 按钮 + 一个 `shell.overlay` 面板；只跟这两条路由说话 |

两条路由都要求自定义请求头 `x-sync-panel: 1`，浏览器里的其它页面拿不到这个头；
Host 半边不碰 git 凭据、不碰 API Key，只在你机器上跑仓库里的那个 `sync.sh`。

## 可选配置

写在 profile `cordis.patch.yml` 对应行里（未知键会记日志并忽略）：

```yaml
- id: sync-panel
  name: 'dsh-sync-panel'
  config:
    dir: /workspaces/<repo>/.dsh-cloud   # 不写就自动在 /workspaces/*/.dsh-cloud 里找
    workspace: /home/codespace/dsh-workspace
    timeoutMs: 60000
    logLines: 8
```

## 设计约束（踩过的坑）

1. **只插一行，而且必须一次装好**：loader 里出现一行激活失败（`inactive`）会破坏其它插件设置表单依赖的
   「可配置条目」视图；第一次装之所以和 `dsh-codespace-panel` 共存无碍，正是因为那次没有失败行。
2. **footer 按钮保持恒定尺寸**：那一行同时被 `dsh-remote-web-ui`、`dsh-cost-meter`、`dsh-codespace-panel`
   的布局 CSS 接管，尺寸变化会带动别人的控件。
3. **面板必须放 `shell.overlay`**：放在 `sidebar.footer.action` 里会被栏裁掉。
4. 不导出 `Config` 模式，配置在 `apply` 里手写归一化。
