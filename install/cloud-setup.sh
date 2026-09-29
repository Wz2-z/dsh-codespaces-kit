#!/usr/bin/env bash
# =============================================================================
#  DeepSeek Harness (dsh) on GitHub Codespaces —— 云端一键安装
#
#  在 Codespaces 的**容器里**运行（不是本机）：
#      curl -fsSL https://raw.githubusercontent.com/Wz2-z/dsh-codespaces-kit/main/install/cloud-setup.sh -o ~/cloud-setup.sh
#      bash ~/cloud-setup.sh --dry-run     # 先只看它打算做什么，不改任何东西
#      bash ~/cloud-setup.sh               # 真正执行
#
#  参数：
#      --dry-run        只检查、只打印，不写文件、不改配置
#      --repo=a/b       指定仓库（默认从 Codespace 自己的工作区识别）
#      --no-deploy-key  跳过生成/登记 deploy key（只用平台自带令牌）
#
#  它是幂等的：跑第 2 次不会重复装、不会覆盖你已有的 dsh 配置。
# =============================================================================
set -u

DRY_RUN=0
NO_DEPLOY_KEY=0
REPO_SLUG_ARG=""

usage() {
  sed -n '2,17p' "$0" 2>/dev/null || echo "用法：bash cloud-setup.sh [--dry-run] [--repo=owner/name] [--no-deploy-key]"
}

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run|--check) DRY_RUN=1 ;;
    --no-deploy-key)   NO_DEPLOY_KEY=1 ;;
    --repo)            shift || true; REPO_SLUG_ARG="${1:-}" ;;
    --repo=*)          REPO_SLUG_ARG="${1#--repo=}" ;;
    -h|--help)         usage; exit 0 ;;
    *) echo "未知参数：$1（用 --help 看用法）"; exit 2 ;;
  esac
  shift || true
done

STEP=0
TOTAL=8
ok()   { printf '     \033[32m✓\033[0m %s\n' "$*"; }
info() { printf '       %s\n' "$*"; }
warn() { printf '     \033[33m!\033[0m %s\n' "$*"; }
skip() { printf '     \033[90m-\033[0m %s\n' "$*"; }
step() { STEP=$((STEP + 1)); printf '\n[%d/%d] \033[1m%s\033[0m\n' "$STEP" "$TOTAL" "$*"; }
fail() {
  printf '\n\033[31m✗ %s\033[0m\n' "$*"
  printf '  卡住了就把这一行的上面几行贴给 AI，它会接着修。\n'
  exit 1
}
# 所有会改东西的命令都经过 run：--dry-run 时只打印
run() {
  if [ "$DRY_RUN" = 1 ]; then
    printf '       \033[90m(dry-run) %s\033[0m\n' "$*"
    return 0
  fi
  "$@"
}

printf '\033[1mDeepSeek Harness · Codespaces 云端安装\033[0m\n'
[ "$DRY_RUN" = 1 ] && printf '\033[33m模式：dry-run（只检查，不改任何东西）\033[0m\n'

# -----------------------------------------------------------------------------
step "检查 GitHub CLI"
GH_BIN=""
if command -v gh >/dev/null 2>&1; then
  GH_BIN="$(command -v gh)"
  ok "已经装好：$(gh --version 2>/dev/null | head -1)"
else
  warn "没找到 gh —— 云端同步不依赖它，只是没法自动登记 deploy key"
  info "python/node 环境都还能继续，最后会给你手动登记的步骤"
fi

# -----------------------------------------------------------------------------
step "检查 Codespace"
CODESPACE_NAME="${CODESPACE_NAME:-}"
if [ -z "$CODESPACE_NAME" ] && [ -r /workspaces/.codespaces/shared/.env ]; then
  CODESPACE_NAME="$(grep -m1 '^CODESPACE_NAME=' /workspaces/.codespaces/shared/.env 2>/dev/null | cut -d= -f2- | tr -d '"' | tr -d "\r")"
fi
if [ -z "$CODESPACE_NAME" ]; then
  fail "这里看起来不是 Codespace 容器。请把这个脚本放在 Codespaces 的终端里跑；本机请用 install/setup.ps1 / install/setup.sh"
fi
ok "运行在 Codespace 容器里：$CODESPACE_NAME"

