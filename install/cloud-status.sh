#!/usr/bin/env bash
# =============================================================================
#  dsh-codespaces status（云端半）—— 输出机器可读的一行行 STATUS|key|value
#
#  由 install/status.ps1 / install/status.sh 通过 stdin 送进容器执行：
#      gh codespace ssh -c <名字> -- "bash -s" < cloud-status.sh
# =============================================================================
set -u

emit() { printf 'STATUS|%s|%s\n' "$1" "$2"; }
to_epoch() { date -d "$1" +%s 2>/dev/null || echo ''; }

CODESPACE_NAME="${CODESPACE_NAME:-}"
if [ -z "$CODESPACE_NAME" ] && [ -r /workspaces/.codespaces/shared/.env ]; then
  CODESPACE_NAME="$(grep -m1 '^CODESPACE_NAME=' /workspaces/.codespaces/shared/.env 2>/dev/null | cut -d= -f2- | tr -d '"' | tr -d '\r')"
fi
emit codespace "$CODESPACE_NAME"

REPO_ROOT="${GITHUB_WORKSPACE:-}"
if [ -z "$REPO_ROOT" ] || [ ! -d "$REPO_ROOT/.git" ]; then
  REPO_ROOT=""
  for d in /workspaces/*/.git; do
    [ -d "$d" ] || continue
    REPO_ROOT="$(dirname "$d")"
    break
  done
fi
CLOUD_DIR=""
[ -n "$REPO_ROOT" ] && [ -d "$REPO_ROOT/.dsh-cloud" ] && CLOUD_DIR="$REPO_ROOT/.dsh-cloud"
emit cloud_dir "$CLOUD_DIR"

WS="${DSH_WORKSPACE:-$HOME/dsh-workspace}"
BRANCH="$(git -C "$WS" rev-parse --abbrev-ref HEAD 2>/dev/null || echo main)"
[ "$BRANCH" = "HEAD" ] && BRANCH="main"
emit branch "$BRANCH"
emit workspace "$WS"

# ------------------------------------------------------------------ dsh
DSH_DIR=""
RUN_PID="$(ss -ltnp 2>/dev/null | grep ':3080' | grep -o 'pid=[0-9]*' | head -1 | cut -d= -f2)"
if [ -n "$RUN_PID" ]; then
  RUN_EXE="$(readlink -f "/proc/$RUN_PID/exe" 2>/dev/null)"
  [ -n "$RUN_EXE" ] && [ -x "$(dirname "$RUN_EXE")/dsh" ] && DSH_DIR="$(dirname "$RUN_EXE")"
fi
if [ -z "$DSH_DIR" ]; then
  for cand in "$HOME/.nvm/versions/node"/*/bin "$HOME/nvm/current/bin" /usr/local/share/nvm/versions/node/*/bin; do
    [ -x "$cand/dsh" ] || continue
    DSH_DIR="$cand"
    break
  done
fi
emit dsh_version "$([ -n "$DSH_DIR" ] && "$DSH_DIR/dsh" --version 2>/dev/null || echo '')"
emit dsh_pid "${RUN_PID:-}"
emit dsh_http "$(curl -s -o /dev/null -w '%{http_code}' -m 3 http://127.0.0.1:3080/ 2>/dev/null || echo 000)"

# ---------------------------------------------------------------- 自动同步
if [ -n "$CLOUD_DIR" ] && [ -f "$CLOUD_DIR/sync.conf" ]; then
  emit mode "$(grep -m1 '^mode=' "$CLOUD_DIR/sync.conf" 2>/dev/null | cut -d= -f2 | tr -d ' ')"
  emit enabled "$(grep -m1 '^enabled=' "$CLOUD_DIR/sync.conf" 2>/dev/null | cut -d= -f2 | tr -d ' ')"
  emit idle "$(grep -m1 '^idle_seconds=' "$CLOUD_DIR/sync.conf" 2>/dev/null | cut -d= -f2 | tr -d ' ')"
  emit squash "$(grep -m1 '^squash_window_seconds=' "$CLOUD_DIR/sync.conf" 2>/dev/null | cut -d= -f2 | tr -d ' ')"
  emit daemon_pids "$(pgrep -f "$CLOUD_DIR/sync[.]sh" 2>/dev/null | tr '\n' ' ' | sed 's/ $//')"
else
  emit mode ""; emit enabled ""; emit idle ""; emit squash ""; emit daemon_pids ""
fi

LOG="$HOME/dsh-sync.log"
if [ -f "$LOG" ]; then
  LAST_LINE="$(tail -n 1 "$LOG" 2>/dev/null)"
  emit last_check_epoch "$(to_epoch "${LAST_LINE%% *}")"
  emit last_check_line "$LAST_LINE"
  LAST_PUSH="$(grep -E ' (pushed|folded into previous auto-commit) ' "$LOG" 2>/dev/null | tail -1)"
  emit last_push_epoch "$(to_epoch "${LAST_PUSH%% *}")"
  emit last_push_subject "$(printf '%s' "$LAST_PUSH" | sed 's/^[^ ]* [^ ]*  //')"
  FAILS="$(grep -c 'push FAILED' "$LOG" 2>/dev/null || true)"
  emit push_failures "${FAILS:-0}"
else
  emit last_check_epoch ""; emit last_check_line ""
  emit last_push_epoch ""; emit last_push_subject ""; emit push_failures ""
fi

# ----------------------------------------------------------------- workspace
if [ -d "$WS/.git" ]; then
  emit pending "$(git -C "$WS" status --porcelain -uall 2>/dev/null | wc -l | tr -d ' ')"
  emit pending_files "$(git -C "$WS" status --porcelain -uall 2>/dev/null | head -5 | sed 's/^...//' | tr '\n' ' ' | sed 's/ $//')"
  emit head_sha "$(git -C "$WS" rev-parse --short HEAD 2>/dev/null)"
  emit head_epoch "$(git -C "$WS" log -1 --format=%ct 2>/dev/null)"
  emit head_subject "$(git -C "$WS" log -1 --format=%s 2>/dev/null)"
  REMOTE_SHA="$(git -C "$WS" ls-remote origin "refs/heads/$BRANCH" 2>/dev/null | cut -c1-7)"
  emit remote_sha "$REMOTE_SHA"
  LOCAL_SHA="$(git -C "$WS" rev-parse --short HEAD 2>/dev/null)"
  [ -n "$REMOTE_SHA" ] && [ "$LOCAL_SHA" = "$REMOTE_SHA" ] && emit in_sync yes || emit in_sync no
else
  emit pending ""; emit pending_files ""; emit head_sha ""; emit head_epoch ""
  emit head_subject ""; emit remote_sha ""; emit in_sync no
fi
