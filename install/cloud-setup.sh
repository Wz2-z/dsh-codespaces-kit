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
  if ! "$GH_BIN" auth status >/dev/null 2>&1 && [ -r /workspaces/.codespaces/shared/.env ]; then
    # 非交互 SSH 里没有 GH_TOKEN：从 Codespaces 自己的 .env 取平台令牌（只 export，不打印）
    GH_PLATFORM_TOKEN="$(grep -m1 '^GITHUB_TOKEN=' /workspaces/.codespaces/shared/.env 2>/dev/null | cut -d= -f2- | tr -d '"' | tr -d "\r")"
    if [ -n "${GH_PLATFORM_TOKEN:-}" ]; then
      export GH_TOKEN="$GH_PLATFORM_TOKEN"
      "$GH_BIN" auth status >/dev/null 2>&1 && ok "用 Codespace 自带平台令牌做了 gh 认证（用来登记 deploy key）"
    fi
  fi
  "$GH_BIN" auth status >/dev/null 2>&1 || warn "gh 没登录：deploy key 要手动登记（最后会给命令）"
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
node_dir_ok() {
  [ -x "$1/node" ] || return 1
  [ "$("$1/node" -v 2>/dev/null | sed 's/^v//; s/\..*//')" -ge 22 ] 2>/dev/null
}
DSH_DIR=""
# 1) 已经在跑 dsh 的话，就沿用它的运行时（避免"顺手升级"）
RUN_PID="$(ss -ltnp 2>/dev/null | grep ':3080' | grep -o 'pid=[0-9]*' | head -1 | cut -d= -f2)"
if [ -n "$RUN_PID" ]; then
  RUN_EXE="$(readlink -f "/proc/$RUN_PID/exe" 2>/dev/null)"
  if [ -n "$RUN_EXE" ] && [ -x "$(dirname "$RUN_EXE")/dsh" ] && node_dir_ok "$(dirname "$RUN_EXE")"; then
    DSH_DIR="$(dirname "$RUN_EXE")"
    ok "沿用正在运行的那个 dsh 运行时"
  fi
fi
# 2) 否则在常见 nvm 前缀里找已经装好的（Codespaces 的 nvm 可能在 /usr/local/share/nvm）
if [ -z "$DSH_DIR" ]; then
  for cand in "$HOME/.nvm/versions/node"/*/bin "$HOME/nvm/current/bin" /usr/local/share/nvm/versions/node/*/bin "$NODE_BIN_DIR"; do
    [ -x "$cand/dsh" ] || continue
    node_dir_ok "$cand" || continue
    DSH_DIR="$cand"
    break
  done
fi
if [ -n "$DSH_DIR" ]; then
  NODE_BIN_DIR="$DSH_DIR"
  ok "已经装好：$("$DSH_DIR/dsh" --version 2>/dev/null || echo '版本未知')（运行时 $NODE_BIN_DIR）"
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

  # 让工作区固定用这把 key（不影响容器里其它 git 仓库）
  if [ "$DRY_RUN" = 0 ]; then
    git -C "$WORKSPACE_DIR" config core.sshCommand \
      "ssh -i $DEPLOY_KEY -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new"
  fi

  key_works() { git -C "$WORKSPACE_DIR" ls-remote origin "refs/heads/$BRANCH" >/dev/null 2>&1; }

  if [ "$DRY_RUN" = 0 ] && key_works; then
    ok "这把 key 已经能读写仓库（不用重新登记）"
  else
    REGISTERED=0
    if [ -n "$GH_BIN" ]; then
      OLD_ID="$("$GH_BIN" api "/repos/$REPO_SLUG/keys" --jq ".[] | select(.title==\"$KEY_TITLE\") | .id" 2>/dev/null | head -1)"
      case "$OLD_ID" in
        ''|*[!0-9]*) OLD_ID="" ;;   # 403 之类的错误信息不是 id，忽略
      esac
      if [ -n "$OLD_ID" ]; then
        info "先删掉同名旧 key（容器重建后它通常已经失效）"
        run "$GH_BIN" api -X DELETE "/repos/$REPO_SLUG/keys/$OLD_ID" </dev/null || warn "删旧 key 失败，继续"
      fi
      if run "$GH_BIN" api -X POST "/repos/$REPO_SLUG/keys" \
           -f "title=$KEY_TITLE" -f "key=$PUB_KEY" -F read_only=false </dev/null; then
        REGISTERED=1
        ok "已登记到仓库 $REPO_SLUG 的 Deploy keys"
      fi
    fi
    if [ "$REGISTERED" = 0 ]; then
      if [ "$DRY_RUN" = 1 ] && [ -n "$GH_BIN" ]; then
        info "(dry-run) 会试着登记 deploy key"
      else
        warn "自动登记没成功：Codespaces 自带的令牌管不了 Deploy keys（需要你本人的令牌或手动加）"
        info "如果这把 key 以前登记过、现在还能用，就什么都不用做；否则把这行公钥加到"
        info "Settings → Deploy keys（勾 Allow write access）："
        printf '\n%s\n\n' "$PUB_KEY"
      fi
    fi
  fi
  if [ "$DRY_RUN" = 0 ]; then
    key_works && ok "用这把 key 能读写仓库" \
      || warn "用这把 key 连仓库失败 —— 同步会退回用平台令牌，不影响使用"
  fi
