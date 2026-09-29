> [← 回到 README](../README.md)
>
> 把下面**整段**复制给 AI（Codex / dsh / 任何 coding agent 都行）。
> 复制前先把 `<...>` 占位符换成你自己的信息。

# 给 AI 的任务书

```text
我要用 GitHub Codespaces 在云端部署 DeepSeek Harness（dsh），请帮我配置好云端和本机。

【我的信息】
- GitHub 用户名：<你的用户名>
- 已建好的私有仓库：<你的用户名>/<仓库名>
- Codespace 名称：<从 https://github.com/codespaces 复制>
- 本机系统：Windows 11，普通用户（不是管理员）
- 我使用 DeepSeek 官方 API Key（自己充值）付费用量

【目标】
1. 我在本机双击一个脚本，就能打开云端 dsh 的 Web UI，不需要手动敲命令
2. 云端工作区 = 我那个私有仓库的克隆，改动自动 commit + push 备份
3. 不改本机系统设置、不需要管理员权限、不装全局软件（用便携版）
4. 权限保持最保守：新会话默认 workspace-write + ask，不启用 auto review

【请你完成】
A. 云端（Codespaces 容器内）
   - 装 Node 22（>=22.19）和 @deepseek-ai/dsh
   - 在 /workspaces/<repo>/.dsh-cloud/ 放三个脚本：
     start.sh（确保 dsh 在跑，最后一行输出带 token 的访问地址）
     update.sh（升级 dsh 到最新版并重启）
     sync.sh（每 5 分钟自动 commit + push 工作区，含空目录 .gitkeep 处理）
   - 配一把只对 <你的用户名>/<仓库名> 有写权限的 deploy key（不要用账号级 token）
   - 把 dsh 工作区克隆到 ~/dsh-workspace，git 使用这把 deploy key
   - 写 dsh 权限预设：defaultPreset=workspace-write，presets 里保留 read-only，
     并把 danger-full-access 的审批策略从 never 改成 ask
B. 本机（Windows）
   - 下载便携版 GitHub CLI 到 %LOCALAPPDATA%\dsh-cloud（解压即用，不装到系统）
   - 引导我做一次 gh auth login（scope 需要 codespace,repo,read:org,workflow）
   - 在 %USERPROFILE%\.ssh 下生成 SSH 密钥（必须由我这个用户生成，否则 Windows ssh 会拒绝）
   - 写两个脚本 + 桌面快捷方式（图标用 dsh 官方图标）：
     启动脚本：检查/唤醒 Codespace → 触发云端 start.sh → gh codespace ports forward 3080:3080
               → 用返回的 token 地址打开浏览器
     更新脚本：触发云端 update.sh → 同样建隧道并打开浏览器
C. 验证并告诉我结果
   - 云端 dsh 启动正常（不带 token 访问返回 401，带 token 返回 303）
   - 本机隧道能打开 dsh 界面
   - 工作区能 push 成功（本地 HEAD == 远端 main）

【已知的坑，请务必照做】
1. GitHub 的 *.app.github.dev 端口转发地址打不开 dsh —— dsh 的登录凭证绑定
   127.0.0.1:3080，必须在本机用 gh codespace ports forward 3080:3080 -c <名称>
   建隧道，再用 dsh 打印的带 token 地址访问。
2. Windows 批处理文件保持纯 ASCII，路径用 %USERPROFILE%，不要把中文文件名写进 .bat。
3. SSH 私钥必须由"使用这台电脑的人"在 %USERPROFILE%\.ssh 里生成；
   别人（或 agent 沙箱）生成的密钥，Windows 的 ssh 会报 Permission denied。
4. 不要用 pkill -f "dsh web"（命令自身包含该字符串，会把自己杀掉）；
   改用按端口找 PID：ss -ltnp | grep :3080，然后 kill 那个 PID。
5. 空文件夹不会被 git 跟踪，同步脚本要先给空目录放 .gitkeep 再 add。
6. 云端 /workspaces 是持久卷，$HOME 在容器重建后会清空 —— 脚本必须放 /workspaces。
7. 一次性长命令在 PTY 下可能被截断，改文件请用 base64 传输并避免 tty。
8. dsh 是否"识图"取决于模型：deepseek-v4-pro 是纯文本，deepseek-flash 支持图片
   （改的是模型声明的 inputModalities，不是某个全局 image 参数）。

【交付给我】
- 桌面两个快捷方式（启动 / 更新）
- 一份"我下次自己怎么用"的简短说明
- 云端脚本存进我的仓库（tools/dsh-cloud/），这样换电脑也能用
```

---

[← 回到 README](../README.md)
