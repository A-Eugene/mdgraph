#!/usr/bin/env bash
# Resolve a repo's vault directory, or print nothing. Shared by the index and nudge
# hooks so discovery has ONE definition.
#
# Order matters:
#   1. `.mdgraph/` in the repo — a plain directory (non-git project) or an in-tree vault.
#   2. the worktree holding branch `mdgraph`, ASKED OF GIT.
# Git is asked rather than a path guessed, because a sibling-name rule (<repo>-mdgraph)
# only resolves from the primary checkout: from `foo-news` it would look for
# `foo-news-mdgraph` and find nothing, silently, while the vault sits in `foo-mdgraph`.
# `git worktree list` answers correctly from every worktree of the repo, and needs no
# symlink and no naming convention.
set -u
repo="${1:-.}"
[ -d "$repo" ] || exit 0

if [ -e "$repo/.mdgraph" ]; then
  readlink -f "$repo/.mdgraph" 2>/dev/null
  exit 0
fi

git -C "$repo" worktree list --porcelain 2>/dev/null |
  awk '/^worktree /{w=$2} /^branch refs\/heads\/mdgraph$/{print w; exit}'
exit 0
