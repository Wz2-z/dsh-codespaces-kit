# dsh-codespace-panel

在 DSH Web 界面里看 **GitHub Codespaces 额度**，并**一键停止当前 Codespace**。一个 bundle、一行 Host 插件、四个 EXACT 路由。

- **触发按钮**：侧边栏底部、Settings 旁边的电池图标（`sidebar.footer.action`，id `codespace-quota`）；数据加载后展开状态会显示剩余核心·小时数，右上角小圆点按用量变色。
- **弹出面板**：注册在框架级浮层 `shell.overlay`，不会被任何一栏裁剪。
- 面板内容：套餐、本月计算额度（核心·小时）、存储额度（GB·月）、进度条、剩余量、重置日期、原始用量明细；底部是「当前 Codespace」——状态、机器规格、自动停止时间、上次使用，以及带二次确认的 **停止 Codespace**。

## 两套凭据，两种权限

| 功能 | 接口 | 需要什么 |
| --- | --- | --- |
| 额度数字 | [Billing API](https://docs.github.com/en/rest/billing/usage) | **经典 PAT + `user` 权限**（细粒度令牌不支持个人账单接口）。在面板里粘贴即可，写入 DSH 凭据存储的 `codespace-panel/quota-token` 记录（`$DSH_HOME/.credentials.yaml`，0600，不进仓库） |
| 状态 / 停止 | [Codespaces API](https://docs.github.com/en/rest/codespaces/codespaces) | **容器自带的平台令牌**（`/workspaces/.codespaces/shared/` 里那枚，git/gh 用的同一个），**零配置** |

令牌只留在 Host 进程，浏览器永远拿不到；额度令牌按「行配置 `token` → 环境变量（`GITHUB_TOKEN`/`GH_TOKEN`/`CODESPACE_QUOTA_TOKEN`）→ 凭据存储记录 → 旧的明文文件（只读迁移用，保存后自动删除）」取用。本插件不再写任何明文令牌文件。

## 路由（都要自定义请求头 `x-codespace-quota: 1`）

- `GET  /codespace-quota/summary[?refresh=1]` — 额度快照
- `POST /codespace-quota/token` — 保存/清空额度令牌
- `GET  /codespace-quota/codespace` — 当前 Codespace 状态
- `POST /codespace-quota/stop` — 停止当前 Codespace

全部是 EXACT 路由：Web 服务器先查 exact 表再查 prefix 表，谁也不会被别人的前缀路由盖住。

## 可选配置

写在你自己的 profile `cordis.patch.yml` 对应行里（Host 半边自己校验，未知键会记日志并忽略）：

```yaml
- id: codespace-panel
  name: 'dsh-codespace-panel'
  config:
    includedCoreHours: 180   # 0 = 按套餐自动判断（Free 120 / Pro 180）
    includedStorageGb: 20    # 0 = 按套餐自动判断（Free 15 / Pro 20）
    cacheSeconds: 120
```

## 设计约束（踩过的坑）

1. **只插入一行，而且必须一次装好**：loader 里出现一行激活失败（`inactive`）会破坏其它插件设置表单所依赖的「可配置条目」视图；而 `dsh-remote-web-ui` 的表单每个页面会话只绑定一次，绑坏了就再也不会注册它的侧边栏按钮，直到刷新/重启。第一次安装之所以和它共存无碍，正是因为那次没有失败行。
2. **不导出 `Config` 模式**：改为在 `apply` 里手写归一化，这样本插件不会往 profile 的可配置条目表面添加任何特殊形态。
3. **客户端只在 `sidebar.footer.action` 放一个恒定尺寸的图标**：那一行同时被 `dsh-remote-web-ui` 和 `dsh-cost-meter` 的 CSS 接管布局，尺寸变化或时隐时现都会带动别人的控件。
