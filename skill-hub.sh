#!/usr/bin/env bash
# skill-hub.sh — skill 包管理器
# PRD: _dev/feature/feature-202606161103-use化交互优化/PRD.md

set -uo pipefail

# ============ 工具函数 ============

log()     { printf '%s\n' "$*"; }
ok()      { printf '\033[32m✓ %s\033[0m\n' "$*"; }
warn()    { printf '\033[33m! %s\033[0m\n' "$*" >&2; }
err()     { printf '\033[31m✗ %s\033[0m\n' "$*" >&2; }
confirm() { local r; read -r -p "$1 [y/N] " r; [[ "$r" =~ ^[Yy]$ ]]; }

# 递归解引用软链 → 真实绝对路径（支持 install 后通过软链调用）
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

resolve_link_safe() { resolve_link "$1" 2>/dev/null || printf '%s' "$1"; }

# 脚本真实路径（通过软链调用时 HUB_ROOT 仍正确）
_SELF_ABS="$(resolve_link_safe "${BASH_SOURCE[0]}")"
HUB_ROOT="$(cd -P -- "$(dirname -- "$_SELF_ABS")" && pwd)"

SOURCES_FILE="${HOME}/.skill-hub-sources"
GLOBAL_SKILLS_DIR="${HOME}/.claude/skills"
PROJECT_SKILLS_DIR="${PWD}/.claude/skills"

# ============ source 管理 ============

read_sources() {
  [ -f "$SOURCES_FILE" ] || return
  while IFS= read -r line; do
    [[ "$line" =~ ^[[:space:]]*$ ]] && continue
    [[ "$line" =~ ^# ]] && continue
    printf '%s\n' "$line"
  done < "$SOURCES_FILE"
}

cmd_source() {
  local sub="${1:-list}"; shift 2>/dev/null || true
  case "$sub" in
    add)
      local path="${1:-}"
      [ -z "$path" ] && { err "用法: source add <路径>"; return 1; }
      path="$(cd -P -- "$path" 2>/dev/null && pwd)" || { err "路径不存在: $path"; return 1; }
      [ -d "${path}/packages" ] || warn "未发现 packages/ 目录，确认路径是否正确"
      if grep -qxF "$path" "$SOURCES_FILE" 2>/dev/null; then
        warn "已注册: $path"; return 0
      fi
      printf '%s\n' "$path" >> "$SOURCES_FILE"
      ok "已注册 source: $path"
      ;;
    remove|rm)
      local path="${1:-}"
      [ -z "$path" ] && { err "用法: source remove <路径>"; return 1; }
      path="$(cd -P -- "$path" 2>/dev/null && pwd 2>/dev/null || printf '%s' "$path")"
      if [ ! -f "$SOURCES_FILE" ] || ! grep -qxF "$path" "$SOURCES_FILE" 2>/dev/null; then
        warn "未找到: $path"; return 1
      fi
      local tmp; tmp="$(mktemp)"
      grep -vxF "$path" "$SOURCES_FILE" > "$tmp" && mv "$tmp" "$SOURCES_FILE"
      ok "已移除 source: $path"
      ;;
    list)
      log "=== 已注册的 Sources ==="
      local found=0
      while IFS= read -r src; do
        found=$((found+1))
        if [ -d "$src" ]; then
          printf '  ✅ %s\n' "$src"
        else
          printf '  ❌ %s  (路径不存在)\n' "$src"
        fi
      done < <(read_sources)
      if [ "$found" -eq 0 ]; then warn "尚未注册任何 source，用: skill-hub source add <路径>"; fi
      ;;
    *) err "未知子命令: source $sub  (add|remove|list)"; return 1 ;;
  esac
}

# ============ list ============

