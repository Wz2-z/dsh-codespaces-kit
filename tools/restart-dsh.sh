#!/usr/bin/env bash
# 重启 dsh web（宿主进程）。
#
# 用途：某些客户端插件（例如 @linxin666/dsh-remote-web-ui）的设置表单在页面会话里
# 绑定失败后不会自己恢复，需要重启宿主 + 刷新页面才会重新注册。
#
# 用法（在任意终端里，例如 DSH 右侧边栏的终端）：
#     bash ~/dsh-workspace/projects/plugincreate/restart-dsh.sh
#
# 重启后刷新浏览器页面即可（登录 cookie 有效 30 天，不需要重新用 URL 里的 token）。
set -u

LOG="$HOME/dsh-web.log"
WORKDIR="$HOME/dsh-workspace"
PORT=3080

say() { printf '%s\n' "$*"; }

# 1) 找到 dsh web 进程：argv 里必须有一个恰好是 "web" 的参数（脚本自身不会匹配），
#    且命令行里含有 dsh。
find_pids() {
  local p args a
  for p in /proc/[0-9]*; do
    [ -r "$p/cmdline" ] || continue
    args=()
    while IFS= read -r -d '' a; do args+=("$a"); done <"$p/cmdline" 2>/dev/null || continue
    [ "${#args[@]}" -ge 2 ] || continue
    local has_web=0 has_dsh=0
    for a in "${args[@]}"; do
      [ "$a" = "web" ] && has_web=1
      case "$a" in *dsh*) has_dsh=1 ;; esac
    done
    [ "$has_web" = 1 ] && [ "$has_dsh" = 1 ] || continue
    [ "${p#/proc/}" = "$$" ] && continue
    printf '%s\n' "${p#/proc/}"
  done
}

DSH_BIN="$(command -v dsh 2>/dev/null || true)"
if [ -z "$DSH_BIN" ]; then
  for candidate in "$HOME/.nvm/versions/node"/*/bin/dsh "$HOME/nvm/current/bin/dsh" /usr/local/share/nvm/versions/node/*/bin/dsh; do
    [ -x "$candidate" ] && DSH_BIN="$candidate" && break
  done
fi
if [ -z "$DSH_BIN" ]; then
  say "找不到 dsh 可执行文件，请先确认 dsh 已安装（npm i -g @deepseek-ai/dsh）。"
  exit 1
fi
say "dsh: $DSH_BIN"

pids="$(find_pids | tr '\n' ' ')"
if [ -n "${pids// /}" ]; then
  say "正在停止 dsh web（pid: $pids）…"
  # shellcheck disable=SC2086
  kill $pids 2>/dev/null || true
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    sleep 1
    [ -z "$(find_pids | tr -d '\n')" ] && break
  done
  pids="$(find_pids | tr '\n' ' ')"
  if [ -n "${pids// /}" ]; then
    say "普通停止没生效，强制结束：$pids"
    # shellcheck disable=SC2086
    kill -9 $pids 2>/dev/null || true
    sleep 2
  fi
else
  say "没有发现正在运行的 dsh web，直接启动。"
fi

say "正在启动 dsh web …"
cd "$WORKDIR" || exit 1
setsid nohup "$DSH_BIN" web >>"$LOG" 2>&1 </dev/null &

for _ in $(seq 1 30); do
  sleep 2
  if curl -s -o /dev/null -m 3 "http://127.0.0.1:$PORT/"; then
    say "dsh web 已重启（端口 $PORT 有响应）。"
    url="$(grep -o "http://127.0.0.1:$PORT/?token=[A-Za-z0-9_-]*" "$LOG" 2>/dev/null | tail -1)"
    [ -n "$url" ] && say "新的访问地址（浏览器 cookie 仍有效时不需要它）：$url"
    say "现在刷新浏览器页面即可。"
    exit 0
  fi
done

say "dsh web 在 60 秒内没有起来，请查看日志：$LOG"
exit 1
