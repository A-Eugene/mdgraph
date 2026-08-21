#!/usr/bin/env bash
# SessionStart hook: inject each vault's entry index as ambient context.
# The read-side complement to mdgraph-nudge.sh — targets the observed failure mode
# (asserting about past work from compressed memory instead of the vault): facts that
# are IN context do not get fabricated around; out-of-context ones do. Headings only;
# the entries themselves stay retrieval-on-demand.
#
# Indexes each vault ONCE. Every worktree of a repo resolves to the same vault, so a
# naive loop over checkouts would print the same index once per checkout.
set -u
seen=""
for repo in /root/Projects/*/; do
  real=$("$(dirname "$0")/mdgraph-vault.sh" "$repo")
  [ -n "$real" ] && [ -d "$real" ] || continue
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
  # Standing constraints are preconditions, not events. A dated log ages them out at
  # the same rate as everything else, so the tail above hides them exactly when they
  # still bind. This pass ignores the window: a #constraint line is always shown.
  # (2026-08-21: an eligibility rule sat at entry 26 of 206 and no session ever saw it.
  # Options the operator could not use were re-proposed for weeks. A session that does
  # not know a constraint exists cannot grep for one, so rule 0 never fires.)
  # A constraint is a bullet whose text BEGINS with the tag. Matching the bare word
  # anywhere also catches prose that merely mentions it, and a plain line-grep truncates
  # a wrapped bullet mid-sentence — both observed on the first cut of this hook.
  cons=$(awk '
    /^[[:space:]]*[-*][[:space:]]+#constraint/            { p=1; print; next }
    p && /^[[:space:]]+/ && !/^[[:space:]]*[-*][[:space:]]/ { print; next }
                                                          { p=0 }
  ' "${logs[@]}" 2>/dev/null)
  if [ -n "$cons" ]; then
    echo "--- standing constraints (always shown; the tail above cannot hide these) ---"
    printf '%s\n' "$cons"
  fi
  echo "--- pursuits recorded as ended; the result and mechanism are in the entries ---"
  grep -oh "Kills: \[\[[a-z0-9_-]*\]\]" "${logs[@]}" 2>/dev/null | sort -u | sed 's/Kills: //'
done
exit 0
