#!/usr/bin/env bash
# =============================================================================
#  把连续的 "auto-sync" 提交合并成一条（每个连续段合成一条，手工提交保持不变）
#
#  用法：
#      bash tools/squash-autosync.sh                 # 只看会怎么合并（dry-run，默认）
#      bash tools/squash-autosync.sh --apply         # 真的改历史（本地）
#      bash tools/squash-autosync.sh --apply --push  # 改完顺带 force-with-lease 推上去
#
#  参数：
#      --repo=DIR     仓库路径（默认当前目录）
#      --match=REGEX  哪些提交算"自动提交"（默认 '^auto-sync '）
#      --apply        真的执行（不加就只预览）
#      --backup=REF   改之前把当前位置存成 REF（默认 backup/pre-squash-<时间戳>）
#      --no-backup    不建备份分支（不推荐）
#      --push         改完 force-with-lease 推到 origin 的同名分支
#
#  安全说明：
#      - 默认只预览；--apply 才动历史
#      - 有 merge 提交时直接拒绝（这个工具不做 -p 重放）
#      - 合并后的提交信息会按改动内容重新生成，例如
#        `dsh: update projects/x, notes (23 files) — 合并 9 次自动同步`
# =============================================================================
set -u

REPO="."
MATCH_RE='^auto-sync '
APPLY=0
PUSH=0
BACKUP=""
NO_BACKUP=0

while [ $# -gt 0 ]; do
  case "$1" in
    --repo=*)    REPO="${1#--repo=}" ;;
    --repo)      shift || true; REPO="${1:-.}" ;;
    --match=*)   MATCH_RE="${1#--match=}" ;;
    --apply)     APPLY=1 ;;
    --push)      PUSH=1 ;;
    --backup=*)  BACKUP="${1#--backup=}" ;;
    --no-backup) NO_BACKUP=1 ;;
    -h|--help)   sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)           echo "未知参数：$1（--help 看用法）"; exit 2 ;;
  esac
  shift || true
done

cd "$REPO" || { echo "进不去 $REPO"; exit 2; }
git rev-parse --git-dir >/dev/null 2>&1 || { echo "$REPO 不是 git 仓库"; exit 2; }

BRANCH="$(git rev-parse --abbrev-ref HEAD)"
[ "$BRANCH" = "HEAD" ] && { echo "当前是游离 HEAD，先切到分支再跑"; exit 2; }

if [ -n "$(git status --porcelain)" ]; then
  echo "工作区不干净，先提交或 stash 再跑（免得把改动卷进来）"; exit 1
fi

if [ -n "$(git rev-list --merges HEAD | head -1)" ]; then
  echo "历史里有 merge 提交，这个工具不处理（先用别的办法或手工 rebase）"; exit 1
fi

# 找出所有匹配的提交，以及它们构成的连续段
mapfile -t ALL < <(git rev-list --reverse HEAD)
declare -a RUNS=()        # 每段：第一个 sha#最后一个 sha#个数
declare -a MATCHED=()
run_first=""; run_last=""; run_count=0
for sha in "${ALL[@]}"; do
  subj="$(git log -1 --format=%s "$sha")"
  if printf '%s' "$subj" | grep -Eq "$MATCH_RE"; then
    MATCHED+=("$sha")
    [ -z "$run_first" ] && run_first="$sha"
    run_last="$sha"; run_count=$((run_count + 1))
  else
    if [ "$run_count" -gt 1 ]; then RUNS+=("$run_first#$run_last#$run_count"); fi
    run_first=""; run_last=""; run_count=0
  fi
done
if [ "$run_count" -gt 1 ]; then RUNS+=("$run_first#$run_last#$run_count"); fi

total_matched="${#MATCHED[@]}"
echo "仓库：$(pwd)（分支 $BRANCH）"
echo "自动提交：$total_matched 条；可以合并的连续段：${#RUNS[@]} 个"
if [ "${#RUNS[@]}" -eq 0 ]; then
  echo "没有需要合并的（连续段至少要有 2 条自动提交）"
  exit 0
fi

changed=0
for run in "${RUNS[@]}"; do
  first="${run%%#*}"; rest="${run#*#}"; last="${rest%%#*}"; n="${rest##*#}"
  files="$(git diff --name-only -z "$first^" "$last" 2>/dev/null | tr '\0' '\n' | grep -c . || true)"
  dirs="$(git diff --name-only -z "$first^" "$last" 2>/dev/null | tr '\0' '\n' |
    tr -d '"' | awk -F/ 'NF>1{print $1"/"$2} NF==1{print $1}' | sort | uniq -c | sort -rn |
    head -2 | awk '{print $2}' | paste -sd', ' -)"
  printf '  %s…%s（%s 条）→ 1 条：dsh: update %s (%s files) — 合并 %s 次自动同步\n' \
    "$(git rev-parse --short "$first")" "$(git rev-parse --short "$last")" "$n" "${dirs:-workspace}" "$files" "$n"
  changed=$((changed + n - 1))
done
echo "合并后历史会少 $changed 条提交（$total_matched → $((total_matched - changed))）"

if [ "$APPLY" = 0 ]; then
  echo
  echo "（这是 dry-run。要真的执行：bash $0 --apply [--push]）"
  exit 0
fi

