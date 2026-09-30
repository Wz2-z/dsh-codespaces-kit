# dsh 自己的坑

> [English version](../en/troubleshooting.md)

> [← 回到 README](../../README.md) · 其他平台：[Windows](windows.md) / [SSH](ssh.md) / [Codespaces](codespaces.md)

## 提示 `dsh web authentication required`

**现象**：浏览器或 SSH 里看到

```
dsh web authentication required; reopen the URL printed by dsh web.
```

**原因**：dsh 的凭证绑定 `127.0.0.1:3080` + 一次性的 token 地址，换域名或直接开根路径都会这样。

**解法**：

- 本机保持 `gh codespace ports forward 3080:3080 -c <名称>` 的隧道窗口开着
- 访问**最后一行打印出来的** `http://127.0.0.1:3080/?token=...`
- 不确定地址就再跑一次 `start.sh`，它会重新打印当前有效的地址

同一现象的另一个原因（用 `*.app.github.dev` 访问）见 [Codespaces](codespaces.md#github-的端口转发地址打不开-dsh)。

## "dsh 不能识图"其实是模型问题

dsh 支持图片输入，但取决于**模型声明的模态**：

| 模型 | 输入模态 | 结论 |
| --- | --- | --- |
| `deepseek-flash` | text + image | 能看图（1M 上下文） |
| `deepseek-v4-pro` | text | 纯文本 |

切换模型即可。只有自建/中转网关的视觉模型才需要在
「设置 → 模型 → 自定义设置 → 模型选项 → 输入类型」勾选"图片"
（保存为 `input` 或 `inputModalities`）—— 不是某个全局的 image 参数。

## 插件装了但侧边栏没出现

**按顺序查**：

1. 插件名有没有加进 profile `package.json` 的 `dsh.profile.bundles` 数组
2. 改完有没有**重启 dsh**（`dsh web` 那个进程）——
   可以用仓库里的 `tools/restart-dsh.sh`
3. 浏览器硬刷新（`Ctrl+Shift+R`）
4. 插件本身有没有报错：看 dsh 的启动日志

## 权限太宽 / 太严

**现象**：agent 动不动就要点确认，或者反过来，跑起来什么都不问。

**解法**：改 `~/.dsh/profiles/web/cordis.patch.yml` 里的权限预设：

```yaml
- id: permission
  name: "@deepseek-ai/dsh-permission-presets"
  config:
    defaultPreset: workspace-write   # 想更严就写 read-only
    presets:
      read-only:
        sandbox: read-only
        approval: ask
      workspace-write:
        sandbox: workspace-write
        approval: ask
      danger-full-access:
        sandbox: danger-full-access
        approval: ask
```

完整片段见 [技术细节 · 云端](../ai-runbook.md)。改完重启 dsh。

## 想更省心的一点建议

- 只给 dsh 一个**低额度、可随时吊销**的 DeepSeek API Key
- 新会话默认留在 `workspace-write`，别长期用 `danger-full-access`
- 插件在宿主进程内运行，权限等于你的云端账号：来源不清楚的先在 `read-only` 下试
