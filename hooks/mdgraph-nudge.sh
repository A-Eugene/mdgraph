#!/usr/bin/env bash
# Stop hook: warn when code moved but the mdgraph router did not.
# A loaded skill is knowledge, not an interrupt — this is the interrupt.
set -u
for repo in /root/Projects/*/; do
  vault="$repo.mdgraph/WORKLOG.md"
  [ -f "$vault" ] || continue
  last=$(git -C "$repo" log -1 --format=%H -- .mdgraph/WORKLOG.md 2>/dev/null) || continue
  [ -n "$last" ] || continue
  n=$(git -C "$repo" log --oneline "$last"..HEAD -- src/ trading_framework/ 2>/dev/null | wc -l)
  if [ "${n:-0}" -gt 0 ]; then
    echo "mdgraph: $(basename "$repo") has $n commit(s) touching code since the last WORKLOG entry. Append one if a future session would otherwise repeat the work."
  fi
done
exit 0
