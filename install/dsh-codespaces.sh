#!/usr/bin/env bash
# dsh-codespaces <command> —— macOS / Linux 入口
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
CMD="${1:-}"
[ $# -gt 0 ] && shift

case "$CMD" in
  doctor) exec bash "$HERE/doctor.sh" "$@" ;;
  setup)  exec bash "$HERE/setup.sh" "$@" ;;
  ""|-h|--help|help)
    cat <<'USAGE'
  dsh-codespaces doctor     check GitHub CLI / Codespace / DSH / SSH / tunnel / sync ...
  dsh-codespaces setup      install or repair everything

  Examples:
    dsh-codespaces doctor
    dsh-codespaces doctor --no-tunnel
    dsh-codespaces setup --repo=your-name/your-repo
USAGE
    [ -n "$CMD" ] && exit 0 || exit 1
    ;;
  *) echo "未知命令：$CMD（试试 dsh-codespaces help）"; exit 2 ;;
esac