fi

# -----------------------------------------------------------------------------
step "配置自动同步（脚本放在持久卷 /workspaces）"
CLOUD_DIR="$REPO_ROOT/.dsh-cloud"
run mkdir -p "$CLOUD_DIR"

if [ "$DRY_RUN" = 0 ]; then
  cat > "$CLOUD_DIR/sync.conf" <<'DSH_CONF'
# 自动同步设置（改完不用重启，下一次 tick 就会读到）
#   enabled       on / off
#   mode          idle(智能批量，默认) / interval(固定周期) / manual(只手动)
#   idle_seconds  idle 模式：静默这么久没有新改动就提交一次
#   max_wait      就算一直在改，最多拖这么久也提交一次（防止一天都没提交）
#   interval      interval 模式：每隔多久提交一次
#   tick          守护进程检查间隔
#   prefix        自动生成的提交信息前缀（例如 dsh: update notes (3 files)）
#   squash_window_seconds
#                 折叠窗口：上一条也是自动提交、且在这段时间内，就把新改动并进它
#                 （0 = 关闭，默认；开启后需要 force-with-lease 改写远端历史）
enabled=on
mode=idle
idle_seconds=600
max_wait=1800
interval=300
tick=30
prefix=dsh
squash_window_seconds=0
DSH_CONF

  cat > "$CLOUD_DIR/start.sh" <<'DSH_START'
#!/usr/bin/env bash
# 由 install/cloud-setup.sh 生成：确保 dsh 在跑 + 拉起同步守护进程，最后一行打印带 token 的地址
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
  (setsid nohup bash "$CLOUD_DIR/sync.sh" --daemon >/dev/null 2>&1 </dev/null &)
fi

echo "STATE:$(curl -s -o /dev/null -w '%{http_code}' -m 3 http://127.0.0.1:3080/ || true)"
grep -a -o 'http://127.0.0.1:3080[^ ]*' "$LOG" | tail -n 1
DSH_START

  cat > "$CLOUD_DIR/sync.sh" <<'DSH_SYNC'
#!/usr/bin/env bash
# =============================================================================
#  自动同步（智能批量）—— 由 install/cloud-setup.sh 生成
#
#  模式（写在 sync.conf 里，命令行可临时覆盖）：
#    idle      默认：静默 idle_seconds 没有新改动才提交；一直在改也会在 max_wait 后兜底提交
#    interval  每 interval 秒提交一次（旧行为）
#    manual    永不自动提交，只在你手动 --now 时提交
#
#    bash sync.sh --status          看模式 / 待提交的改动 / 最近提交
#    bash sync.sh --plan            只显示"会提交什么、提交信息是什么"，不动 git 历史
#    bash sync.sh --now             立刻提交一次
#    bash sync.sh --mode=interval --interval=300 --enable   切换并写回 sync.conf
#    bash sync.sh --disable         暂停自动同步（改动仍然留在工作区）
#    bash sync.sh --message="feat: 给面板加额度条"   指定下一次提交信息
# =============================================================================
set -u
CLOUD_DIR="__CLOUD_DIR__"
BRANCH="__BRANCH__"
WORKSPACE_DIR="${DSH_WORKSPACE:-$HOME/dsh-workspace}"
CONF="$CLOUD_DIR/sync.conf"
STATE="$HOME/.dsh-sync-state"
LOG="$HOME/dsh-sync.log"