# 找到仓库本体（Codespace 打开的那个目录）
REPO_ROOT="${GITHUB_WORKSPACE:-}"
if [ -z "$REPO_ROOT" ] || [ ! -d "$REPO_ROOT/.git" ]; then
  REPO_ROOT=""
  for d in /workspaces/*/.git; do
    [ -d "$d" ] || continue
    REPO_ROOT="$(dirname "$d")"
    break
  done
fi
[ -n "$REPO_ROOT" ] && [ -d "$REPO_ROOT/.git" ] || fail "在 /workspaces 下没找到 git 仓库：Codespace 应该建在一个仓库上"
info "仓库目录：$REPO_ROOT"

REMOTE_URL="$(git -C "$REPO_ROOT" remote get-url origin 2>/dev/null || true)"
case "$REMOTE_URL" in
  git@github.com:*)     REPO_SLUG="${REMOTE_URL#git@github.com:}" ;;
  https://github.com/*) REPO_SLUG="${REMOTE_URL#https://github.com/}" ;;
  *)                    REPO_SLUG="" ;;
esac
REPO_SLUG="${REPO_SLUG%.git}"
[ -n "$REPO_SLUG_ARG" ] && REPO_SLUG="$REPO_SLUG_ARG"
[ -n "$REPO_SLUG" ] || fail "认不出仓库名（origin = ${REMOTE_URL:-空}），可以加 --repo=你的用户名/仓库名 再跑一次"
BRANCH="$(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || echo main)"
[ "$BRANCH" = "HEAD" ] && BRANCH="main"
ok "仓库：$REPO_SLUG（分支 $BRANCH）"

# -----------------------------------------------------------------------------
step "检查 Node（需要 22 或更高）"
NODE_BIN_DIR=""
node_major() { node -v 2>/dev/null | sed 's/^v//; s/\..*//'; }

if command -v node >/dev/null 2>&1 && [ "$(node_major)" -ge 22 ] 2>/dev/null; then
  NODE_BIN_DIR="$(dirname "$(command -v node)")"
  ok "已经装好：$(node -v)（$NODE_BIN_DIR）"
else
  warn "当前没有 22+ 的 node，尝试用 nvm 装一个"
  for nvm_sh in /usr/local/share/nvm/nvm.sh "$HOME/.nvm/nvm.sh"; do
    # shellcheck disable=SC1090
    [ -s "$nvm_sh" ] && . "$nvm_sh" && break
  done
  if command -v nvm >/dev/null 2>&1; then
    run nvm install 22 </dev/null || warn "nvm install 22 失败"
    run nvm alias default 22 </dev/null || true
  fi
  if command -v node >/dev/null 2>&1 && [ "$(node_major)" -ge 22 ] 2>/dev/null; then
    NODE_BIN_DIR="$(dirname "$(command -v node)")"
    ok "装好了：$(node -v)"
  else
    fail "没能装上 Node 22+。可以手动：export NVM_DIR=/usr/local/share/nvm && . \$NVM_DIR/nvm.sh && nvm install 22"
  fi
fi
NODE_BIN_DIR="$(dirname "$(command -v node 2>/dev/null || echo /usr/bin/node)")"
[ -x "$NODE_BIN_DIR/npm" ] || fail "在 $NODE_BIN_DIR 里没找到 npm，Node 安装可能不完整"

# -----------------------------------------------------------------------------
step "安装 dsh"
if [ -x "$NODE_BIN_DIR/dsh" ]; then
  ok "已经装好：$("$NODE_BIN_DIR/dsh" --version 2>/dev/null || echo '版本未知')"
elif command -v dsh >/dev/null 2>&1; then
  NODE_BIN_DIR="$(dirname "$(command -v dsh)")"
  ok "已经装好：$(dsh --version 2>/dev/null || echo '版本未知')"
else
  info "npm install -g @deepseek-ai/dsh"
  run "$NODE_BIN_DIR/npm" install -g @deepseek-ai/dsh </dev/null || fail "dsh 安装失败，看上面的 npm 报错"
  if [ "$DRY_RUN" = 1 ]; then
    info "(dry-run) 上面这行还没真的执行"
  else
    ok "装好了：$("$NODE_BIN_DIR/dsh" --version 2>/dev/null || echo '已安装')"
  fi
fi

