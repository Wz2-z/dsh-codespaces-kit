#!/usr/bin/env bash
# =============================================================================
#  dsh-codespaces uninstall（云端半）
#
#  默认什么也不做，只打印"会删什么"。要真删得加 --yes。
#    --stop-only    只停（同步守护进程 + dsh web），不删文件
#    --remove-files 再删 /workspaces/<repo>/.dsh-cloud
#    --revoke-deploy-key  再撤销仓库里的 deploy key（用平台令牌，可能没权限）
#    --delete-codespace   再删除整个 Codespace（不可恢复！）
# =============================================================================
set -u

YES=0; STOP_ONLY=0; REMOVE_FILES=0; REVOKE_KEY=0; DELETE_CS=0
while [ $# -gt 0 ]; do
  case "$1" in
    --yes) YES=1 ;;
    --stop-only) STOP_ONLY=1 ;;
    --remove-files) REMOVE_FILES=1 ;;
    --revoke-deploy-key) REVOKE_KEY=1 ;;
    --delete-codespace) DELETE_CS=1 ;;
    *) echo "未知参数：$1"; exit 2 ;;
  esac
  shift || true
done

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
[ -n "$REPO_ROOT" ] && CLOUD_DIR="$REPO_ROOT/.dsh-cloud"
CODESPACE_NAME="${CODESPACE_NAME:-}"
[ -z "$CODESPACE_NAME" ] && [ -r /workspaces/.codespaces/shared/.env ] &&
  CODESPACE_NAME="$(grep -m1 '^CODESPACE_NAME=' /workspaces/.codespaces/shared/.env | cut -d= -f2- | tr -d '"' | tr -d '\r')"
SLUG="$(git -C "${REPO_ROOT:-/tmp}" remote get-url origin 2>/dev/null | sed 's#.*[:/]##; s#\.git$##')"

say() { printf '%s\n' "$*"; }
act() {
  if [ "$YES" = 0 ]; then say "  （预览）$*"; else say "  → $*"; fi
}

say "云端卸载清单："
act "停掉自动同步守护进程（$(pgrep -f "$CLOUD_DIR/sync[.]sh" 2>/dev/null | tr '\n' ' '))"
act "停掉 public-sync 守护进程"
act "停掉 dsh web（端口 3080 上的进程）"
if [ "$REMOVE_FILES" = 1 ] && [ -n "$CLOUD_DIR" ]; then
  act "删除 $CLOUD_DIR（start/update/sync/sync.conf 等）"
fi
if [ "$REVOKE_KEY" = 1 ]; then
  act "从 $SLUG 的 Deploy keys 里删掉名为 dsh-cloud-autosync 的公钥"
fi
if [ "$DELETE_CS" = 1 ]; then
  act "删除 Codespace $CODESPACE_NAME（不可恢复）"
fi
say "不会动：工作区 clone（~/dsh-workspace）、你的仓库内容、dsh 的 ~/.dsh 会话与凭据"

if [ "$YES" = 0 ]; then
  say ""
  say "（这是预览。要真的执行：bash cloud-uninstall.sh --yes [--remove-files] [--revoke-deploy-key] [--delete-codespace]）"
  exit 0
fi

say ""
for p in $(pgrep -f "$CLOUD_DIR/sync[.]sh" 2>/dev/null) $(pgrep -f "dsh-cloud/public-sync[.]sh" 2>/dev/null); do
  kill "$p" 2>/dev/null && say "  已停 pid $p"
done
PID="$(ss -ltnp 2>/dev/null | grep ':3080' | grep -o 'pid=[0-9]*' | head -1 | cut -d= -f2)"
[ -n "$PID" ] && kill "$PID" 2>/dev/null && say "  已停 dsh web（pid $PID）"

if [ "$REMOVE_FILES" = 1 ] && [ -n "$CLOUD_DIR" ]; then
  rm -rf "$CLOUD_DIR" && say "  已删除 $CLOUD_DIR"
fi

if [ "$REVOKE_KEY" = 1 ] && command -v gh >/dev/null 2>&1; then
  if [ -r /workspaces/.codespaces/shared/.env ]; then
    export GH_TOKEN="$(grep -m1 '^GITHUB_TOKEN=' /workspaces/.codespaces/shared/.env | cut -d= -f2- | tr -d '"' | tr -d '\r')"
  fi
  ID="$(gh api "/repos/$SLUG/keys" --jq '.[] | select(.title=="dsh-cloud-autosync") | .id' 2>/dev/null | head -1)"
  case "$ID" in
    ''|*[!0-9]*) say "  没找到名为 dsh-cloud-autosync 的 deploy key（或没权限查看）" ;;
    *) gh api -X DELETE "/repos/$SLUG/keys/$ID" >/dev/null 2>&1 &&
         say "  已撤销 deploy key（id $ID）" || say "  撤销失败：平台令牌通常没有 administration 权限，请到仓库 Settings → Deploy keys 手动删" ;;
  esac
fi

if [ "$DELETE_CS" = 1 ] && [ -n "$CODESPACE_NAME" ]; then
  if command -v gh >/dev/null 2>&1; then
    [ -r /workspaces/.codespaces/shared/.env ] &&
      export GH_TOKEN="$(grep -m1 '^GITHUB_TOKEN=' /workspaces/.codespaces/shared/.env | cut -d= -f2- | tr -d '"' | tr -d '\r')"
    gh codespace delete -c "$CODESPACE_NAME" --force >/dev/null 2>&1 &&
      say "  已删除 Codespace $CODESPACE_NAME" ||
      say "  删除失败：去 https://github.com/codespaces 手动删除"
  fi
fi

say ""
say "云端清理完成。还没动的（需要你自己决定）："
say "  · GitHub 上的 Deploy keys（Settings → Deploy keys）—— 想彻底清就删掉 dsh-cloud-autosync"
say "  · Codespace 本身 —— https://github.com/codespaces 点 Delete"