enabled=on
mode=idle
idle_seconds=600
max_wait=1800
interval=300
tick=30
prefix=dsh
squash_window_seconds=0
MODE_OVERRIDE=""; IDLE_OVERRIDE=""; INT_OVERRIDE=""; ENABLE_OVERRIDE=""; MESSAGE_OVERRIDE=""
SQUASH_OVERRIDE=""
FP=""; CHANGED_AT=""; FIRST_AT=""; LAST_COMMIT_AT=""

usage() {
  sed -n '3,20p' "$0" 2>/dev/null | sed 's/^# \{0,1\}//' ||
    echo "用法：bash sync.sh [--daemon|--status|--plan|--now|--help]"
}

load_conf() {
  [ -f "$CONF" ] || return 0
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%%#*}"
    case "$line" in *=*) ;; *) continue ;; esac
    key="$(printf '%s' "${line%%=*}" | tr -d ' \t')"
    val="$(printf '%s' "${line#*=}" | tr -d ' \t"' | tr -d "'")"
    case "$key" in
      enabled) enabled="$val" ;;
      mode) mode="$val" ;;
      idle_seconds) idle_seconds="$val" ;;
      max_wait) max_wait="$val" ;;
      interval) interval="$val" ;;
      tick) tick="$val" ;;
      prefix) prefix="$val" ;;
      squash_window_seconds) squash_window_seconds="$val" ;;
    esac
  done < "$CONF"
}

save_conf() {
  [ -f "$CONF" ] || return 0
  tmp="$CONF.tmp"
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      enabled=*)      printf 'enabled=%s\n' "$enabled" ;;
      mode=*)         printf 'mode=%s\n' "$mode" ;;
      idle_seconds=*) printf 'idle_seconds=%s\n' "$idle_seconds" ;;
      max_wait=*)     printf 'max_wait=%s\n' "$max_wait" ;;
      interval=*)     printf 'interval=%s\n' "$interval" ;;
      tick=*)         printf 'tick=%s\n' "$tick" ;;
      prefix=*)       printf 'prefix=%s\n' "$prefix" ;;
      squash_window_seconds=*) printf 'squash_window_seconds=%s\n' "$squash_window_seconds" ;;
      *)              printf '%s\n' "$line" ;;
    esac
  done < "$CONF" > "$tmp"
  # 老版本 sync.conf 里没有新键时补上（否则 --squash-window=… 会悄悄不生效）
  for kv in "enabled=$enabled" "mode=$mode" "idle_seconds=$idle_seconds" "max_wait=$max_wait" \
            "interval=$interval" "tick=$tick" "prefix=$prefix" \
            "squash_window_seconds=$squash_window_seconds"; do
    grep -q "^${kv%%=*}=" "$tmp" || printf '%s\n' "$kv" >> "$tmp"
  done
  mv "$tmp" "$CONF"
}

load_state() {
  [ -f "$STATE" ] || return 0
  # shellcheck disable=SC1090
  . "$STATE"
}

save_state() {
  {
    printf 'FP=%q\n' "$FP"
    printf 'CHANGED_AT=%q\n' "$CHANGED_AT"
    printf 'FIRST_AT=%q\n' "$FIRST_AT"
    printf 'LAST_COMMIT_AT=%q\n' "$LAST_COMMIT_AT"
  } > "$STATE"
}

now_epoch() { date +%s; }

keep_empty_dirs() {
  find "$WORKSPACE_DIR" \( -name .git -o -name node_modules \) -prune -o -type d -empty -print0 2>/dev/null |
    while IFS= read -r -d '' d; do
      rel="${d#"$WORKSPACE_DIR"/}"
      git -C "$WORKSPACE_DIR" check-ignore -q -- "$rel" || : >"$d/.gitkeep"
    done
}

# 指纹：已跟踪文件的 diff + 未跟踪文件的大小/改动时间 —— 一点点改动都能看出来
fingerprint() {
  {
    git -C "$WORKSPACE_DIR" status --porcelain -uall 2>/dev/null
    git -C "$WORKSPACE_DIR" diff --binary 2>/dev/null
    git -C "$WORKSPACE_DIR" ls-files --others --exclude-standard -z 2>/dev/null |
      xargs -0 -r stat -c '%n %s %Y' 2>/dev/null
  } | sha1sum | cut -d' ' -f1
}

dirty() { [ -n "$(git -C "$WORKSPACE_DIR" status --porcelain 2>/dev/null)" ]; }

