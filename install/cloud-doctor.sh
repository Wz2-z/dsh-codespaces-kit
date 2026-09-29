#!/usr/bin/env bash
# =============================================================================
#  dsh-codespaces doctor（云端半）—— 在 Codespaces 容器里跑，输出机器可读的检查结果
#
#  由 install/doctor.ps1 / install/doctor.sh 通过 stdin 送进来执行：
#      gh codespace ssh -c <名字> -- "bash -s" < cloud-doctor.sh
#
#  每行格式：CHECK|<名字>|ok|warn|fail|<说明>
#  这一半不看本机的东西（本机那半由 doctor.ps1 / doctor.sh 负责）。
# =============================================================================
set -u

emit() { printf 'CHECK|%s|%s|%s\n' "$1" "$2" "$3"; }

# ---------------------------------------------------------------- Codespace
# 本机那半已经确认过 Codespace 了（能 SSH 进来就是证明），这里不再重复一行。
CODESPACE_NAME="${CODESPACE_NAME:-}"
if [ -z "$CODESPACE_NAME" ] && [ -r /workspaces/.codespaces/shared/.env ]; then
  CODESPACE_NAME="$(grep -m1 '^CODESPACE_NAME=' /workspaces/.codespaces/shared/.env 2>/dev/null | cut -d= -f2- | tr -d '"' | tr -d '\r')"
fi
if [ -z "$CODESPACE_NAME" ] && [ ! -d /workspaces/.codespaces ]; then
  emit Codespace fail "这里不是 Codespace 容器"
fi

# ------------------------------------------------------------------- 仓库
REPO_ROOT="${GITHUB_WORKSPACE:-}"
if [ -z "$REPO_ROOT" ] || [ ! -d "$REPO_ROOT/.git" ]; then
  REPO_ROOT=""
  for d in /workspaces/*/.git; do
    [ -d "$d" ] || continue
    REPO_ROOT="$(dirname "$d")"
    break
  done
fi
if [ -n "$REPO_ROOT" ] && [ -d "$REPO_ROOT/.git" ]; then
  CLOUD_DIR="$REPO_ROOT/.dsh-cloud"
  BRANCH="$(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || echo main)"
  [ "$BRANCH" = "HEAD" ] && BRANCH="main"
else
  CLOUD_DIR=""
  BRANCH="main"
fi

# --------------------------------------------------------------------- dsh
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
if [ -n "$DSH_DIR" ]; then
  emit DSH ok "$("$DSH_DIR/dsh" --version 2>/dev/null || echo '版本未知')（$DSH_DIR）"
else
  emit DSH fail "没找到 dsh，跑 install/cloud-setup.sh 装一下"
fi

# --------------------------------------------------------------- workspace
WS="${DSH_WORKSPACE:-$HOME/dsh-workspace}"
if [ ! -d "$WS/.git" ]; then
  emit Workspace fail "没有工作区：$WS"
else
  DIRTY="$(git -C "$WS" status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
  HEAD_SHA="$(git -C "$WS" rev-parse --short HEAD 2>/dev/null)"
  REMOTE_SHA="$(git -C "$WS" ls-remote origin "refs/heads/$BRANCH" 2>/dev/null | cut -c1-7)"
  if [ "$DIRTY" = "0" ] && [ -n "$REMOTE_SHA" ] && [ "$HEAD_SHA" = "$REMOTE_SHA" ]; then
    emit Workspace ok "干净，HEAD=$HEAD_SHA（与远端一致）"
  elif [ "${DIRTY:-0}" != "0" ]; then
    emit Workspace warn "$DIRTY 个未提交改动（等自动同步，或 sync.sh --now）"
  else
    emit Workspace warn "本地 $HEAD_SHA / 远端 ${REMOTE_SHA:-?} 不一致"
  fi
fi

# -------------------------------------------------------------- deploy key
KEY="$HOME/.ssh/dsh_deploy"
if [ ! -f "$KEY" ]; then
  emit "Deploy key" fail "没有 $KEY（跑 cloud-setup.sh 生成）"
elif git -C "$WS" ls-remote origin "refs/heads/$BRANCH" >/dev/null 2>&1; then
  emit "Deploy key" ok "ed25519，能读写 $(git -C "$WS" remote get-url origin 2>/dev/null | sed 's#.*[:/]##; s#\.git$##')"
else
  emit "Deploy key" fail "有密钥但连不上仓库（公钥没加到 Deploy keys？）"
fi

# --------------------------------------------------------------- auto sync
if [ -z "$CLOUD_DIR" ] || [ ! -x "$CLOUD_DIR/sync.sh" ]; then
  emit "Auto sync" fail "没有 $CLOUD_DIR/sync.sh"
  emit "Sync config" fail "缺少 sync.conf（跑 cloud-setup.sh 生成）"
else
  PIDS="$(pgrep -f "$CLOUD_DIR/sync[.]sh" 2>/dev/null | tr '\n' ' ' | sed 's/ $//')"
  MODE="$(grep -m1 '^mode=' "$CLOUD_DIR/sync.conf" 2>/dev/null | cut -d= -f2 | tr -d ' ')"
  ENABLED="$(grep -m1 '^enabled=' "$CLOUD_DIR/sync.conf" 2>/dev/null | cut -d= -f2 | tr -d ' ')"
  LAST="$(tail -n 1 "$HOME/dsh-sync.log" 2>/dev/null | cut -c1-19)"
  if [ -n "$PIDS" ] && [ "$ENABLED" != "off" ]; then
    emit "Auto sync" ok "守护进程 pid $PIDS · 模式 $MODE · 最近一条日志 ${LAST:-无}"
  elif [ -n "$PIDS" ]; then
    emit "Auto sync" warn "守护进程在跑，但已暂停（sync.sh --enable 恢复）"
  else
    emit "Auto sync" fail "守护进程没在跑（bash $CLOUD_DIR/start.sh 拉起）"
  fi

  SQUASH="$(grep -m1 '^squash_window_seconds=' "$CLOUD_DIR/sync.conf" 2>/dev/null | cut -d= -f2 | tr -d ' ')"
  IDLE="$(grep -m1 '^idle_seconds=' "$CLOUD_DIR/sync.conf" 2>/dev/null | cut -d= -f2 | tr -d ' ')"
  if [ -z "$MODE" ]; then
    emit "Sync config" fail "sync.conf 里没有 mode"
  elif [ "$ENABLED" = "off" ]; then
    emit "Sync config" warn "enabled=off · mode=$MODE（自动同步已暂停）"
  else
    emit "Sync config" ok "mode=$MODE · 静默 ${IDLE:-?}s · 折叠 ${SQUASH:-0}s"
  fi
fi

# --------------------------------------------------------------- dsh 进程
if [ -n "$RUN_PID" ]; then
  CODE="$(curl -s -o /dev/null -w '%{http_code}' -m 3 http://127.0.0.1:3080/ 2>/dev/null || echo 000)"
  case "$CODE" in
    401) emit "dsh web" ok "监听 127.0.0.1:3080，需要 token（401 = 正常）" ;;
    200) emit "dsh web" warn "监听中，但无 token 也放行（200），建议检查认证" ;;
    *)   emit "dsh web" warn "3080 返回 $CODE，看 ~/dsh-web.log" ;;
  esac
else
  emit "dsh web" fail "3080 上没有进程（bash $CLOUD_DIR/start.sh 拉起）"
fi
