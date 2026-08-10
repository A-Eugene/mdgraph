#!/usr/bin/env bash
# Resolve a repo's vault directory, or print nothing. Shared by the index and nudge
# hooks so discovery has ONE definition.
#
# Order, first hit wins:
#   1. the registry (~/.claude/mdgraph-registry.txt) — an explicit answer, and the only
#      thing that can express an unconventional vault path or a project that declined.
#   2. `.mdgraph/` in the repo — a plain directory (non-git project) or an in-tree vault.
#   3. the worktree holding branch `mdgraph`, ASKED OF GIT.
#
# Git is asked rather than a path guessed, because a sibling-name rule (<repo>-mdgraph)
# only resolves from the primary checkout: from `foo-news` it would look for
# `foo-news-mdgraph` and find nothing, silently, while the vault sits in `foo-mdgraph`.
# `git worktree list` answers correctly from every worktree, with no symlink and no
# naming convention — but it can only find a vault that is a worktree of THIS repo,
# which is why the registry sits above it.
set -u
repo="${1:-.}"
[ -d "$repo" ] || exit 0
abs=$(cd "$repo" 2>/dev/null && pwd -P) || exit 0

reg="${MDGRAPH_REGISTRY:-$HOME/.claude/mdgraph-registry.txt}"
if [ -f "$reg" ]; then
  line=$(awk -F'\t' -v r="$abs" '!/^#/ && $1==r {print; exit}' "$reg")
  if [ -n "$line" ]; then
    mode=$(printf '%s' "$line" | cut -f2)
    vault=$(printf '%s' "$line" | cut -f3)
    [ "$mode" = "declined" ] && exit 0          # asked once, answered no
    if [ -n "$vault" ] && [ -d "$vault" ]; then
      printf '%s\n' "$vault"
      exit 0
    fi
  fi
fi

if [ -e "$abs/.mdgraph" ]; then
  readlink -f "$abs/.mdgraph" 2>/dev/null
  exit 0
fi

git -C "$abs" worktree list --porcelain 2>/dev/null |
  awk '/^worktree /{w=$2} /^branch refs\/heads\/mdgraph$/{print w; exit}'
exit 0
