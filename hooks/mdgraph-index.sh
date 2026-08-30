#!/usr/bin/env bash
# SessionStart hook: print every vault entry's description as ambient context.
#
# Every entry, not a window. A window ages out the facts that bind longest, and a
# session that does not know a constraint exists cannot grep for one. Cost grows
# with the vault: ~8k tokens at 300 entries, ~13k at 500. Past that, move old
# entries to an archive/ subdirectory — still greppable, no longer indexed.
#
# Indexes each vault ONCE. Every worktree of a repo resolves to the same vault, so
# a naive loop over checkouts would print the same index once per checkout.
set -u
seen=""
for repo in /root/Projects/*/; do
  real=$("$(dirname "$0")/mdgraph-vault.sh" "$repo")
  [ -n "$real" ] && [ -d "$real" ] || continue
  case " $seen " in *" $real "*) continue ;; esac
  seen="$seen $real"

  # An entry is a root-level .md whose frontmatter carries description and date.
  # Anything else — a README, a scratch file — has no frontmatter and is skipped.
  entries=$(
    for f in "$real"/*.md; do
      [ -f "$f" ] || continue
      awk -v n="$(basename "${f%.md}")" '
        NR==1 && $0!="---" {exit}
        NR>1 && $0=="---"  {if (d!="" && s!="") printf "%s\t%s\t%s\n", d, n, s; exit}
        /^date:/           {sub(/^date:[ ]*/,"");        d=$0}
        /^description:/    {sub(/^description:[ ]*/,""); s=$0}
      ' "$f"
    done | sort
  )

  # Pre-2026-09 vaults keep a WORKLOG; index its headings until it is converted.
  shopt -s nullglob; logs=("$real"/WORKLOG*.md); shopt -u nullglob
  [ -n "$entries" ] || [ "${#logs[@]}" -gt 0 ] || continue

  echo "=== mdgraph: $(basename "$repo") — grep this vault before ANY claim about past work ==="
  [ -n "$entries" ] && printf '%s\n' "$entries" | awk -F'\t' '{printf "  [[%s]] (%s) %s\n", $2, $1, $3}'
  for w in "${logs[@]}"; do
    echo "--- $(basename "$w") ---"
    grep -n "^## " "$w" | tail -45
  done
done
exit 0
