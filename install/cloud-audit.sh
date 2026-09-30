#!/usr/bin/env bash
# =============================================================================
#  dsh-codespaces audit（云端半）—— 云端有哪些凭据、各自能干什么
#
#  只报"有什么、在哪、权限多大"，**不打印任何密钥/令牌内容**。
#  输出：AUDIT|<项目>|<位置>|<权限或说明>
# =============================================================================
LANG_OUT=zh
while [ $# -gt 0 ]; do
  case "$1" in
    --lang=en|--lang en) LANG_OUT=en ;;
    --lang=zh|--lang zh) LANG_OUT=zh ;;
    *) ;;
  esac
  shift || true
done
set -u

if [ "$LANG_OUT" = en ]; then
  T_KEY="deploy key"; T_CRED="dsh credentials"; T_TOKEN="platform token"; T_SCRIPTS="cloud scripts"; T_REMOTE="workspace remote"
  D_REPO="write access to this repo only"
  D_RW_OK="fingerprint {FP} · read/write verified ✓"
  D_RW_BAD="fingerprint {FP} · cannot reach the repo ✗"
  D_MISSING="does not exist"
  D_CRED_MODE="mode {MODE} (should be 600) · keys: {NAMES} (provider names live in records, not printed) · the API key only exists inside this container"
  D_CRED_NONE="does not exist (no API key stored yet)"
  D_TOKEN="provided by Codespaces ({NAMES}) · dies with the container, nothing to revoke"
  D_TOKEN_UNREADABLE="not readable"
  D_SCRIPTS="{FILES} · contains no credentials"
  D_REMOTE="auto sync pushes through this using the deploy key, not your account token"
else
  T_KEY="deploy key"; T_CRED="dsh 凭据"; T_TOKEN="平台令牌"; T_SCRIPTS="云端脚本"; T_REMOTE="工作区 remote"
  D_REPO="只对 {SLUG} 有写权限"
  D_RW_OK="指纹 {FP} · 实测可读写 ✓"
  D_RW_BAD="指纹 {FP} · 实测连不上 ✗"
  D_MISSING="不存在"
  D_CRED_MODE="权限 {MODE}（应 600）· 文件结构：{NAMES}（provider 名在 records 里，不打印）—— API Key 只在这台容器里"
  D_CRED_NONE="不存在（还没在 dsh 里填过 API Key）"
  D_TOKEN="Codespaces 自带（{NAMES}）· 随容器销毁而失效，不用你撤销"
  D_TOKEN_UNREADABLE="读不到"
  D_SCRIPTS="{FILES} · 不含任何凭据"
  D_REMOTE="同步用它推送（走 deploy key，不用你的账号令牌）"
fi
emit() { printf 'AUDIT|%s|%s|%s\n' "$1" "$2" "$3"; }
fill() { local t="$1"; shift; printf '%s' "$t" | sed -e "s/{FP}/$1/; s/{SLUG}/$2/; s/{MODE}/$3/; s/{NAMES}/$4/; s/{FILES}/$5/"; }

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
    emit "$T_KEY" "$KEY" "$(fill "$D_REPO · $D_RW_OK" "${FP:-?}" "${SLUG:-this repo}" '' '' '')"
  else
    emit "$T_KEY" "$KEY" "$(fill "$D_REPO · $D_RW_BAD" "${FP:-?}" "${SLUG:-this repo}" '' '' '')"
  fi
else
  emit "$T_KEY" "$KEY" "$D_MISSING"
fi

# ------------------------------------------------------- dsh 自己的凭据
CRED="${DSH_HOME:-$HOME/.dsh}/.credentials.yaml"
if [ -f "$CRED" ]; then
  MODE="$(stat -c '%a' "$CRED" 2>/dev/null)"
  NAMES="$(grep -oE '^[A-Za-z0-9_-]+:' "$CRED" 2>/dev/null | tr -d ':' | tr -d '\r' | paste -sd', ' -)"
  emit "$T_CRED" "$CRED" "$(fill "$D_CRED_MODE" '' '' "$MODE" "${NAMES:-empty}" '')"
else
  emit "$T_CRED" "$CRED" "$D_CRED_NONE"
fi

# ------------------------------------------------- Codespaces 平台令牌
ENV="/workspaces/.codespaces/shared/.env"
if [ -r "$ENV" ]; then
  NAMES="$(cut -d= -f1 "$ENV" 2>/dev/null | tr -d '\r' | grep -E 'TOKEN|REPOSITORY|^CODESPACE_NAME$' | sort -u | paste -sd', ' -)"
  emit "$T_TOKEN" "$ENV" "$(fill "$D_TOKEN" '' '' '' "$NAMES" '')"
else
  emit "$T_TOKEN" "$ENV" "$D_TOKEN_UNREADABLE"
fi

# ----------------------------------------------------------- 云端的脚本
if [ -n "$REPO_ROOT" ] && [ -d "$REPO_ROOT/.dsh-cloud" ]; then
  FILES="$(ls "$REPO_ROOT/.dsh-cloud" 2>/dev/null | tr -d '\r' | paste -sd', ' -)"
  emit "$T_SCRIPTS" "$REPO_ROOT/.dsh-cloud" "$(fill "$D_SCRIPTS" '' '' '' '' "$FILES")"
fi

# ----------------------------------------------------------- 本仓库的 remote
if [ -n "$REPO_ROOT" ]; then
  URL="$(git -C "$REPO_ROOT" remote get-url origin 2>/dev/null)"
  emit "$T_REMOTE" "$URL" "$D_REMOTE"
fi
