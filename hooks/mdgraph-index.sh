#!/usr/bin/env bash
# SessionStart hook: inject each vault's entry index as ambient context.
# The read-side complement to mdgraph-nudge.sh — targets the observed failure mode
# (asserting about past work from compressed memory instead of the vault): facts that
# are IN context do not get fabricated around; out-of-context ones do. Headings only;
# the entries themselves stay retrieval-on-demand.
#
# Resolves symlinks and indexes each vault ONCE. A vault on its own branch is mounted
# in one worktree and symlinked into the others, so a naive loop over checkouts prints
# the same index once per checkout.
set -u
seen=""
for repo in /root/Projects/*/; do
  d="$repo.mdgraph"
  [ -e "$d" ] || continue
  real=$(readlink -f "$d" 2>/dev/null) || continue
  [ -d "$real" ] || continue
  case " $seen " in *" $real "*) continue ;; esac
  seen="$seen $real"

  shopt -s nullglob
  logs=("$real"/WORKLOG*.md)
  shopt -u nullglob
  [ "${#logs[@]}" -gt 0 ] || continue

  echo "=== mdgraph index: $(basename "$repo") — grep this vault before ANY claim about past decisions/results; these are headings only ==="
  for w in "${logs[@]}"; do
    echo "--- $(basename "$w") ---"
    grep -n "^## " "$w" | tail -45
  done
  echo "--- pursuits recorded as ended; the result and mechanism are in the entries ---"
  grep -oh "Kills: \[\[[a-z0-9_-]*\]\]" "${logs[@]}" 2>/dev/null | sort -u | sed 's/Kills: //'
done
exit 0
