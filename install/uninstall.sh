#!/usr/bin/env bash
# dsh-codespaces uninstall（macOS / Linux 本机）—— 默认只预览，--yes 才动手
set -u
KIT_VERSION="1.6.0"
CLOUD_UNINSTALL_URL="https://raw.githubusercontent.com/Wz2-z/dsh-codespaces-kit/main/install/cloud-uninstall.sh"
YES=0; LOCAL=0; PURGE_LOCAL=0; CLOUD=0; PURGE_CLOUD=0; REVOKE=0; DELETE_CS=0
KEY="$HOME/.ssh/dsh_cs_key"; CS=""
while [ $# -gt 0 ]; do
  case "$1" in
    --yes) YES=1 ;;
    --local) LOCAL=1 ;;
    --purge-local) LOCAL=1; PURGE_LOCAL=1 ;;
    --cloud) CLOUD=1 ;;
    --purge-cloud) CLOUD=1; PURGE_CLOUD=1 ;;
    --revoke-deploy-key) REVOKE=1 ;;
    --delete-codespace) DELETE_CS=1 ;;
    --key=*) KEY="${1#--key=}" ;;
    --codespace=*) CS="${1#--codespace=}" ;;
    -h|--help) sed -n '2,4p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "未知参数：$1"; exit 2 ;;
  esac
  shift || true
done

DESKTOP="$HOME/Desktop"; [ -d "$DESKTOP" ] || DESKTOP="$HOME/桌面"
SHORTCUTS="$(ls "$DESKTOP"/*dsh*.command 2>/dev/null || true)"

printf '\ndsh-codespaces uninstall  v%s\n\n' "$KIT_VERSION"
printf '会处理的：\n'
if [ "$LOCAL" = 1 ]; then
  printf '  · 删桌面启动器：%s\n' "${SHORTCUTS:-（没有）}"
  [ "$PURGE_LOCAL" = 1 ] && printf '  · 再删本机 ~/.local/share/dsh-cloud 与 %s\n' "$KEY"
else
  printf '  · 本机：跳过（没有 --local）\n'
fi
if [ "$CLOUD" = 1 ]; then
  printf '  · 云端：停同步守护进程 + dsh web%s\n' "$([ "$PURGE_CLOUD" = 1 ] && echo '、删 .dsh-cloud')"
  [ "$REVOKE" = 1 ] && printf '  · 撤销仓库里的 deploy key\n'
  [ "$DELETE_CS" = 1 ] && printf '  · 删除 Codespace（不可恢复）\n'
else
  printf '  · 云端：跳过（没有 --cloud）\n'
fi
printf '\n不会动的：GitHub 登录、仓库内容、DeepSeek API Key（删 Codespace 才没）\n'

if [ "$YES" = 0 ]; then
  printf '\n（这是预览。要真执行：--yes 并显式给出范围，比如 --local --cloud）\n\n'
  exit 0
fi

if [ "$LOCAL" = 1 ]; then
  for f in $SHORTCUTS; do rm -f "$f" && echo "  ✓ 已删 $f"; done
  if [ "$PURGE_LOCAL" = 1 ]; then
    rm -rf "$HOME/.local/share/dsh-cloud" && echo "  ✓ 已删 ~/.local/share/dsh-cloud"
    for f in "$KEY" "$KEY.pub"; do [ -e "$f" ] && rm -f "$f" && echo "  ✓ 已删 $f"; done
  fi
fi

if [ "$CLOUD" = 1 ] && command -v gh >/dev/null 2>&1; then
  [ -z "$CS" ] && CS="$(gh codespace list --json name 2>/dev/null | sed -n 's/.*"name":"\([^"]*\)".*/\1/p' | head -1)"
  if [ -n "$CS" ] && [ -f "$KEY" ]; then
    TMP="$(mktemp "${TMPDIR:-/tmp}/cloud-uninstall.XXXXXX")"
    if [ -f "$(dirname "$0")/cloud-uninstall.sh" ]; then cp "$(dirname "$0")/cloud-uninstall.sh" "$TMP"
    else curl -fsSL "$CLOUD_UNINSTALL_URL" -o "$TMP" 2>/dev/null || true; fi
    if [ -s "$TMP" ]; then
      FLAGS="--yes"
      [ "$PURGE_CLOUD" = 1 ] && FLAGS="$FLAGS --remove-files"
      [ "$REVOKE" = 1 ] && FLAGS="$FLAGS --revoke-deploy-key"
      [ "$DELETE_CS" = 1 ] && FLAGS="$FLAGS --delete-codespace"
      gh codespace ssh -c "$CS" -- -i "$KEY" "bash -s - $FLAGS" < "$TMP" 2>&1 | sed 's/^/  /'
    fi
    rm -f "$TMP"
  fi
fi

printf '\n剩下的手动步骤（如果有）：\n'
printf '  · 退出 GitHub 登录：gh auth logout -h github.com\n'
printf '  · 删 Codespace：https://github.com/codespaces\n\n'