# -----------------------------------------------------------------------------
step "配置 workspace（= 你仓库的克隆）"
WORKSPACE_DIR="$HOME/dsh-workspace"
if [ -d "$WORKSPACE_DIR/.git" ]; then
  ok "已经存在：$WORKSPACE_DIR"
  DIRTY="$(git -C "$WORKSPACE_DIR" status --porcelain 2>/dev/null | head -1)"
  [ -n "$DIRTY" ] && warn "里面还有没提交的改动，稍后 sync 会自动提交"
else
  info "git clone https://github.com/$REPO_SLUG.git → $WORKSPACE_DIR"
  run git clone "https://github.com/$REPO_SLUG.git" "$WORKSPACE_DIR" </dev/null || fail "clone 失败（仓库存在吗？当前容器有权限吗？）"
  if [ "$DRY_RUN" = 1 ]; then
    info "(dry-run) 还没真的 clone"
  else
    ok "工作区就绪：$WORKSPACE_DIR"
  fi
fi
if [ "$DRY_RUN" = 0 ]; then
  git -C "$WORKSPACE_DIR" config user.name "${DSH_GIT_NAME:-dsh cloud}"
  git -C "$WORKSPACE_DIR" config user.email "${DSH_GIT_EMAIL:-dsh-cloud@users.noreply.github.com}"
fi

# -----------------------------------------------------------------------------
step "生成 deploy key（只对你这一个仓库有写权限）"
DEPLOY_KEY="$HOME/.ssh/dsh_deploy"
KEY_TITLE="dsh-cloud-autosync"
if [ "$NO_DEPLOY_KEY" = 1 ]; then
  skip "按 --no-deploy-key 跳过"
else
  run mkdir -p "$HOME/.ssh" && run chmod 700 "$HOME/.ssh"
  if [ -f "$DEPLOY_KEY" ]; then
    ok "已经存在：$DEPLOY_KEY"
  else
    run ssh-keygen -t ed25519 -N "" -f "$DEPLOY_KEY" -C "$KEY_TITLE" </dev/null || fail "ssh-keygen 失败"
    ok "生成好了：$DEPLOY_KEY"
  fi
  PUB_KEY="$(cat "$DEPLOY_KEY.pub" 2>/dev/null || echo '')"

  if [ -n "$GH_BIN" ]; then
    OLD_ID="$("$GH_BIN" api "/repos/$REPO_SLUG/keys" --jq ".[] | select(.title==\"$KEY_TITLE\") | .id" 2>/dev/null | head -1)"
    if [ -n "$OLD_ID" ]; then
      info "先删掉同名旧 key（容器重建后它通常已经失效）"
      run "$GH_BIN" api -X DELETE "/repos/$REPO_SLUG/keys/$OLD_ID" </dev/null || warn "删旧 key 失败，继续"
    fi
    if run "$GH_BIN" api -X POST "/repos/$REPO_SLUG/keys" \
         -f "title=$KEY_TITLE" -f "key=$PUB_KEY" -F read_only=false </dev/null; then
      ok "已登记到仓库 $REPO_SLUG 的 Deploy keys"
    else
      warn "自动登记失败（可能没有 administration 权限），下面这行请手动加到 Settings → Deploy keys（勾 Allow write access）："
      printf '\n%s\n\n' "$PUB_KEY"
    fi
  else
    warn "没有 gh，跳过自动登记。手动加到 Settings → Deploy keys（勾 Allow write access）："
    printf '\n%s\n\n' "$PUB_KEY"
  fi

  # 让工作区固定用这把 key（不影响容器里其它 git 仓库）
  if [ "$DRY_RUN" = 0 ]; then
    git -C "$WORKSPACE_DIR" config core.sshCommand \
      "ssh -i $DEPLOY_KEY -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new"
  fi
  if git -C "$WORKSPACE_DIR" ls-remote origin "refs/heads/$BRANCH" >/dev/null 2>&1; then
    ok "用这把 key 能读写仓库"
  else
    warn "用这把 key 连仓库失败（key 没登记？）—— 同步会退回用平台令牌，不影响使用"
  fi
fi

# -----------------------------------------------------------------------------
step "配置自动同步（脚本放在持久卷 /workspaces）"
CLOUD_DIR="$REPO_ROOT/.dsh-cloud"
run mkdir -p "$CLOUD_DIR"

if [ "$DRY_RUN" = 0 ]; then
  cat > "$CLOUD_DIR/start.sh" <<'DSH_START'
