#!/usr/bin/env bash
# Stop hook: warn when code moved but the vault did not.
# A loaded skill is knowledge, not an interrupt — this is the interrupt.
#
# Freshness is asked of the VAULT'S OWN repo, not the code repo. When a vault lives on
# its own branch, `git -C <code-repo> log -- .mdgraph/WORKLOG.md` returns the commit
# that REMOVED the in-tree copy; that timestamp never advances, so the check would fire
# on every Stop forever and train the reader to ignore it.
#
# One nudge per repository, not per worktree: sibling checkouts of one repo share an
# object store, so they are deduped on the common git dir.
set -u
seen=""
for repo in /root/Projects/*/; do
  d="$repo.mdgraph"
  [ -e "$d" ] || continue
  real=$(readlink -f "$d" 2>/dev/null) || continue
  [ -d "$real" ] || continue

  common=$(git -C "$repo" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || continue
  case " $seen " in *" $common "*) continue ;; esac
  seen="$seen $common"

  # last commit touching any log in the vault, asked of whichever repo owns the vault
  vt=$(git -C "$real" log -1 --format=%ct -- . 2>/dev/null)
  [ -n "$vt" ] || continue

  n=$(git -C "$repo" log --oneline --since="@$vt" -- src/ trading_framework/ 2>/dev/null | wc -l)
  if [ "${n:-0}" -gt 0 ]; then
    echo "mdgraph: $(basename "$repo") has $n commit(s) touching code since the last vault entry. Append one if a future session would otherwise repeat the work."
  fi
done
exit 0