# 提交信息：优先用 AI/人 留下的提示文件，否则按改动内容自动生成
build_message() {
  for hint in "$CLOUD_DIR/commit-msg" "$WORKSPACE_DIR/.dsh-commit-msg"; do
    if [ -s "$hint" ]; then
      head -1 "$hint" | cut -c1-200
      rm -f "$hint"
      return 0
    fi
  done
  added="$(git -C "$WORKSPACE_DIR" diff --cached --name-status 2>/dev/null | awk '$1=="A"{c++} END{print c+0}')"
  deleted="$(git -C "$WORKSPACE_DIR" diff --cached --name-status 2>/dev/null | awk '$1=="D"{c++} END{print c+0}')"
  total="$(git -C "$WORKSPACE_DIR" diff --cached --name-only 2>/dev/null | grep -c . || true)"
  verb=update
  if [ "${deleted:-0}" -gt 0 ] && [ "${added:-0}" -eq 0 ]; then
    verb=remove
  elif [ "${added:-0}" -gt 0 ] && [ "${added:-0}" = "${total:-1}" ]; then
    verb=add
  fi
  dirs="$(git -C "$WORKSPACE_DIR" diff --cached --name-only 2>/dev/null |
    awk -F/ 'NF>1{print $1"/"$2} NF==1{print $1}' | sort | uniq -c | sort -rn |
    head -3 | awk '{print $2}' | paste -sd', ' -)"
  [ -n "$dirs" ] || dirs="workspace"
  printf '%s: %s %s (%s files)' "$prefix" "$verb" "$dirs" "${total:-0}"
}

commit_now() {
  cd "$WORKSPACE_DIR" || return 1
  keep_empty_dirs
  if ! dirty; then
    echo "没有待提交的改动"
    return 0
  fi
  was_staged=0
  git diff --cached --quiet || was_staged=1
  git add -A
  MSG="$(build_message)"
  if [ "$PLAN_ONLY" = 1 ]; then
    echo "提交信息：$MSG"
    echo "涉及文件："
    git diff --cached --name-status | head -20 | sed 's/^/  /'
    [ "$was_staged" = 0 ] && git reset -q
    return 0
  fi
  BODY="$(git diff --cached --name-only | head -20 | paste -sd', ' -)"
  # 折叠窗口：上一条也是自动提交、且够新 → 把改动并进去（改写那一条）
  LAST_SUBJ="$(git log -1 --format=%s 2>/dev/null || echo '')"
  LAST_TS="$(git log -1 --format=%ct 2>/dev/null || echo 0)"
  if [ "${squash_window_seconds:-0}" -gt 0 ] && [ -n "$LAST_SUBJ" ]; then
    case "$LAST_SUBJ" in
      "$prefix: "*)
        if [ $(( $(now_epoch) - LAST_TS )) -le "$squash_window_seconds" ]; then
          PRE_FOLD="$(git rev-parse HEAD)"
          git -c user.name="dsh cloud" -c user.email="dsh-cloud@users.noreply.github.com" \
            commit -q --amend -m "$MSG" ${BODY:+-m "$BODY"} >>"$LOG" 2>&1
          if git push -q --force-with-lease origin "HEAD:$BRANCH" >>"$LOG" 2>&1; then
            echo "$(date -Is) folded into previous auto-commit  $MSG" >>"$LOG"
            FP="$(fingerprint)"; LAST_COMMIT_AT="$(now_epoch)"; FIRST_AT=""; CHANGED_AT="$LAST_COMMIT_AT"
            return 0
          fi
          git reset -q --soft "$PRE_FOLD"
          echo "$(date -Is) fold push rejected, fallback to a new commit" >>"$LOG"
        fi
        ;;
    esac
  fi
  git -c user.name="dsh cloud" -c user.email="dsh-cloud@users.noreply.github.com" \
    commit -q -m "$MSG" ${BODY:+-m "$BODY"} >>"$LOG" 2>&1 || return 1
  if git push -q origin "HEAD:$BRANCH" >>"$LOG" 2>&1; then
    echo "$(date -Is) pushed  $MSG" >>"$LOG"
    FP="$(fingerprint)"; LAST_COMMIT_AT="$(now_epoch)"; FIRST_AT=""; CHANGED_AT="$LAST_COMMIT_AT"
    return 0
  fi
  # 远端可能被别的电脑动过：rebase 一下再推
  echo "$(date -Is) push rejected, rebase and retry" >>"$LOG"
  if git pull --rebase -q origin "$BRANCH" >>"$LOG" 2>&1 && git push -q origin "HEAD:$BRANCH" >>"$LOG" 2>&1; then
    echo "$(date -Is) pushed after rebase  $MSG" >>"$LOG"
    FP="$(fingerprint)"; LAST_COMMIT_AT="$(now_epoch)"; FIRST_AT=""; CHANGED_AT="$LAST_COMMIT_AT"
    return 0
  fi
  git rebase --abort >>"$LOG" 2>&1 || true
  echo "$(date -Is) push FAILED  $MSG" >>"$LOG"
  return 1
}

