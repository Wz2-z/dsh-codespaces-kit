#!/usr/bin/env bash
# dsh-codespaces update（macOS / Linux）—— 升级云端 dsh 并重建隧道
set -u
KIT_VERSION="1.5.0"
BASE=""; KEY="$HOME/.ssh/dsh_cs_key"; CS=""; NO_OPEN=0
while [ $# -gt 0 ]; do
  case "$1" in
    --base) shift || true; BASE="${1:-}" ;;
    --base=*) BASE="${1#--base=}" ;;
    --key) shift || true; KEY="${1:-}" ;;
    --key=*) KEY="${1#--key=}" ;;
    --codespace) shift || true; CS="${1:-}" ;;
    --codespace=*) CS="${1#--codespace=}" ;;
    --no-open) NO_OPEN=1 ;;
    *) echo "未知参数：$1"; exit 2 ;;
  esac
  shift || true
done
[ -n "$BASE" ] && { export GH_CONFIG_DIR="${GH_CONFIG_DIR:-$BASE/ghconfig}"; [ -x "$BASE/gh/bin/gh" ] && PATH="$BASE/gh/bin:$PATH"; }
command -v gh >/dev/null 2>&1 || { echo "缺少 gh"; exit 1; }

[ -z "$CS" ] && CS="$(gh codespace list --json name 2>/dev/null | sed -n 's/.*"name":"\([^"]*\)".*/\1/p' | head -1)"
[ -n "$CS" ] || { echo "找不到 Codespace"; exit 1; }
REPO_NAME="$(gh codespace list --json name,repository 2>/dev/null | tr '{' '\n' | grep -F "\"$CS\"" | sed -n 's/.*"repository":"\([^"]*\)".*/\1/p' | head -1)"
REPO_NAME="${REPO_NAME##*/}"

printf '\ndsh-codespaces update  v%s\n升级云端 dsh（%s）…\n\n' "$KIT_VERSION" "$CS"
OUT="$(mktemp "${TMPDIR:-/tmp}/dsh-update.XXXXXX")"
gh codespace ssh -c "$CS" -- -i "$KEY" "bash /workspaces/$REPO_NAME/.dsh-cloud/update.sh" 2>&1 | tee "$OUT"
( gh codespace ports forward 3080:3080 -c "$CS" >/dev/null 2>&1 & )
sleep 8
if [ "$NO_OPEN" = 0 ]; then
  URL="$(grep -a -o 'http://127.0.0.1:3080[^ ]*' "$OUT" | tail -1)"
  [ -z "$URL" ] && URL='http://127.0.0.1:3080'
  (xdg-open "$URL" >/dev/null 2>&1 || open "$URL" >/dev/null 2>&1 || echo "打开这个地址：$URL") &
fi
rm -f "$OUT"
printf '\n完成。\n\n'
