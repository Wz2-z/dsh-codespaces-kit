#!/usr/bin/env bash
# dsh-codespaces status（macOS / Linux 本机）
# 用法： bash install/status.sh [--base=DIR] [--key=PATH] [--codespace=NAME] [--quick] [--json]
set -u
KIT_VERSION="1.7.2"
CLOUD_STATUS_URL="https://raw.githubusercontent.com/Wz2-z/dsh-codespaces-kit/main/install/cloud-status.sh"
BASE=""; KEY="$HOME/.ssh/dsh_cs_key"; CS=""; QUICK=0; JSON=0
while [ $# -gt 0 ]; do
  case "$1" in
    --base) shift || true; BASE="${1:-}" ;;
    --base=*) BASE="${1#--base=}" ;;
    --key) shift || true; KEY="${1:-}" ;;
    --key=*) KEY="${1#--key=}" ;;
    --codespace) shift || true; CS="${1:-}" ;;
    --codespace=*) CS="${1#--codespace=}" ;;
    --quick|--no-tunnel) QUICK=1 ;;
    --json) JSON=1 ;;
    -h|--help) sed -n '2,4p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "未知参数：$1"; exit 2 ;;
  esac
  shift || true
done
if [ -n "$BASE" ]; then
  export GH_CONFIG_DIR="${GH_CONFIG_DIR:-$BASE/ghconfig}"
  [ -x "$BASE/gh/bin/gh" ] && PATH="$BASE/gh/bin:$PATH"
fi

declare -A C=()
if [ -n "$CS" ] || command -v gh >/dev/null 2>&1; then
  [ -z "$CS" ] && CS="$(gh codespace list --json name 2>/dev/null | sed -n 's/.*"name":"\([^"]*\)".*/\1/p' | head -1)"
  if [ -n "$CS" ] && [ -f "$KEY" ]; then
    TMP="$(mktemp "${TMPDIR:-/tmp}/cloud-status.XXXXXX")"
    if [ -f "$(dirname "$0")/cloud-status.sh" ]; then cp "$(dirname "$0")/cloud-status.sh" "$TMP"
    else curl -fsSL "$CLOUD_STATUS_URL" -o "$TMP" 2>/dev/null || true; fi
    if [ -s "$TMP" ]; then
      while IFS='|' read -r tag k v; do [ "$tag" = "STATUS" ] && C["$k"]="$v"; done < <(gh codespace ssh -c "$CS" -- -i "$KEY" 'bash -s' < "$TMP" 2>/dev/null || true)
    fi
    rm -f "$TMP"
  fi
fi

TUNNEL="Skipped"
if [ "$QUICK" = 0 ] && [ -n "$CS" ] && [ -f "$KEY" ]; then
  ( gh codespace ports forward 3080:3080 -c "$CS" >/dev/null 2>&1 & ) ; sleep 6
  CODE="$(curl -s -o /dev/null -w '%{http_code}' -m 8 http://127.0.0.1:3080/ || echo 000)"
  case "$CODE" in 401|200) TUNNEL="Healthy" ;; 000) TUNNEL="Down" ;; *) TUNNEL="Degraded" ;; esac
  pkill -f "ports forward 3080:3080" 2>/dev/null || true
fi

age() {
  [ -z "${1:-}" ] && { echo '—'; return; }
  local s=$(( $(date +%s) - $1 ))
  if [ "$s" -lt 60 ]; then echo "${s} seconds ago"
  elif [ "$s" -lt 3600 ]; then echo "$((s / 60)) minute(s) ago"
  elif [ "$s" -lt 86400 ]; then echo "$((s / 3600)) hour(s) ago"
  else echo "$((s / 86400)) day(s) ago"; fi
}

if [ "$JSON" = 1 ]; then
  printf '{"version":"%s","codespace":"%s","tunnel":"%s","dsh":"%s","sync":"%s","pending":"%s","last_push":"%s","in_sync":"%s"}\n' \
    "$KIT_VERSION" "$CS" "$TUNNEL" "${C[dsh_version]:-}" "${C[mode]:-}" "${C[pending]:-}" "$(age "${C[last_push_epoch]:-}")" "${C[in_sync]:-}"
  exit 0
fi

printf '\ndsh-codespaces status  v%s\n\n' "$KIT_VERSION"
printf '  %-16s%s\n' 'Codespace' "${CS:-没有可用的 Codespace}"
printf '  %-16s%s\n' 'Tunnel' "$TUNNEL"
printf '  %-16s%s\n' 'DSH' "${C[dsh_version]:-?} · pid ${C[dsh_pid]:-?} · HTTP ${C[dsh_http]:-?}"
printf '  %-16s%s\n' 'Auto sync' "${C[mode]:-?} · ${C[enabled]:-?} · daemon pid ${C[daemon_pids]:-none} · 静默 ${C[idle]:-?}s · 折叠 ${C[squash]:-0}s"
printf '  %-16s%s\n' 'Last check' "$(age "${C[last_check_epoch]:-}")"
printf '  %-16s%s\n' 'Last push' "$(age "${C[last_push_epoch]:-}") · ${C[last_push_subject]:-—}"
printf '  %-16s%s\n' 'Last commit' "${C[head_sha]:-—} · $(age "${C[head_epoch]:-}") · ${C[head_subject]:-—}"
printf '  %-16s%s\n' 'Pending files' "${C[pending]:-?} ${C[pending_files]:+(}${C[pending_files]:-}${C[pending_files]:+)}"
printf '  %-16s%s\n\n' 'In sync' "${C[in_sync]:-?}（本地 ${C[head_sha]:-?} / 远端 ${C[remote_sha]:-?}）"