cmd_list() {
  log "=== skill-hub 技能总览 ==="
  local total=0 src pkg pkg_name s sn desc n first

  while IFS= read -r src; do
    [ -d "${src}/packages" ] || continue
    for pkg in "${src}/packages"/*/; do
      [ -d "$pkg" ] || continue
      pkg_name=$(basename -- "$pkg")
      [[ "$pkg_name" == .* ]] && continue

      desc=""
      [ -f "${pkg}README.md" ] && desc=$(awk \
        '/^[[:space:]]*$/{if(f)exit; next} /^#/{if(f)exit; next} {print; f=1}' \
        "${pkg}README.md" | head -1 | sed 's/  */ /g')

      printf '\n  ■ %s\n' "$pkg_name"
      [ -n "$desc" ] && printf '    描述: %s\n' "$desc"
      printf '    来源: %s\n' "$src"

      n=0
      for s in "${pkg}skills"/*/; do
        [ -d "$s" ] || continue
        sn=$(basename -- "$s"); [[ "$sn" == .* ]] && continue
        n=$((n+1))
        first=""
        [ -f "${s}SKILL.md" ] && first=$(grep -m1 '^description:' "${s}SKILL.md" 2>/dev/null \
          | sed 's/^description:[[:space:]]*//')
        printf '      - %-24s %s\n' "$sn" "$first"
      done
      printf '    技能数: %d\n' "$n"
      total=$((total+1))
    done
  done < <(read_sources)

  echo ""
  if [ "$total" -eq 0 ]; then
    warn "未发现任何技能包（请先: skill-hub source add <路径>）"
  else
    ok "共 $total 个包"
  fi
}

# ============ check ============