# ---- 真正执行 -------------------------------------------------------------
if [ "$NO_BACKUP" = 0 ]; then
  [ -n "$BACKUP" ] || BACKUP="backup/pre-squash-$(date +%Y%m%d-%H%M%S)"
  git branch -f "$BACKUP" HEAD || exit 1
  echo "备份分支：$BACKUP → $(git rev-parse --short HEAD)"
fi

TMPD="$(mktemp -d)"
HELPER="$TMPD/amend-msg.sh"
cat > "$HELPER" <<'HELPER_EOF'
#!/usr/bin/env bash
# 在执行 rebase 的仓库里把当前 HEAD（刚 fixup 完的那条）的信息按改动内容重写
set -u
subj="$(git log -1 --format=%s)"
printf '%s' "$subj" | grep -Eq "$SQUASH_MATCH_RE" || exit 0
files="$(git show --name-only -z --format= HEAD | tr '\0' '\n' | sed '/^$/d' | tr -d '"')"
count="$(printf '%s\n' "$files" | grep -c . || true)"
dirs="$(printf '%s\n' "$files" | awk -F/ 'NF>1{print $1"/"$2} NF==1{print $1}' |
  sort | uniq -c | sort -rn | head -2 | awk '{print $2}' | paste -sd', ' -)"
# 用被合并提交原本的作者身份，别再要求仓库里配好 user.name
an="$(git log -1 --format=%an)"; ae="$(git log -1 --format=%ae)"
git -c user.name="$an" -c user.email="$ae" \
  commit --amend -q -m "dsh: update ${dirs:-workspace} (${count:-0} files) — 合并 ${1:-?} 次自动同步"
HELPER_EOF
chmod +x "$HELPER"

SEQ="$TMPD/sequence-editor.sh"
cat > "$SEQ" <<'SEQ_EOF'
#!/usr/bin/env bash
# 重写 rebase 的 todo：每段连续自动提交里，第一条 pick，其余 fixup，段尾 exec 改信息
set -u
todo="$1"
out="$todo.new"
: > "$out"
mapfile -t lines < "$todo"
n=${#lines[@]}
PREV_AUTO=0
run_size=0
for ((i = 0; i < n; i++)); do
  line="${lines[$i]}"
  case "$line" in
    pick\ *) ;;
    *) printf '%s\n' "$line" >> "$out"; continue ;;
  esac
  sha="$(printf '%s' "$line" | awk '{print $2}')"
  subj="$(git log -1 --format=%s "$sha" 2>/dev/null || echo '')"
  is_auto=0
  printf '%s' "$subj" | grep -Eq "$SQUASH_MATCH_RE" && is_auto=1
  next_auto=0
  for ((j = i + 1; j < n; j++)); do
    case "${lines[$j]}" in
      pick\ *)
        nsha="$(printf '%s' "${lines[$j]}" | awk '{print $2}')"
        nsubj="$(git log -1 --format=%s "$nsha" 2>/dev/null || echo '')"
        printf '%s' "$nsubj" | grep -Eq "$SQUASH_MATCH_RE" && next_auto=1
        break ;;
    esac
  done
  if [ "$is_auto" = 1 ]; then
    if [ "$PREV_AUTO" = 1 ]; then
      printf 'fixup %s %s\n' "$sha" "$subj" >> "$out"
      run_size=$((run_size + 1))
    else
      printf 'pick %s %s\n' "$sha" "$subj" >> "$out"
      run_size=1
    fi
    # 只在真的合并了 ≥2 条时改信息；落单的自动提交保持原样
    if [ "$next_auto" = 0 ] && [ "$run_size" -ge 2 ]; then
      printf 'exec %s %s\n' "$SQUASH_HELPER" "$run_size" >> "$out"
      run_size=0
    fi
  else
    printf 'pick %s %s\n' "$sha" "$subj" >> "$out"
    run_size=0
  fi
  PREV_AUTO=$is_auto
done
mv "$out" "$todo"
SEQ_EOF
chmod +x "$SEQ"

export SQUASH_MATCH_RE="$MATCH_RE"
export SQUASH_HELPER="$HELPER"
export GIT_EDITOR=true
rm -f "$(git rev-parse --git-dir)/SQUASH_MSG_COUNT"

# 从最早的自动提交的父提交开始 rebase（没有父提交就用 --root）
FIRST="${MATCHED[0]}"
if git rev-parse "$FIRST^" >/dev/null 2>&1; then
  BASE="$(git rev-parse "$FIRST^")"
  echo "重写范围：$BASE..HEAD"
  GIT_SEQUENCE_EDITOR="$SEQ" git rebase -i "$BASE" || { echo "rebase 失败，可以用 $BACKUP 回滚"; exit 1; }
else
  echo "重写范围：--root..HEAD"
  GIT_SEQUENCE_EDITOR="$SEQ" git rebase -i --root || { echo "rebase 失败，可以用 $BACKUP 回滚"; exit 1; }
fi
rm -rf "$TMPD"

echo
echo "改完了，新历史："
git log --oneline -8 | sed 's/^/  /'

if [ "$PUSH" = 1 ]; then
  git push --force-with-lease origin "HEAD:$BRANCH" || {
    echo "force-with-lease 推失败（远端有新提交？）。本地已经改好，可以用 $BACKUP 回滚，或先 git pull --rebase 再推"
    exit 1
  }
  echo "已推送（force-with-lease）"
  if [ "$NO_BACKUP" = 0 ]; then
    git push origin "$BACKUP" >/dev/null 2>&1 && echo "备份分支也推上去了：$BACKUP"
  fi
fi
