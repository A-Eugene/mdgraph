#!/usr/bin/env bash
# SessionStart hook: inject each vault's entry index + kill list as ambient context.
# The read-side complement to mdgraph-nudge.sh — targets the observed failure mode
# (asserting about past work from compressed memory instead of the vault): facts that
# are IN context do not get fabricated around; out-of-context ones do. Headings only,
# ~1k tokens; the entries themselves stay retrieval-on-demand.
set -u
for repo in /root/Projects/*/; do
  w="$repo.mdgraph/WORKLOG.md"
  [ -f "$w" ] || continue
  echo "=== mdgraph index: $(basename "$repo") — grep this WORKLOG before ANY claim about past decisions/results; these are headings only ==="
  grep -n "^## " "$w" | tail -60
  echo "--- recorded kills (do not re-fund, do not re-recommend) ---"
  grep -oh "Kills: \[\[[a-z0-9_-]*\]\]" "$w" | sort -u | sed 's/Kills: //'
done
exit 0