tick() {
  [ -d "$WORKSPACE_DIR/.git" ] || return 0
  cur="$(fingerprint)"
  t="$(now_epoch)"
  if [ "$cur" != "$FP" ]; then
    FP="$cur"
    CHANGED_AT="$t"
    [ -n "$FIRST_AT" ] || FIRST_AT="$t"
  fi
  if ! dirty; then
    FIRST_AT=""
    save_state
    return 0
  fi
  if [ "$enabled" != "on" ]; then
    save_state
    return 0
  fi
  case "$mode" in
    manual)
      : ;;
    interval)
      [ -n "$LAST_COMMIT_AT" ] || LAST_COMMIT_AT="$t"
      [ $((t - LAST_COMMIT_AT)) -ge "$interval" ] && commit_now
      ;;
    *)
      [ -n "$CHANGED_AT" ] || CHANGED_AT="$t"
      [ -n "$FIRST_AT" ] || FIRST_AT="$t"
      if [ $((t - CHANGED_AT)) -ge "$idle_seconds" ] || [ $((t - FIRST_AT)) -ge "$max_wait" ]; then
        commit_now
      fi
      ;;
  esac
  save_state
}

show_status() {
  printf '模式：%s（enabled=%s）\n' "$mode" "$enabled"
  printf '参数：idle_seconds=%s  max_wait=%s  interval=%s  tick=%s  prefix=%s  squash_window_seconds=%s\n' \
    "$idle_seconds" "$max_wait" "$interval" "$tick" "$prefix" "$squash_window_seconds"
  if [ -d "$WORKSPACE_DIR/.git" ]; then
    printf '工作区：%s\n' "$WORKSPACE_DIR"
    if dirty; then
      printf '待提交：%s 个文件\n' "$(git -C "$WORKSPACE_DIR" status --porcelain | wc -l | tr -d ' ')"
      git -C "$WORKSPACE_DIR" status --short | head -10 | sed 's/^/  /'
    else
      printf '待提交：无（工作区是干净的）\n'
    fi
    printf '分支：%s  本地 HEAD：%s  远端：%s\n' "$BRANCH" \
      "$(git -C "$WORKSPACE_DIR" rev-parse --short HEAD 2>/dev/null)" \
      "$(git -C "$WORKSPACE_DIR" ls-remote origin "refs/heads/$BRANCH" 2>/dev/null | cut -c1-7)"
    printf '最近提交：\n'
    git -C "$WORKSPACE_DIR" log --oneline -5 2>/dev/null | sed 's/^/  /'
  else
    printf '工作区不存在：%s\n' "$WORKSPACE_DIR"
  fi
}

ACTION=daemon
ACTION_EXPLICIT=0
while [ $# -gt 0 ]; do
  case "$1" in
    --daemon)     ACTION=daemon; ACTION_EXPLICIT=1 ;;
    --status)     ACTION=status ;;
    --plan)       ACTION=plan ;;
    --now|--once) ACTION=now ;;
    --mode=*)     MODE_OVERRIDE="${1#--mode=}" ;;
    --idle=*)     IDLE_OVERRIDE="${1#--idle=}" ;;
    --interval=*) INT_OVERRIDE="${1#--interval=}" ;;
    --enable)     ENABLE_OVERRIDE=on ;;
    --disable)    ENABLE_OVERRIDE=off ;;
    --squash-window=*) SQUASH_OVERRIDE="${1#--squash-window=}" ;;
    --message=*)  MESSAGE_OVERRIDE="${1#--message=}" ;;
    --help|-h)    usage; exit 0 ;;
    *)            echo "未知参数：$1（--help 看用法）"; exit 2 ;;
  esac
  shift || true
done

