#!/usr/bin/env bash
# dsh-codespaces <command> —— macOS / Linux 入口
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
CMD="${1:-}"
[ $# -gt 0 ] && shift

case "$CMD" in
  doctor) exec bash "$HERE/doctor.sh" "$@" ;;
  status) exec bash "$HERE/status.sh" "$@" ;;
  audit)  exec bash "$HERE/audit.sh" "$@" ;;
  setup)  exec bash "$HERE/setup.sh" "$@" ;;
  repair)
    echo "[repair] re-running setup (idempotent), then doctor ..."
    bash "$HERE/setup.sh" "$@"; rc=$?
    bash "$HERE/doctor.sh" "$@"
    exit $rc
    ;;
  update) exec bash "$HERE/update.sh" "$@" ;;
  uninstall) exec bash "$HERE/uninstall.sh" "$@" ;;
  ""|-h|--help|help)
    cat <<'USAGE'
  dsh-codespaces status     one screen: codespace / tunnel / dsh / sync / last push / pending
  dsh-codespaces doctor     check GitHub CLI / Codespace / DSH / SSH / tunnel / sync ... (12 items)
  dsh-codespaces audit      what keys / tokens / configs exist, what each can do
  dsh-codespaces setup      install everything (first time)
  dsh-codespaces repair     re-run setup (idempotent) then doctor
  dsh-codespaces update     upgrade dsh in the cloud and reopen the tunnel
  dsh-codespaces uninstall  preview removal; add --yes and scope flags to actually do it

  Examples:
    dsh-codespaces status
    dsh-codespaces doctor
    dsh-codespaces doctor --no-tunnel
    dsh-codespaces audit
    dsh-codespaces setup --repo=your-name/your-repo
    dsh-codespaces uninstall
    dsh-codespaces uninstall --yes --local --cloud
USAGE
    [ -n "$CMD" ] && exit 0 || exit 1
    ;;
  *) echo "未知命令：$CMD（试试 dsh-codespaces help）"; exit 2 ;;
esac
