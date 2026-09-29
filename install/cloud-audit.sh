#!/usr/bin/env bash
# =============================================================================
#  dsh-codespaces audit（云端半）—— 云端有哪些凭据、各自能干什么
#
#  只报"有什么、在哪、权限多大"，**不打印任何密钥/令牌内容**。
#  输出：AUDIT|<项目>|<位置>|<权限或说明>
# =============================================================================
set -u

emit() { printf 'AUDIT|%s|%s|%s\n' "$1" "$2" "$3"; }

REPO_ROOT="${GITHUB_WORKSPACE:-}"
if [ -z "$REPO_ROOT" ] || [ ! -d "$REPO_ROOT/.git" ]; then
  REPO_ROOT=""
  for d in /workspaces/*/.git; do
    [ -d "$d" ] || continue
    REPO_ROOT="$(dirname "$d")"
    break
  done
fi
SLUG="$(git -C "${REPO_ROOT:-/tmp}" remote get-url origin 2>/dev/null | sed 's#.*[:/]##; s#\.git$##')"
WS="${DSH_WORKSPACE:-$HOME/dsh-workspace}"
BRANCH="$(git -C "$WS" rev-parse --abbrev-ref HEAD 2>/dev/null || echo main)"
[ "$BRANCH" = "HEAD" ] && BRANCH="main"

# -------------------------------------------------------------- deploy key
KEY="$HOME/.ssh/dsh_deploy"
if [ -f "$KEY" ]; then
  FP="$(ssh-keygen -lf "$KEY.pub" 2>/dev/null | awk '{print $2}')"
  if git -C "$WS" ls-remote origin "refs/heads/$BRANCH" >/dev/null 2>&1; then
    emit "deploy key" "$KEY" "只对 ${SLUG:-这个仓库} 有写权限 · 指纹 ${FP:-?} · 实测可读写 ✓"
  else
    emit "deploy key" "$KEY" "只对 ${SLUG:-这个仓库} 有写权限 · 指纹 ${FP:-?} · 实测连不上 ✗"
  fi
else
  emit "deploy key" "$KEY" "不存在"
fi

# ------------------------------------------------------- dsh 自己的凭据
CRED="${DSH_HOME:-$HOME/.dsh}/.credentials.yaml"
if [ -f "$CRED" ]; then
  MODE="$(stat -c '%a' "$CRED" 2>/dev/null)"
  NAMES="$(grep -oE '^[A-Za-z0-9_-]+:' "$CRED" 2>/dev/null | tr -d ':' | tr -d '\r' | paste -sd', ' -)"
  emit "dsh 凭据" "$CRED" "权限 $MODE（应 600）· 文件结构：${NAMES:-（空）}（provider 名在 records 里，不打印）—— API Key 只在这台容器里"
else
  emit "dsh 凭据" "$CRED" "不存在（还没在 dsh 里填过 API Key）"
fi

# ------------------------------------------------- Codespaces 平台令牌
ENV="/workspaces/.codespaces/shared/.env"
if [ -r "$ENV" ]; then
  NAMES="$(cut -d= -f1 "$ENV" 2>/dev/null | tr -d '\r' | grep -E 'TOKEN|REPOSITORY|^CODESPACE_NAME$' | sort -u | paste -sd', ' -)"
  emit "平台令牌" "$ENV" "Codespaces 自带（$NAMES）· 随容器销毁而失效，不用你撤销"
else
  emit "平台令牌" "$ENV" "读不到"
fi

# ----------------------------------------------------------- 云端的脚本
if [ -n "$REPO_ROOT" ] && [ -d "$REPO_ROOT/.dsh-cloud" ]; then
  FILES="$(ls "$REPO_ROOT/.dsh-cloud" 2>/dev/null | tr -d '\r' | paste -sd', ' -)"
  emit "云端脚本" "$REPO_ROOT/.dsh-cloud" "$FILES · 不含任何凭据"
fi

# ----------------------------------------------------------- 本仓库的 remote
if [ -n "$REPO_ROOT" ]; then
  URL="$(git -C "$REPO_ROOT" remote get-url origin 2>/dev/null)"
  emit "工作区 remote" "$URL" "同步用它推送（走 deploy key，不用你的账号令牌）"
fi
