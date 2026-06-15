#!/usr/bin/env bash
# publish.sh — skill-hub 技能发布与软链体检脚本
# PRD: feature/feature-2606151813-初始项目/PRD.md
#
# 安全约定：
#   - 删除仅在用户逐条确认后执行，且路径必须落在目标目录内（safe_remove_in）
#   - 软链一律使用绝对路径
#   - 永不删除空路径、永不越界目标目录

set -uo pipefail

# ===================== 工具函数 =====================

log()  { printf '%s\n' "$*"; }
warn() { printf '\033[33m! %s\033[0m\n' "$*" >&2; }
err()  { printf '\033[31m✗ %s\033[0m\n' "$*" >&2; }
ok()   { printf '\033[32m✓ %s\033[0m\n' "$*"; }

# y/n 确认；默认 n（危险默认拒绝）
confirm() {
  local prompt="$1" reply
  read -r -p "$prompt [y/N] " reply
  [[ "$reply" =~ ^[Yy]$ ]]
}

# 递归解析软链到最终绝对目标（防环，上限 40 层）
resolve_link() {
  local cur="$1" i=0 dir tgt
  while [ -L "$cur" ]; do
    i=$((i+1)); [ "$i" -gt 40 ] && { printf '%s\n' "$cur"; return 1; }
    dir=$(cd -P -- "$(dirname -- "$cur")" 2>/dev/null && pwd)
    tgt=$(readlink "$cur")
    [[ "$tgt" != /* ]] && tgt="$dir/$tgt"
    cur="$tgt"
  done
  dir=$(cd -P -- "$(dirname -- "$cur")" 2>/dev/null && pwd || dirname -- "$cur")
  printf '%s/%s\n' "$dir" "$(basename -- "$cur")"
}

# 目录内条目计数（覆盖实体目录时提示风险）
count_entries() {
  local d="$1"
  [ -d "$d" ] && { find "$d" -mindepth 1 2>/dev/null | wc -l | tr -d ' '; } || printf '0'
}

# 读 README 首段正文作为项目描述
read_desc() {
  local readme="$1" out
  [ -f "$readme" ] || { printf '未提供'; return; }
  out=$(awk '/^[[:space:]]*$/{if(f)exit; next} /^#/{if(f)exit; next} {print; f=1}' "$readme" \
        | head -3 | sed 's/  */ /g')
  out=${out# }; out=${out% }
  printf '%s' "${out:-未提供}"
}

# 仅允许删除目标目录内的单一路径（防空/防越界）
safe_remove_in() {
  local target_dir="$1" path="$2"
  [ -n "$path" ] || { err "拒绝删除：空路径"; return 1; }
  case "$path" in
    "$target_dir"/*) : ;;
    *) err "拒绝删除：路径不在目标目录内 → $path"; return 1 ;;
  esac
  [ -e "$path" ] || [ -L "$path" ] || return 0
  rm -rf -- "$path"
}

# ===================== 全局常量 =====================

HUB_ROOT="$( cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd )"
GLOBAL_SKILLS_DIR="${HOME}/.claude/skills"
PROJECT_SKILLS_DIR="${PWD}/.claude/skills"
CHECK_DEAD=0

# ===================== F1: check =====================

# 分类单条目 → "tag|detail"
classify() {
  local entry="$1"
  if [ -L "$entry" ]; then
    if [ ! -e "$entry" ]; then
      printf 'dead|'; return
    fi
    local abs; abs=$(resolve_link "$entry")
    if [[ "$abs" == "$HUB_ROOT"/* ]]; then
      printf 'managed|%s' "$abs"
    else
      printf 'external|%s' "$abs"
    fi
  else
    printf 'native|'
  fi
}

scan_side() {
  local label="$1" dir="$2"
  local n_m=0 n_e=0 n_d=0 n_n=0
  echo ""
  echo "[$label] $dir"
  if [ ! -d "$dir" ]; then
    warn "  目录不存在，跳过"
    return 0
  fi
  local name entry res tag detail
  while IFS= read -r name; do
    [ -z "$name" ] && continue
    entry="$dir/$name"
    res=$(classify "$entry")
    tag="${res%%|*}"; detail="${res#*|}"
    case "$tag" in
      managed)  printf '  \033[32m✅\033[0m %-22s → %s\n' "$name" "$detail"; n_m=$((n_m+1)) ;;
      external) printf '  \033[33m⚠️\033[0m %-22s → %s  (外部源)\n' "$name" "$detail"; n_e=$((n_e+1)) ;;
      dead)     printf '  \033[31m❌\033[0m %-22s (失效)\n' "$name"; n_d=$((n_d+1)) ;;
      native)   n_n=$((n_n+1)) ;;
    esac
  done < <(ls -A "$dir" 2>/dev/null)
  echo "  小计: 已纳管 $n_m / 外部源 $n_e / 失效 $n_d / 原生 $n_n"
  CHECK_DEAD=$((CHECK_DEAD + n_d))
}

cmd_check() {
  CHECK_DEAD=0
  log "=== 软链来源审计 ==="
  scan_side "A 全局"   "$GLOBAL_SKILLS_DIR"
  scan_side "B 工程级" "$PROJECT_SKILLS_DIR"
  echo ""
  if [ "$CHECK_DEAD" -gt 0 ]; then
    warn "共发现 $CHECK_DEAD 个失效软链"
    return 2
  fi
  ok "审计完成"
}

# ===================== F2: list =====================

cmd_list() {
  log "=== skill-hub 项目总览 ==="
  log "根: $HUB_ROOT"
  local proj name desc n sn first found=0 s
  for proj in "$HUB_ROOT"/*/; do
    [ -d "${proj}skills" ] || continue
    name=$(basename -- "$proj")
    [ "$name" = "feature" ] && continue
    found=$((found+1))
    echo ""
    echo "■ $name"
    desc=$(read_desc "${proj}README.md")
    echo "  描述: $desc"
    n=0
    for s in "${proj}skills"/*/; do
      [ -d "$s" ] || continue
      sn=$(basename -- "$s")
      [[ "$sn" == .* ]] && continue
      n=$((n+1))
      first=""
      if [ -f "${s}SKILL.md" ]; then
        first=$(grep -m1 '^description:' "${s}SKILL.md" 2>/dev/null | sed 's/^description:[[:space:]]*//')
      fi
      printf '    - %-18s %s\n' "$sn" "$first"
    done
    echo "  技能数: $n"
  done
  echo ""
  [ "$found" -eq 0 ] && warn "未发现项目（需含 skills/ 子目录）" || ok "共 $found 个项目"
}

# ===================== F3: publish =====================

cmd_publish() {
  local project="" target="" target_dir src sn src_abs link cur cnt s
  local succ=0 skip=0 fail=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --target)        target="$2"; shift 2 ;;
      --target=*)      target="${1#*=}"; shift ;;
      -*)              err "未知选项: $1"; return 1 ;;
      *)               project="$1"; shift ;;
    esac
  done
  if [ -z "$project" ] || [ -z "$target" ]; then
    err "用法: publish <项目> --target global|project"; return 1
  fi
  case "$target" in
    global)  target_dir="$GLOBAL_SKILLS_DIR" ;;
    project) target_dir="$PROJECT_SKILLS_DIR" ;;
    *) err "未知 --target: $target (应为 global|project)"; return 1 ;;
  esac

  src="$HUB_ROOT/$project/skills"
  if [ ! -d "$src" ]; then
    err "项目技能目录不存在: $src"; return 1
  fi

  if [ ! -d "$target_dir" ]; then
    if [ "$target" = "global" ]; then
      err "全局目录不存在: $target_dir"; return 1
    fi
    if ! confirm "工程级目录不存在: $target_dir ，是否创建？"; then
      warn "已取消"; return 1
    fi
    mkdir -p -- "$target_dir" || { err "创建失败"; return 1; }
  fi

  log "=== 发布: $project → $target_dir ==="
  log "源: $src"
  for s in "$src"/*/; do
    [ -d "$s" ] || continue
    sn=$(basename -- "$s")
    [[ "$sn" == .* ]] && continue
    src_abs=$(cd -P -- "$s" && pwd)
    link="$target_dir/$sn"

    if [ -e "$link" ] || [ -L "$link" ]; then
      if [ -L "$link" ]; then
        cur=$(resolve_link "$link" 2>/dev/null)
        if [ "$cur" = "$src_abs" ]; then
          printf '  · %-18s 已指向同源，跳过\n' "$sn"; skip=$((skip+1)); continue
        fi
        printf '  \033[33m⚠️\033[0m %-18s 已存在(软链→%s)\n' "$sn" "$cur"
      else
        cnt=$(count_entries "$link")
        printf '  \033[33m⚠️\033[0m %-18s 已存在(实体目录, %s 项)\n' "$sn" "$cnt"
      fi
      if confirm "    覆盖 $sn ?"; then
        safe_remove_in "$target_dir" "$link" || { err "删除失败: $link"; fail=$((fail+1)); continue; }
      else
        skip=$((skip+1)); continue
      fi
    fi

    if ln -s -- "$src_abs" "$link"; then
      printf '  \033[32m✓\033[0m %-18s → %s\n' "$sn" "$src_abs"; succ=$((succ+1))
    else
      err "链接失败: $sn"; fail=$((fail+1))
    fi
  done

  echo ""
  log "汇总: 成功 $succ / 跳过 $skip / 失败 $fail"
  [ "$fail" -gt 0 ] && return 1 || return 0
}

# ===================== 交互菜单 =====================

menu_publish() {
  echo ""; log "可发布项目:"
  local i=0 pick target name desc proj
  declare -a PROJS
  for proj in "$HUB_ROOT"/*/; do
    [ -d "${proj}skills" ] || continue
    name=$(basename -- "$proj")
    [ "$name" = "feature" ] && continue
    i=$((i+1)); PROJS[$i]="$name"
    desc=$(read_desc "${proj}README.md")
    printf '  %d) %s — %s\n' "$i" "$name" "$desc"
  done
  [ "$i" -eq 0 ] && { warn "无可用项目"; return 1; }
  echo "  0) 返回"
  read -r -p "选择项目编号: " pick
  [[ "$pick" =~ ^[0-9]+$ ]] || { err "请输入数字"; return 1; }
  [ "$pick" = "0" ] && return
  (( pick >= 1 && pick <= i )) || { err "超出范围"; return 1; }
  read -r -p "目标 [1]全局 ~/.claude/skills  [2]工程级 $PWD/.claude/skills : " target
  case "$target" in
    1) cmd_publish "${PROJS[$pick]}" --target global ;;
    2) cmd_publish "${PROJS[$pick]}" --target project ;;
    *) err "无效目标" ;;
  esac
}