classify() {
  local entry="$1"
  if [ -L "$entry" ]; then
    [ ! -e "$entry" ] && { printf 'dead|'; return; }
    local abs; abs=$(resolve_link_safe "$entry")
    while IFS= read -r src; do
      [[ "$abs" == "$src"/* ]] && { printf 'managed|%s' "$abs"; return; }
    done < <(read_sources)
    printf 'external|%s' "$abs"
  else
    printf 'native|'
  fi
}

scan_side() {
  local label="$1" dir="$2"
  local n_m=0 n_e=0 n_d=0 n_n=0
  echo ""; echo "[$label] $dir"
  if [ ! -d "$dir" ]; then warn "  目录不存在，跳过"; return 0; fi
  local name entry res tag detail
  while IFS= read -r name; do
    [ -z "$name" ] && continue
    entry="$dir/$name"; res=$(classify "$entry")
    tag="${res%%|*}"; detail="${res#*|}"
    case "$tag" in
      managed)  printf '  \033[32m✅\033[0m %-24s → %s\n' "$name" "$detail"; n_m=$((n_m+1)) ;;
      external) printf '  \033[33m⚠️\033[0m %-24s → %s  (外部源)\n' "$name" "$detail"; n_e=$((n_e+1)) ;;
      dead)     printf '  \033[31m❌\033[0m %-24s (失效)\n' "$name"; n_d=$((n_d+1)) ;;
      native)   n_n=$((n_n+1)) ;;
    esac
  done < <(ls -A "$dir" 2>/dev/null)
  echo "  小计: 已纳管 $n_m / 外部源 $n_e / 失效 $n_d / 原生 $n_n"
  return "$n_d"
}

cmd_check() {
  local dead=0 d
  log "=== 软链来源审计 ==="
  scan_side "全局" "$GLOBAL_SKILLS_DIR"; d=$?; dead=$((dead+d))
  scan_side "工程级" "$PROJECT_SKILLS_DIR"; d=$?; dead=$((dead+d))
  echo ""
  [ "$dead" -gt 0 ] && { warn "共 $dead 个失效软链"; return 2; }
  ok "审计完成"
}

# ============ use / unuse 共用 ============

count_entries() {
  local d="$1"
  [ -d "$d" ] && find "$d" -mindepth 1 2>/dev/null | wc -l | tr -d ' ' || printf '0'
}

safe_remove_in() {
  local target_dir="$1" path="$2"
  [ -n "$path" ] || { err "拒绝删除：空路径"; return 1; }
  case "$path" in
    "$target_dir"/*) : ;;
    *) err "拒绝删除：路径越界 → $path"; return 1 ;;
  esac
  [ -e "$path" ] || [ -L "$path" ] || return 0
  rm -rf -- "$path"
}

_find_pkg() {
  local pkg_name="$1" src
  while IFS= read -r src; do
    [ -d "${src}/packages/${pkg_name}" ] && { printf '%s' "${src}/packages/${pkg_name}/"; return 0; }
  done < <(read_sources)
  return 1
}

_pick_target() {
  local target="${1:-global}"
  case "$target" in
    global)  printf '%s' "$GLOBAL_SKILLS_DIR" ;;
    project) printf '%s' "$PROJECT_SKILLS_DIR" ;;
    *) err "未知 target: $target（应为 global|project）"; return 1 ;;
  esac
}

# ============ use ============

cmd_use() {
  local pkg_name="" target=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --target|-t) target="$2"; shift 2 ;;
      --target=*|-t=*) target="${1#*=}"; shift ;;
      -*) err "未知选项: $1"; return 1 ;;
      *) pkg_name="$1"; shift ;;
    esac
  done
  [ -z "$pkg_name" ] && { err "用法: skill-hub use <包名> [-t global|project]"; return 1; }

  local pkg_dir; pkg_dir=$(_find_pkg "$pkg_name") || { err "未找到包: $pkg_name"; return 1; }
  local target_dir; target_dir=$(_pick_target "$target") || return 1

  log "=== use: $pkg_name → $target_dir ==="

  if [ ! -d "$target_dir" ]; then
    confirm "目标目录不存在，是否创建？" || { warn "已取消"; return 1; }
    mkdir -p -- "$target_dir"
  fi

  local succ=0 skip=0 fail=0 s sn src_abs link cur cnt
  for s in "${pkg_dir}skills"/*/; do
    [ -d "$s" ] || continue
    sn=$(basename -- "$s"); [[ "$sn" == .* ]] && continue
    src_abs=$(cd -P -- "$s" && pwd)
    link="$target_dir/$sn"

    if [ -e "$link" ] || [ -L "$link" ]; then
      if [ -L "$link" ]; then
        cur=$(resolve_link_safe "$link")
        if [ "$cur" = "$src_abs" ]; then
          printf '  · %-22s 已指向同源，跳过\n' "$sn"; skip=$((skip+1)); continue
        fi
        printf '  \033[33m⚠️\033[0m %-22s 已存在(软链→%s)\n' "$sn" "$cur"
      else
        cnt=$(count_entries "$link")
        printf '  \033[33m⚠️\033[0m %-22s 已存在(实体目录, %s 项)\n' "$sn" "$cnt"
      fi
      confirm "    覆盖 $sn ?" || { skip=$((skip+1)); continue; }
      safe_remove_in "$target_dir" "$link" || { fail=$((fail+1)); continue; }
    fi

    if ln -s -- "$src_abs" "$link"; then
      printf '  \033[32m✓\033[0m %-22s → %s\n' "$sn" "$src_abs"; succ=$((succ+1))
    else
      err "链接失败: $sn"; fail=$((fail+1))
    fi
  done

  echo ""; log "汇总: 成功 $succ / 跳过 $skip / 失败 $fail"
  [ "$fail" -gt 0 ] && return 1 || return 0
}

# ============ unuse ============

cmd_unuse() {
  local pkg_name="" target=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --target|-t) target="$2"; shift 2 ;;
      --target=*|-t=*) target="${1#*=}"; shift ;;
      -*) err "未知选项: $1"; return 1 ;;
      *) pkg_name="$1"; shift ;;
    esac
  done
  [ -z "$pkg_name" ] && { err "用法: skill-hub unuse <包名> [-t global|project]"; return 1; }

  local pkg_dir; pkg_dir=$(_find_pkg "$pkg_name") || { err "未找到包: $pkg_name"; return 1; }
  local target_dir; target_dir=$(_pick_target "$target") || return 1

  log "=== unuse: $pkg_name 从 $target_dir ==="
  local removed=0 s sn link
  for s in "${pkg_dir}skills"/*/; do
    [ -d "$s" ] || continue
    sn=$(basename -- "$s"); [[ "$sn" == .* ]] && continue
    link="$target_dir/$sn"
    if [ -L "$link" ]; then
      safe_remove_in "$target_dir" "$link" && {
        printf '  \033[32m✓\033[0m 已移除 %s\n' "$sn"; removed=$((removed+1))
      }
    else
      printf '  · %-22s 未安装，跳过\n' "$sn"
    fi
  done
  ok "完成，共移除 $removed 个软链"
}

# ============ install ============

_install_companion_skill() {
  local skill_src="${HUB_ROOT}/skills/skill-hub"
  local skill_link="${GLOBAL_SKILLS_DIR}/skill-hub"
  [ -d "$skill_src" ] || return 0
  [ -d "$GLOBAL_SKILLS_DIR" ] || return 0
  local src_abs; src_abs=$(cd -P -- "$skill_src" && pwd)
  if [ -L "$skill_link" ]; then
    local cur_skill; cur_skill=$(resolve_link_safe "$skill_link")
    if [ "$cur_skill" != "$src_abs" ]; then
      rm -f -- "$skill_link" && ln -s -- "$src_abs" "$skill_link"
    fi
  elif [ ! -e "$skill_link" ]; then
    ln -s -- "$src_abs" "$skill_link"
  fi
  ok "伴随 skill 已装入: $skill_link"
}

cmd_install() {
  local bin_dir="${HOME}/.local/bin"
  local target="${bin_dir}/skill-hub"

  [ -d "$bin_dir" ] || { mkdir -p -- "$bin_dir" && ok "创建目录: $bin_dir"; }

  if [ -L "$target" ]; then
    local cur; cur=$(resolve_link_safe "$target")
    if [ "$cur" = "$_SELF_ABS" ]; then
      ok "已安装（同源）: $target"
      _install_companion_skill; return 0
    fi
    warn "已存在但指向: $cur"
    confirm "覆盖？" || { warn "已取消"; return 1; }
    rm -f -- "$target"
  elif [ -e "$target" ]; then
    err "目标已存在且非软链: $target"; return 1
  fi

  chmod +x "$_SELF_ABS"
  ln -s -- "$_SELF_ABS" "$target"
  ok "已安装: $target"
  ok "  → $_SELF_ABS"

  _install_companion_skill

  case ":${PATH}:" in
    *":${bin_dir}:"*) : ;;
    *)
      echo ""
      warn "$bin_dir 不在 PATH 中，请执行："
      case "${SHELL##*/}" in
        zsh)  log "  echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ~/.zshrc && source ~/.zshrc" ;;
        bash) log "  echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ~/.bashrc && source ~/.bashrc" ;;
        *)    log "  export PATH=\"\$HOME/.local/bin:\$PATH\"" ;;
      esac
      ;;
  esac
}

