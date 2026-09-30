#!/usr/bin/env bash
# dsh-codespaces audit（macOS / Linux 本机）—— 凭据 / 权限清单，不打印任何密钥内容
set -u
KIT_VERSION="1.7.2"
CLOUD_AUDIT_URL="https://raw.githubusercontent.com/Wz2-z/dsh-codespaces-kit/main/install/cloud-audit.sh"
BASE=""; KEY="$HOME/.ssh/dsh_cs_key"; CS=""; JSON=0
while [ $# -gt 0 ]; do
  case "$1" in
    --base) shift || true; BASE="${1:-}" ;;
    --base=*) BASE="${1#--base=}" ;;
    --key) shift || true; KEY="${1:-}" ;;
    --key=*) KEY="${1#--key=}" ;;
    --codespace) shift || true; CS="${1:-}" ;;
    --codespace=*) CS="${1#--codespace=}" ;;
    --json) JSON=1 ;;
    -h|--help) sed -n '2,4p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "未知参数：$1"; exit 2 ;;
  esac
  shift || true
done
[ -n "$BASE" ] && export GH_CONFIG_DIR="${GH_CONFIG_DIR:-$BASE/ghconfig}"

say() { printf '  ● %s\n' "$1"; [ -n "${2:-}" ] && printf '     位置：%s\n' "$2"; [ -n "${3:-}" ] && printf '     %s\n' "$3"; }
printf '\ndsh-codespaces audit  v%s\n' "$KIT_VERSION"
printf '这套工具创建的凭据 / 配置，以及各自能干什么（不显示任何密钥内容）\n'

if command -v gh >/dev/null 2>&1; then
  say "便携版 / 系统 GitHub CLI" "$(command -v gh)" "$(gh --version | head -1)"
  if gh auth status >/dev/null 2>&1; then
    say "GitHub 登录令牌" "gh 自己的配置目录" "$(gh auth status 2>&1 | sed -n 's/.*account \([^ ]*\).*/\1/p' | head -1) · 能读写你能访问的仓库并管理 Codespaces
     撤销：gh auth logout -h github.com"
  fi
else
  say "GitHub CLI" "(没有)" "跑 install/setup.sh"
fi

if [ -f "$KEY" ]; then
  say "SSH 私钥" "$KEY" "$(ssh-keygen -y -f "$KEY" 2>/dev/null | cut -d' ' -f1) · 只用来 SSH 进你自己的 Codespace
     撤销：GitHub → Settings → SSH and GPG keys 删掉公钥；本机删掉这两个文件"
else
  say "SSH 私钥" "$KEY" "（没有）"
fi

DESKTOP="$HOME/Desktop"; [ -d "$DESKTOP" ] || DESKTOP="$HOME/桌面"
FOUND=""
for f in start-dsh.command update-dsh.command; do [ -e "$DESKTOP/$f" ] && FOUND="$FOUND $f"; done
say "桌面启动器" "$DESKTOP" "${FOUND:-（没有）} · 只是链接，不含密钥"

if [ -z "$CS" ] && command -v gh >/dev/null 2>&1; then
  CS="$(gh codespace list --json name 2>/dev/null | sed -n 's/.*"name":"\([^"]*\)".*/\1/p' | head -1)"
fi
if [ -n "$CS" ] && [ -f "$KEY" ]; then
  TMP="$(mktemp "${TMPDIR:-/tmp}/cloud-audit.XXXXXX")"
  if [ -f "$(dirname "$0")/cloud-audit.sh" ]; then cp "$(dirname "$0")/cloud-audit.sh" "$TMP"
  else curl -fsSL "$CLOUD_AUDIT_URL" -o "$TMP" 2>/dev/null || true; fi
  if [ -s "$TMP" ]; then
    while IFS='|' read -r tag item where power; do
      [ "$tag" = "AUDIT" ] && say "$item" "$where" "$power"
    done < <(gh codespace ssh -c "$CS" -- -i "$KEY" 'bash -s' < "$TMP" 2>/dev/null || true)
  fi
  rm -f "$TMP"
fi

say "没被创建的东西" "" "没有账号级 PAT、没有 GitHub App、没有云厂商账号、没有 sudo 改动；
     DeepSeek API Key 只在容器 ~/.dsh/.credentials.yaml（0600）里"
printf '\n  想彻底清掉：dsh-codespaces uninstall --yes\n  详细说明：docs/security-model.md\n\n'