main_menu() {
  while true; do
    echo ""
    log "publish.sh 主菜单  (hub=$HUB_ROOT)"
    echo "  1) 软链体检 (check)"
    echo "  2) 项目总览 (list)"
    echo "  3) 发布技能 (publish)"
    echo "  0) 退出"
    local c
    read -r -p "选择: " c
    case "$c" in
      1) cmd_check ;;
      2) cmd_list ;;
      3) menu_publish ;;
      0|q) log "再见"; break ;;
      *) warn "无效" ;;
    esac
  done
}

# ===================== 入口 =====================

main() {
  [ -d "$HUB_ROOT" ] || { err "无法定位 skill-hub 根"; exit 1; }
  case "${1:-}" in
    check)   shift; cmd_check "$@" ;;
    list)    shift; cmd_list "$@" ;;
    publish) shift; cmd_publish "$@" ;;
    ""|-h|--help|help)
      cat <<'EOF'
publish.sh — skill-hub 技能发布与软链体检
用法:
  ./publish.sh                                交互菜单
  ./publish.sh check                          软链来源审计 (A 全局 + B 工程级)
  ./publish.sh list                           项目总览
  ./publish.sh publish <项目> --target global|project
                                              发布整项目技能(绝对路径软链)
EOF
      ;;
    *) err "未知命令: $1"; exit 1 ;;
  esac
}

main "$@"
