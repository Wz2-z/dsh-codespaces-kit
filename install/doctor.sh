#!/usr/bin/env bash
# =============================================================================
#  dsh-codespaces doctor（macOS / Linux 本机）
#
#  用法： bash install/doctor.sh [--repo=owner/name] [--codespace=名字] [--key=路径] [--no-tunnel] [--json]
# =============================================================================
set -u

KIT_VERSION="1.7.1"
CLOUD_DOCTOR_URL="https://raw.githubusercontent.com/Wz2-z/dsh-codespaces-kit/main/install/cloud-doctor.sh"

REPO=""; CODESPACE=""; KEY="$HOME/.ssh/dsh_cs_key"; NO_TUNNEL=0; JSON=0
while [ $# -gt 0 ]; do
  case "$1" in
    --repo) shift || true; REPO="${1:-}" ;;
    --repo=*) REPO="${1#--repo=}" ;;
    --codespace) shift || true; CODESPACE="${1:-}" ;;
    --codespace=*) CODESPACE="${1#--codespace=}" ;;
    --key) shift || true; KEY="${1:-}" ;;
    --key=*) KEY="${1#--key=}" ;;
    --no-tunnel) NO_TUNNEL=1 ;;
    --json) JSON=1 ;;
    -h|--help) sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "未知参数：$1"; exit 2 ;;
  esac
  shift || true
done

declare -a NAMES=() STATUSES=() DETAILS=()
add() { NAMES+=("$1"); STATUSES+=("$2"); DETAILS+=("$3"); }

# ---------------------------------------------------------------- GitHub CLI
if command -v gh >/dev/null 2>&1; then
  add "GitHub CLI" ok "$(gh --version | head -1)"
else
  add "GitHub CLI" fail "没找到 gh（brew install gh / sudo apt install gh）"
fi

# ------------------------------------------------------------------ 认证
if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
  add "GitHub authentication" ok "已登录：$(gh auth status 2>&1 | sed -n 's/.*account \([^ ]*\).*/\1/p' | head -1)"
else
  add "GitHub authentication" fail "没登录（gh auth login --scopes codespace,repo,read:org,workflow）"
fi

# ---------------------------------------------------------------- SSH 密钥
KEY_OK=0
if [ -f "$KEY" ]; then
  if ssh-keygen -y -f "$KEY" >/dev/null 2>&1; then
    KEY_OK=1
    add "SSH key" ok "$KEY（可读）"
  else
    add "SSH key" fail "$KEY 读不了（权限：chmod 600）"
  fi
else
  add "SSH key" fail "没有 $KEY（跑 install/setup.sh 生成）"
fi

# ---------------------------------------------------------------- Codespace
CS="$CODESPACE"
if [ -z "$CS" ] && command -v gh >/dev/null 2>&1; then
  LIST="$(gh codespace list --json name,state,repository 2>/dev/null || echo '[]')"
  if [ -n "$REPO" ]; then
    CS="$(printf '%s' "$LIST" | tr '{' '\n' | grep -F "\"$REPO\"" | sed -n 's/.*"name":"\([^"]*\)".*/\1/p' | head -1)"
  fi
  [ -z "$CS" ] && CS="$(printf '%s' "$LIST" | sed -n 's/.*"name":"\([^"]*\)".*/\1/p' | head -1)"
fi
if [ -n "$CS" ]; then
  add "Codespace" ok "$CS"
else
  add "Codespace" fail "没有可用的 Codespace"
fi

# ------------------------------------------------------------------ 云端
if [ -n "$CS" ] && [ "$KEY_OK" = 1 ] && command -v gh >/dev/null 2>&1; then
  TMP="$(mktemp "${TMPDIR:-/tmp}/cloud-doctor.XXXXXX")"
  if [ -f "$(dirname "$0")/cloud-doctor.sh" ]; then
    cp "$(dirname "$0")/cloud-doctor.sh" "$TMP"
  else
    curl -fsSL "$CLOUD_DOCTOR_URL" -o "$TMP" 2>/dev/null || true
  fi
  if [ -s "$TMP" ]; then
    CLOUD_OUT="$(gh codespace ssh -c "$CS" -- -i "$KEY" 'bash -s' < "$TMP" 2>/dev/null || true)"
    while IFS='|' read -r tag name status detail; do
      [ "$tag" = "CHECK" ] && add "$name" "$status" "$detail"
    done <<< "$CLOUD_OUT"
  else
    add "Cloud checks" warn "拿不到 cloud-doctor.sh"
  fi
  rm -f "$TMP"
else
  add "Cloud checks" warn "跳过（缺 gh / 密钥 / Codespace）"
fi

# ------------------------------------------------------------------- 隧道
if [ "$NO_TUNNEL" = 1 ]; then
  add "Tunnel" warn "按 --no-tunnel 跳过"
elif [ -n "$CS" ] && [ "$KEY_OK" = 1 ] && command -v gh >/dev/null 2>&1; then
  ( gh codespace ports forward 3080:3080 -c "$CS" >/dev/null 2>&1 & )
  sleep 7
  CODE="$(curl -s -o /dev/null -w '%{http_code}' -m 8 http://127.0.0.1:3080/ || echo 000)"
  case "$CODE" in
    401) add "Tunnel" ok "127.0.0.1:3080 → 401（需要 token，正常）" ;;
    200) add "Tunnel" ok "127.0.0.1:3080 → 200" ;;
    *)   add "Tunnel" fail "127.0.0.1:3080 没通（返回 $CODE）" ;;
  esac
  pkill -f "ports forward 3080:3080" 2>/dev/null || true
