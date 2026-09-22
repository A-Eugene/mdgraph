#!/usr/bin/env bash
# Stop hook: warn when code moved but the graph did not.
# A loaded skill is knowledge, not an interrupt — this is the interrupt.
#
# Freshness is asked of the GRAPH'S OWN repo, not the code repo. When a graph lives on
# its own branch, `git -C <code-repo> log -- .mdgraph/WORKLOG.md` returns the commit
# that REMOVED the in-tree copy; that timestamp never advances, so the check would fire
# on every Stop forever and train the reader to ignore it.
#
# One nudge per repository, not per worktree: sibling checkouts of one repo share an
# object store, so they are deduped on the common git dir.
set -u
REG="${MDGRAPH_REGISTRY:-$HOME/.claude/mdgraph-registry.txt}"
seen=""
for repo in /root/ /root/Projects/*/; do
  common=$(git -C "$repo" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || continue
  case " $seen " in *" $common "*) continue ;; esac
  seen="$seen $common"

  real=$("$(dirname "$0")/mdgraph-resolve.sh" "$repo")
  if [ -z "$real" ] || [ ! -d "$real" ]; then
    # A repo with real activity and NO graph was invisible here until 2026-09-22,
    # because this loop skipped anything the resolver could not place. That is the
    # case where memory is most needed: claude-crew took six commits over four days
    # and never produced a nudge. Suggest once, above a threshold so a repo with a
    # stray commit stays quiet, and honour a `declined` registry line for good.
    grep -q "^${repo%/}	declined" "$REG" 2>/dev/null && continue
    recent=$(git -C "$repo" log --oneline --since="14 days ago" 2>/dev/null | wc -l)
    if [ "${recent:-0}" -ge 2 ]; then
      echo "mdgraph: $(basename "${repo%/}") has no graph and $recent commit(s) in the last 14 days. Start one if a future session would otherwise repeat the work, or add a 'declined' line to $REG."
    fi
    continue
  fi

  # last commit touching any log in the graph, asked of whichever repo owns the graph
  vt=$(git -C "$real" log -1 --format=%ct -- . 2>/dev/null)
  [ -n "$vt" ] || continue

  # No pathspec: which directories hold code differs per project, and a hardcoded list
  # silently reports zero for every repo that does not use those names. Graph commits
  # land on the graph's own branch, so anything in the code repo is code movement.
  n=$(git -C "$repo" log --oneline --since="@$vt" 2>/dev/null | wc -l)
  if [ "${n:-0}" -gt 0 ]; then
    echo "mdgraph: $(basename "$repo") has $n commit(s) touching code since the last graph entry. Write one if a future session would otherwise repeat the work."
  fi
done
exit 0