load_conf
[ -n "$MODE_OVERRIDE" ] && mode="$MODE_OVERRIDE"
[ -n "$IDLE_OVERRIDE" ] && idle_seconds="$IDLE_OVERRIDE"
[ -n "$INT_OVERRIDE" ] && interval="$INT_OVERRIDE"
[ -n "$ENABLE_OVERRIDE" ] && enabled="$ENABLE_OVERRIDE"
[ -n "$SQUASH_OVERRIDE" ] && squash_window_seconds="$SQUASH_OVERRIDE"
if [ -n "$MODE_OVERRIDE$IDLE_OVERRIDE$INT_OVERRIDE$ENABLE_OVERRIDE$SQUASH_OVERRIDE" ]; then save_conf; fi
if [ -n "$MESSAGE_OVERRIDE" ]; then printf '%s\n' "$MESSAGE_OVERRIDE" > "$CLOUD_DIR/commit-msg"; fi

# 只改设置（--enable / --disable / --mode=… / --idle=… / --message=…）时改完就退出，不进守护循环
if [ "$ACTION" = daemon ] && [ "$ACTION_EXPLICIT" = 0 ] &&
   [ -n "$MODE_OVERRIDE$IDLE_OVERRIDE$INT_OVERRIDE$ENABLE_OVERRIDE$SQUASH_OVERRIDE${MESSAGE_OVERRIDE}" ]; then
  printf '已更新 %s\n  enabled=%s mode=%s idle_seconds=%s max_wait=%s interval=%s tick=%s prefix=%s squash_window_seconds=%s\n' \
    "$CONF" "$enabled" "$mode" "$idle_seconds" "$max_wait" "$interval" "$tick" "$prefix" "$squash_window_seconds"
  [ -n "$MESSAGE_OVERRIDE" ] && printf '下一次提交会用：%s\n' "$MESSAGE_OVERRIDE"
  exit 0
fi

case "$ACTION" in
  status) load_state; show_status; exit 0 ;;
  plan)   load_state; PLAN_ONLY=1; commit_now; exit $? ;;
  now)    load_state; PLAN_ONLY=0; commit_now || { echo "提交/推送失败，看 $LOG"; exit 1; }; save_state; exit 0 ;;
esac

PLAN_ONLY=0
load_state
echo "$(date -Is) daemon start mode=$mode idle=${idle_seconds}s max_wait=${max_wait}s enabled=$enabled" >>"$LOG"
while true; do
  tick
  sleep "${tick:-30}"
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
  info "(dry-run) 上面三个脚本 + sync.conf 还没真的写"
else
  ok "三个脚本 + sync.conf 就位：$CLOUD_DIR/"
fi

if [ "$DRY_RUN" = 0 ]; then
  info "$(bash "$CLOUD_DIR/sync.sh" --status 2>/dev/null | head -1)"
  bash "$CLOUD_DIR/sync.sh" --now >/dev/null 2>&1 && ok "第一次同步完成" || warn "第一次同步有问题，看 ~/dsh-sync.log"
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
  warn "工作区和远端不一致（本地 ${LOCAL_HEAD:0:7} / 远端 ${REMOTE_HEAD:0:7}），改动静默下来后 sync 会自动对齐"
fi
[ -f "$HOME/dsh-sync.log" ] && info "同步日志：$(tail -n 1 "$HOME/dsh-sync.log")"

printf '\n\033[42;30m ✅ Installation complete \033[0m\n\n'
printf '云端这边全部就绪：\n'
printf '  · dsh %s 跑在 127.0.0.1:3080\n' "$("$NODE_BIN_DIR/dsh" --version 2>/dev/null || echo '')"
SYNC_SUMMARY="$(bash "$CLOUD_DIR/sync.sh" --status 2>/dev/null | head -1 | sed 's/模式：/自动同步 /')"
[ -n "$SYNC_SUMMARY" ] || SYNC_SUMMARY="自动同步 idle 模式（静默 ${DSH_IDLE_SECONDS:-600} 秒没有新改动才提交）"
printf '  · 工作区 %s（%s）\n' "$WORKSPACE_DIR" "$SYNC_SUMMARY"
printf '  · 脚本 %s（容器重建也不会丢）\n' "$CLOUD_DIR"
printf '\n接下来在本机：\n'
printf '  1. 建隧道：gh codespace ports forward 3080:3080 -c %s\n' "${CODESPACE_NAME}"
printf '  2. 打开上面那个带 token 的地址\n'
printf '  （或者直接跑 install/setup.ps1 / install/setup.sh，本机这些步骤它也会做）\n\n'