#!/usr/bin/env bash
# 由 install/cloud-setup.sh 生成：确保 dsh 在跑 + 拉起同步循环，最后一行打印带 token 的地址
set -u
NODE_BIN="__NODE_BIN__"
CLOUD_DIR="__CLOUD_DIR__"
WORKSPACE_DIR="$HOME/dsh-workspace"
LOG="$HOME/dsh-web.log"
export PATH="$NODE_BIN:$PATH"

command -v dsh >/dev/null 2>&1 || { echo "STATE:NO_DSH"; exit 1; }
mkdir -p "$WORKSPACE_DIR"

if ! curl -s -o /dev/null -m 3 http://127.0.0.1:3080/; then
  (setsid nohup bash -c "cd $WORKSPACE_DIR && exec dsh web" >"$LOG" 2>&1 </dev/null &)
  for _ in $(seq 1 30); do
    curl -s -o /dev/null -m 2 http://127.0.0.1:3080/ && break
    sleep 2
  done
fi

if [ -x "$CLOUD_DIR/sync.sh" ] && ! pgrep -f "$CLOUD_DIR/sync.sh" >/dev/null 2>&1; then
  (setsid nohup bash "$CLOUD_DIR/sync.sh" "${DSH_SYNC_INTERVAL:-300}" >/dev/null 2>&1 </dev/null &)
fi

echo "STATE:$(curl -s -o /dev/null -w '%{http_code}' -m 3 http://127.0.0.1:3080/ || true)"
grep -a -o 'http://127.0.0.1:3080[^ ]*' "$LOG" | tail -n 1
DSH_START

  cat > "$CLOUD_DIR/sync.sh" <<'DSH_SYNC'
#!/usr/bin/env bash
# 由 install/cloud-setup.sh 生成：有改动就 commit + push（含空目录 .gitkeep 处理）
set -u
WORKSPACE_DIR="$HOME/dsh-workspace"
LOG="$HOME/dsh-sync.log"
BRANCH="__BRANCH__"

keep_empty_dirs() {
  find "$WORKSPACE_DIR" \( -name .git -o -name node_modules \) -prune -o -type d -empty -print0 2>/dev/null |
    while IFS= read -r -d '' d; do
      rel="${d#"$WORKSPACE_DIR"/}"
      git -C "$WORKSPACE_DIR" check-ignore -q -- "$rel" || : >"$d/.gitkeep"
    done
}

sync_once() {
  cd "$WORKSPACE_DIR" || return 1
  keep_empty_dirs
  [ -n "$(git status --porcelain 2>/dev/null)" ] || return 0
  git add -A
  git -c user.name="dsh cloud" -c user.email="dsh-cloud@users.noreply.github.com" \
    commit -q -m "auto-sync $(date '+%Y-%m-%d %H:%M:%S')" >>"$LOG" 2>&1
  if git push -q origin "HEAD:$BRANCH" >>"$LOG" 2>&1; then
    echo "$(date -Is) pushed" >>"$LOG"
  else
    echo "$(date -Is) push FAILED" >>"$LOG"
    return 1
  fi
}

case "${1:-300}" in
  --once) sync_once; exit $? ;;
  *) INTERVAL="$1" ;;
esac

LOCK="$HOME/.dsh-sync.lock"
while true; do
  sleep "$INTERVAL"
  if mkdir "$LOCK" 2>/dev/null; then
    sync_once
    rmdir "$LOCK" 2>/dev/null
  fi
done
DSH_SYNC

  cat > "$CLOUD_DIR/update.sh" <<'DSH_UPDATE'
#!/usr/bin/env bash
# 由 install/cloud-setup.sh 生成：升级 dsh 到最新版并重启
set -u
NODE_BIN="__NODE_BIN__"
CLOUD_DIR="__CLOUD_DIR__"
export PATH="$NODE_BIN:$PATH"

echo "BEFORE:$(dsh --version 2>/dev/null || echo unknown)"
"$NODE_BIN/npm" install -g @deepseek-ai/dsh@latest >>"$HOME/dsh-update.log" 2>&1 || { echo UPDATE:FAILED; exit 1; }
echo "AFTER:$(dsh --version 2>/dev/null || echo unknown)"

