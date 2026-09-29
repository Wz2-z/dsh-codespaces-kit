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

`sync.sh`：自动提交推送（含空目录处理）

```bash
#!/usr/bin/env bash
set -u
WORK="$HOME/dsh-workspace"; LOG="$HOME/dsh-sync.log"
keep_empty_dirs() {
  find "$WORK" \( -name .git -o -name node_modules \) -prune -o -type d -empty -print0 2>/dev/null |
    while IFS= read -r -d '' d; do
      rel="${d#"$WORK"/}"
      if ! git -C "$WORK" check-ignore -q -- "$rel"; then : >"$d/.gitkeep"; fi
    done
}
sync_once() {
  cd "$WORK" || return 1
  keep_empty_dirs
  if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
    git add -A
    git -c user.name="dsh cloud" -c user.email="dsh-cloud@users.noreply.github.com" \
      commit -q -m "auto-sync $(date '+%Y-%m-%d %H:%M:%S')" >>"$LOG" 2>&1
    if git push -q origin HEAD >>"$LOG" 2>&1; then
      echo "$(date -Is) pushed" >>"$LOG"
    else
      echo "$(date -Is) push FAILED" >>"$LOG"
    fi
  fi
}
case "${1:-300}" in
  --once) sync_once; exit $? ;;
  *) INTERVAL="$1" ;;
esac
while true; do sleep "$INTERVAL"; sync_once; done
```

---

[← 回到 README](../README.md)
