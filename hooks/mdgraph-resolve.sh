#!/usr/bin/env bash
# Resolve a repo's graph directory, or print nothing. Discovery has ONE definition:
# run this file (mdgraph-resolve.sh <repo>), or source it for mdgraph_resolve,
# checkouts and name_of.
#
# Order, first hit wins:
#   1. the registry (~/.claude/mdgraph-registry.txt) — an explicit answer, and the only
#      thing that can express an unconventional graph path or a project that declined.
#   2. `.mdgraph/` in the repo — a plain directory (non-git project) or an in-tree graph.
#   3. the worktree holding branch `mdgraph`, ASKED OF GIT.
#
# Git is asked rather than a path guessed, because a sibling-name rule (<repo>-mdgraph)
# only resolves from the primary checkout: from `foo-news` it would look for
# `foo-news-mdgraph` and find nothing, silently, while the graph sits in `foo-mdgraph`.
# `git worktree list` answers correctly from every worktree, with no symlink and no
# naming convention — but it can only find a graph that is a worktree of THIS repo,
# which is why the registry sits above it.
#
# The hooks source this file and call the function, because a session start resolves
# every checkout on the host and one process per checkout costs about 30 ms each.
projects="${MDGRAPH_PROJECTS:-/root/Projects}"

# A repository sits at $projects/<repo>/, or keeps one checkout per branch under
# $projects/<repo>/<branch>/. List the host, every top-level folder, and every
# nested checkout.
checkouts() {
  printf '%s\n' /root/ "$projects"/*/
  for g in "$projects"/*/*/.git; do [ -e "$g" ] && printf '%s\n' "${g%.git}"; done
}
# A repository's name: its folder under $projects, also for a nested checkout.
name_of() {
  local p; p=$(dirname "${1%/}")
  if [ "$p" = "$projects" ] || [ "$p" = / ]; then basename "${1%/}"; else basename "$p"; fi
}

# The registry, read once: project path -> mode and graph path. The first line for a
# project wins. Fields are split by hand because `read` collapses an empty field.
declare -A _mdgraph_mode _mdgraph_graph
_mdgraph_reg="${MDGRAPH_REGISTRY:-$HOME/.claude/mdgraph-registry.txt}"
if [ -f "$_mdgraph_reg" ]; then
  while IFS= read -r _l || [ -n "$_l" ]; do
    case "$_l" in ''|'#'*) continue ;; esac
    _p=${_l%%$'\t'*}; _r=${_l#*$'\t'}; [ "$_r" = "$_l" ] && _r=""
    [ -n "$_p" ] && [ -z "${_mdgraph_mode[$_p]+x}" ] || continue
    _mdgraph_mode[$_p]=${_r%%$'\t'*}
    _r=${_r#*$'\t'}; [ "$_r" = "${_mdgraph_mode[$_p]}" ] && _r=""
    _mdgraph_graph[$_p]=${_r%%$'\t'*}
  done < "$_mdgraph_reg"
fi

mdgraph_resolve() {
  local repo="${1:-.}" abs graph
  [ -d "$repo" ] || return 0
  abs=$(cd "$repo" 2>/dev/null && pwd -P) || return 0
  if [ -n "${_mdgraph_mode[$abs]+x}" ]; then
    [ "${_mdgraph_mode[$abs]}" = "declined" ] && return 0     # asked once, answered no
    graph=${_mdgraph_graph[$abs]}
    if [ -n "$graph" ] && [ -d "$graph" ]; then
      printf '%s\n' "$graph"
      return 0
    fi
  fi
  if [ -e "$abs/.mdgraph" ]; then
    readlink -f "$abs/.mdgraph" 2>/dev/null
    return 0
  fi
  git -C "$abs" worktree list --porcelain 2>/dev/null |
    awk '/^worktree /{w=$2} /^branch refs\/heads\/mdgraph$/{print w; exit}'
  return 0
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then mdgraph_resolve "${1:-.}"; exit 0; fi