# 按端口找 PID（不要用 pkill -f "dsh web"：命令自己会命中）
PID="$(ss -ltnp 2>/dev/null | grep ':3080' | grep -o 'pid=[0-9]*' | head -1 | cut -d= -f2)"
[ -n "$PID" ] && kill "$PID" && sleep 2
exec bash "$CLOUD_DIR/start.sh"
DSH_UPDATE

  sed -i "s|__NODE_BIN__|$NODE_BIN_DIR|g; s|__CLOUD_DIR__|$CLOUD_DIR|g; s|__BRANCH__|$BRANCH|g" \
    "$CLOUD_DIR/start.sh" "$CLOUD_DIR/sync.sh" "$CLOUD_DIR/update.sh"
  chmod +x "$CLOUD_DIR/start.sh" "$CLOUD_DIR/sync.sh" "$CLOUD_DIR/update.sh"
fi
if [ "$DRY_RUN" = 1 ]; then
  info "(dry-run) 上面三个脚本还没真的写"
else
  ok "三个脚本就位：$CLOUD_DIR/{start,update,sync}.sh"
fi

if [ "$DRY_RUN" = 0 ]; then
  bash "$CLOUD_DIR/sync.sh" --once >/dev/null 2>&1 && ok "第一次同步完成" || warn "第一次同步有问题，看 ~/dsh-sync.log"
  bash "$CLOUD_DIR/start.sh" >/dev/null 2>&1 || warn "start.sh 返回非 0，稍后看 ~/dsh-web.log"
else
  skip "(dry-run) 跳过：启动 dsh、拉起同步循环"
fi

# -----------------------------------------------------------------------------
step "验证"
HTTP_CODE="$(curl -s -o /dev/null -w '%{http_code}' -m 5 http://127.0.0.1:3080/ 2>/dev/null || echo 000)"
case "$HTTP_CODE" in
  401) ok "dsh 在 127.0.0.1:3080 上监听，且需要 token（401 = 正常）" ;;
  200) warn "dsh 在监听，但直接放行了无 token 请求（200），建议检查认证配置" ;;
  000) warn "3080 没响应：可能还在启动，等 30 秒再跑一次本脚本，或看 ~/dsh-web.log" ;;
  *)   warn "3080 返回 $HTTP_CODE，看 ~/dsh-web.log" ;;
esac

TOKEN_URL="$(grep -a -o 'http://127.0.0.1:3080[^ ]*' "$HOME/dsh-web.log" 2>/dev/null | tail -1 || true)"
if [ -n "${TOKEN_URL:-}" ]; then
  ok "访问地址（本机建好隧道后打开）："
  printf '\n     \033[36m%s\033[0m\n\n' "$TOKEN_URL"
else
  warn "还没在日志里看到带 token 的地址；dsh 刚启动时跑一次 $CLOUD_DIR/start.sh 就会打印"
fi

LOCAL_HEAD="$(git -C "$WORKSPACE_DIR" rev-parse HEAD 2>/dev/null || echo none)"
REMOTE_HEAD="$(git -C "$WORKSPACE_DIR" ls-remote origin "refs/heads/$BRANCH" 2>/dev/null | cut -f1 || echo none)"
if [ "$LOCAL_HEAD" = "$REMOTE_HEAD" ] && [ "$LOCAL_HEAD" != "none" ]; then
  ok "工作区 HEAD 和远端 $BRANCH 一致（${LOCAL_HEAD:0:7}）"
else
  warn "工作区和远端不一致（本地 ${LOCAL_HEAD:0:7} / 远端 ${REMOTE_HEAD:0:7}），sync 会在 5 分钟内对齐"
fi
[ -f "$HOME/dsh-sync.log" ] && info "同步日志：$(tail -n 1 "$HOME/dsh-sync.log")"

printf '\n\033[42;30m ✅ Installation complete \033[0m\n\n'
printf '云端这边全部就绪：\n'
printf '  · dsh %s 跑在 127.0.0.1:3080\n' "$("$NODE_BIN_DIR/dsh" --version 2>/dev/null || echo '')"
printf '  · 工作区 %s（每 5 分钟自动 commit + push）\n' "$WORKSPACE_DIR"
printf '  · 脚本 %s（容器重建也不会丢）\n' "$CLOUD_DIR"
printf '\n接下来在本机：\n'
printf '  1. 建隧道：gh codespace ports forward 3080:3080 -c %s\n' "${CODESPACE_NAME}"
printf '  2. 打开上面那个带 token 的地址\n'
printf '  （或者直接跑 install/setup.ps1 / install/setup.sh，本机这些步骤它也会做）\n\n'