# ============ collect (V2 占位) ============

cmd_collect() {
  warn "collect 功能 V2 规划中，暂未实现"
  return 0
}

# ============ 主菜单 ============

main_menu() {
  while true; do
    echo ""
    log "skill-hub 主菜单"
    echo "  1) 查看技能包    (list)"
    echo "  2) 软链审计      (check)"
    echo "  3) 使用技能包    (use)"
    echo "  4) 移除技能包    (unuse)"
    echo "  5) Source 管理   (source add|remove|list)"
    echo "  6) 安装全局命令  (install)"
    echo "  7) 收编外部技能  (collect) [V2]"
    echo "  0) 退出"
    local c; read -r -p "选择: " c
    case "$c" in
      1) cmd_list ;;
      2) cmd_check ;;
      3) local p; read -r -p "包名: " p; [ -n "$p" ] && cmd_use "$p" ;;
      4) local p; read -r -p "包名: " p; [ -n "$p" ] && cmd_unuse "$p" ;;
      5)
        local sub arg
        read -r -p "source 子命令 (add|remove|list) [路径]: " sub arg
        cmd_source "$sub" "${arg:-}"
        ;;
      6) cmd_install ;;
      7) cmd_collect ;;
      0|q) log "再见"; break ;;
      *) warn "无效选择" ;;
    esac
  done
}

# ============ 入口 ============

main() {
  case "${1:-}" in
    list)    shift; cmd_list "$@" ;;
    check)   shift; cmd_check "$@" ;;
    use)     shift; cmd_use "$@" ;;
    unuse)   shift; cmd_unuse "$@" ;;
    source)  shift; cmd_source "$@" ;;
    install) shift; cmd_install "$@" ;;
    collect) shift; cmd_collect "$@" ;;
    ""|-h|--help|help)
      cat <<'EOF'
skill-hub — skill 包管理器

用法:
  skill-hub                               交互菜单
  skill-hub list                          列出所有技能包
  skill-hub check                         软链来源审计
  skill-hub use <包> [-t global|project]  激活技能包（建软链）
  skill-hub unuse <包> [-t global|project] 移除技能包软链
  skill-hub source add <路径>             注册 skill source
  skill-hub source remove <路径>          移除 source
  skill-hub source list                   查看已注册 sources
  skill-hub install                       安装全局命令到 ~/.local/bin/
  skill-hub collect                       (V2) 收编外部技能
EOF
      ;;
    *) err "未知命令: $1"; exit 1 ;;
  esac
}

main "$@"
