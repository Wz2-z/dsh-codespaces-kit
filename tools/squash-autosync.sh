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

is_auto_subject() { printf '%s' "$1" | grep -Eq "$MATCH_RE"; }
EMPTY_TREE="$(git hash-object -t tree /dev/null)"

# 用给定的 tree / 父提交 / 信息重建一个提交，作者与时间沿用源提交
make_commit() {
  _src="$1"; _tree="$2"; _parent="$3"; _msg="$4"
  _an="$(git log -1 --format=%an "$_src")"; _ae="$(git log -1 --format=%ae "$_src")"
  _ad="$(git log -1 --format=%aI "$_src")"
  _cn="$(git log -1 --format=%cn "$_src")"; _ce="$(git log -1 --format=%ce "$_src")"
  _cd="$(git log -1 --format=%cI "$_src")"
  if [ -n "$_parent" ]; then
    printf '%s\n' "$_msg" | GIT_AUTHOR_NAME="$_an" GIT_AUTHOR_EMAIL="$_ae" GIT_AUTHOR_DATE="$_ad" \
      GIT_COMMITTER_NAME="$_cn" GIT_COMMITTER_EMAIL="$_ce" GIT_COMMITTER_DATE="$_cd" \
      git commit-tree "$_tree" -p "$_parent" -F -
  else
    printf '%s\n' "$_msg" | GIT_AUTHOR_NAME="$_an" GIT_AUTHOR_EMAIL="$_ae" GIT_AUTHOR_DATE="$_ad" \
      GIT_COMMITTER_NAME="$_cn" GIT_COMMITTER_EMAIL="$_ce" GIT_COMMITTER_DATE="$_cd" \
      git commit-tree "$_tree" -F -
  fi
}

merged_message() {
  _base="$1"; _tree="$2"; _n="$3"
  _files="$(git diff --name-only -z "$_base" "$_tree" 2>/dev/null | tr '\0' '\n' | sed '/^$/d' | tr -d '"')"
  _count="$(printf '%s\n' "$_files" | grep -c . || true)"
  _dirs="$(printf '%s\n' "$_files" | awk -F/ 'NF>1{print $1"/"$2} NF==1{print $1}' |
    sort | uniq -c | sort -rn | head -3 | awk '{print $2}' | paste -sd', ' -)"
  printf 'dsh: update %s (%s files) — 合并 %s 次自动同步' "${_dirs:-workspace}" "${_count:-0}" "$_n"
}

# 按"段"重放整条历史：每段连续自动提交压成一条（内容 = 该段最后一条的 tree），
# 其余提交原样重建。不用 rebase，所以中间态出现"空改动"也不会失败。
OLD_TREE="$(git rev-parse HEAD^{tree})"
NEW=""
i=0; n_all=${#ALL[@]}; created=0; skipped=0
while [ "$i" -lt "$n_all" ]; do
  sha="${ALL[$i]}"
  subj="$(git log -1 --format=%s "$sha")"
  if is_auto_subject "$subj"; then
    j="$i"
    while [ $((j + 1)) -lt "$n_all" ] && is_auto_subject "$(git log -1 --format=%s "${ALL[$((j + 1))]}")"; do
      j=$((j + 1))
    done
    run_len=$((j - i + 1))
    src="${ALL[$j]}"
    tree="$(git rev-parse "$src^{tree}")"
    if [ "$run_len" -ge 2 ]; then
      base_tree="$EMPTY_TREE"
      [ -n "$NEW" ] && base_tree="$(git rev-parse "$NEW^{tree}")"
      if git diff --quiet "$base_tree" "$tree" 2>/dev/null; then
        echo "  跳过净改动为空的一段：$(git rev-parse --short "${ALL[$i]}")…$(git rev-parse --short "$src")（$run_len 条）"
        skipped=$((skipped + 1))
      else
        NEW="$(make_commit "$src" "$tree" "$NEW" "$(merged_message "$base_tree" "$tree" "$run_len")")"
        created=$((created + 1))
      fi
    else
      NEW="$(make_commit "$sha" "$tree" "$NEW" "$subj")"
      created=$((created + 1))
    fi
    i=$((j + 1))
  else
    tree="$(git rev-parse "$sha^{tree}")"
    NEW="$(make_commit "$sha" "$tree" "$NEW" "$(git log -1 --format=%B "$sha")")"
    created=$((created + 1))
    i=$((i + 1))
  fi
done

[ -n "$NEW" ] || { echo "重建失败：没有生成任何提交"; exit 1; }
git update-ref -m "squash-autosync" "refs/heads/$BRANCH" "$NEW" "$(git rev-parse HEAD)"
git reset -q --hard "$NEW" || { echo "更新工作区失败，用 $BACKUP 回滚"; exit 1; }

if [ "$(git rev-parse HEAD^{tree})" != "$OLD_TREE" ]; then
  echo "❌ 重建后文件树和原来不一致，没有推送。用 $BACKUP 回滚"
  exit 1
fi

echo
echo "改完了（跳过 $skipped 段净改动为空的，共建 $created 条），新历史："
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