else
  add "Tunnel" warn "跳过（缺 gh / 密钥 / Codespace）"
fi

# ------------------------------------------------------------- 桌面启动器
DESKTOP="$HOME/Desktop"; [ -d "$DESKTOP" ] || DESKTOP="$HOME/桌面"
COUNT=0
for f in "start-dsh.command" "update-dsh.command"; do
  [ -e "$DESKTOP/$f" ] && COUNT=$((COUNT + 1))
done
if [ "$COUNT" -ge 2 ]; then
  add "Launcher" ok "桌面有 $COUNT 个启动器"
elif [ "$COUNT" = 1 ]; then
  add "Launcher" warn "桌面只有 1 个启动器"
else
  add "Launcher" warn "桌面没有启动器（install/setup.sh 会生成）"
fi

# -------------------------------------------------------------------- 输出
ok=0; warn=0; fail=0
for s in "${STATUSES[@]}"; do
  case "$s" in ok) ok=$((ok+1)) ;; warn) warn=$((warn+1)) ;; *) fail=$((fail+1)) ;; esac
done
total=${#STATUSES[@]}

if [ "$JSON" = 1 ]; then
  printf '{"version":"%s","passed":%s,"warnings":%s,"failed":%s,"total":%s,"checks":[' \
    "$KIT_VERSION" "$ok" "$warn" "$fail" "$total"
  for i in "${!NAMES[@]}"; do
    [ "$i" -gt 0 ] && printf ','
    printf '{"name":"%s","status":"%s","detail":"%s"}' "${NAMES[$i]}" "${STATUSES[$i]}" "${DETAILS[$i]}"
  done
  printf ']}\n'
else
  printf '\ndsh-codespaces doctor  v%s\n\n' "$KIT_VERSION"
  order=("GitHub CLI" "GitHub authentication" "Codespace" "DSH" "SSH key" \
         "Workspace" "Deploy key" "Auto sync" "Sync config" "dsh web" "Tunnel" "Launcher")
  shown=()
  for want in "${order[@]}"; do
    for i in "${!NAMES[@]}"; do
      [ "${NAMES[$i]}" = "$want" ] && shown+=("$i")
    done
  done
  for i in "${!NAMES[@]}"; do
    skip=0
    for s in "${shown[@]}"; do [ "$s" = "$i" ] && skip=1; done
    [ "$skip" = 1 ] || shown+=("$i")
  done
  for i in "${shown[@]}"; do
    case "${STATUSES[$i]}" in
      ok)   mark='✓'; color='\033[32m' ;;
      warn) mark='!'; color='\033[33m' ;;
      *)    mark='✗'; color='\033[31m' ;;
    esac
    printf '  %-24s %b%s\033[0m  \033[90m%s\033[0m\n' "${NAMES[$i]}" "$color" "$mark" "${DETAILS[$i]}"
  done
  printf '\n  %s/%s checks passed' "$ok" "$total"
  [ "$warn" -gt 0 ] && printf ' · %s warning(s)' "$warn"
  [ "$fail" -gt 0 ] && printf ' · %s failed' "$fail"
  printf '\n\n'
fi

[ "$fail" -gt 0 ] && exit 1
exit 0
