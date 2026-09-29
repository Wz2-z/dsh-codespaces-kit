> [← 回到 README](../README.md)
>
> 云端三个脚本的**精简版参考**，用来理解原理或手工修脚本。
> 实际部署时 AI 会按你的仓库名/路径生成完整版本，不需要手抄。

# 云端三个脚本（精简版参考）

`start.sh`：确保 dsh 在跑 → 拉起同步循环 → 最后一行打印访问地址

```bash
#!/usr/bin/env bash
set -u
LOG="$HOME/dsh-web.log"; SYNC="/workspaces/<repo>/.dsh-cloud/sync.sh"
NODE_BIN="$HOME/.nvm/versions/node/v22.x.y/bin"
ensure_dsh() {
  if [ -x "$NODE_BIN/dsh" ]; then export PATH="$NODE_BIN:$PATH"; return 0; fi
  for d in "$HOME/.nvm/versions/node"/*/bin "$HOME/nvm/current/bin" /usr/local/share/nvm/versions/node/*/bin; do
    if [ -x "$d/dsh" ]; then export PATH="$d:$PATH"; return 0; fi
  done
  npm install -g @deepseek-ai/dsh >>"$LOG.install" 2>&1 || true
  command -v dsh >/dev/null 2>&1
}
ensure_dsh || { echo "STATE:NO_DSH"; exit 1; }
mkdir -p "$HOME/dsh-workspace"
if ! curl -s -o /dev/null -m 3 http://127.0.0.1:3080/; then
  (setsid nohup bash -c "cd $HOME/dsh-workspace && exec dsh web" >"$LOG" 2>&1 </dev/null &)
  sleep 20
fi
if [ -x "$SYNC" ] && ! pgrep -f 'dsh-cloud/sync.sh' >/dev/null 2>&1; then
  (setsid nohup bash "$SYNC" 300 >/dev/null 2>&1 </dev/null &)
fi
echo "STATE:$(curl -s -o /dev/null -w '%{http_code}' -m 3 http://127.0.0.1:3080/ || true)"
grep -a -o 'http://127.0.0.1:3080[^ ]*' "$LOG" | tail -n 1
```

`update.sh`：升级并重启

```bash
#!/usr/bin/env bash
export PATH="$HOME/.nvm/versions/node/v22.x.y/bin:$PATH"
echo "BEFORE:$(dsh --version 2>/dev/null || echo unknown)"
npm install -g @deepseek-ai/dsh@latest >>"$HOME/dsh-update.log" 2>&1 || { echo UPDATE:FAILED; exit 1; }
echo "AFTER:$(dsh --version 2>/dev/null || echo unknown)"
PID=$(ss -ltnp 2>/dev/null | grep ':3080' | grep -o 'pid=[0-9]*' | head -1 | cut -d= -f2)
if [ -n "$PID" ]; then kill "$PID"; sleep 2; fi
bash /workspaces/<repo>/.dsh-cloud/start.sh
```

`sync.sh`：自动同步（智能批量）

真实版本有 200 多行（模式切换、状态文件、rebase 重试、提交信息生成），由 `install/cloud-setup.sh` 生成。
这里只留算法骨架：

```bash
# 1) 指纹：已跟踪 diff + 未跟踪文件的 大小/时间 —— 改一点点就能看出来
fp=$( { git status --porcelain -uall; git diff --binary; } | sha1sum )

# 2) 有新改动就把"静默计时"重置
[ "$fp" != "$LAST_FP" ] && CHANGED_AT=$(date +%s)

# 3) 静默够了（或拖过 max_wait）就提交一次
if [ $(( $(date +%s) - CHANGED_AT )) -ge "$idle_seconds" ]; then
  git add -A
  git commit -m "$(build_message)"        # dsh: update projects/x (12 files)
  git push origin HEAD                    # 被拒就 pull --rebase 再试一次
fi
```

- `mode=idle|interval|manual`、`idle_seconds`、`max_wait` 等都在 `.dsh-cloud/sync.conf` 里
- 提交信息按改动目录自动生成；也可以用 `--message=` 或 `.dsh-cloud/commit-msg` 指定一次
- 行为细节见 [自动同步](auto-sync.md)

---

[← 回到 README](../README.md)
