#!/usr/bin/env bash
# SessionStart hook: the entry rules, then one line per graph on this host (name,
# entry count, path, and how many descriptions run past 200 characters).
#
# No graph contents. A graph is memory for ONE repository, and a session that has
# not entered that repository has no use for them. A session that enters one
# reads its index itself, and mdgraph-guard.sh holds its first write until it has.
#
# The rules are printed here, not left to the skill, because a skill's body loads
# only when a session calls for it, and most sessions that write entries never do.
set -u
seen=""; out=""
for repo in /root/ /root/Projects/*/; do
  real=$("$(dirname "$0")/mdgraph-resolve.sh" "$repo")
  [ -n "$real" ] && [ -d "$real" ] || continue
  case " $seen " in *" $real "*) continue ;; esac
  seen="$seen $real"
  n=$(grep -l '^description:' "$real"/*.md 2>/dev/null | wc -l)
  shopt -s nullglob; logs=("$real"/WORKLOG*.md); shopt -u nullglob
  [ "$n" -gt 0 ] || [ "${#logs[@]}" -gt 0 ] || continue
  long=$(grep -h '^description:' "$real"/*.md 2>/dev/null | awk 'length($0) > 213' | wc -l)
  extra=""; [ "$long" -eq 1 ] && extra=", 1 description over 200 characters"
  [ "$long" -gt 1 ] && extra=", $long descriptions over 200 characters"
  out="$out  $(basename "$repo"): $n entries$extra, $real"$'\n'
done
[ -n "$out" ] || exit 0
cat <<'CARD'
=== mdgraph: durable memory for a repository, one markdown file per entry. The rules:
- Before working in a repository with a graph, read its index:
    grep -h '^description:' <graph>/*.md
  On a large graph, filter it for your topic first: ... | grep -i <topic>
- Before any claim about past work, grep the graph.
- Write an entry when a future session would otherwise repeat the work: a result and its
  numbers, a dead end, an open question, a constraint found the hard way, a trap that cost
  time. Progress narration is not an entry.
- One file per entry, flat at the graph root, named for the thing. Frontmatter holds
  description (one sentence under 200 characters: what you found) and date (YYYY-MM-DD).
- The body holds everything needed to reproduce the result or rule it out without you: the
  setup, the parameters, the numbers, the mechanism, what was tried and failed.
- Record what happened, never a verdict: no "DEAD", no "do not re-attempt", nothing marked
  closed. Name who or what made a decision, or leave the conclusion to the reader.
- Never change an entry's claims. A correction is a new entry that links the earlier one
  as [[name]]. Write [[name]] only for an entry that exists.
- Commit with: git -C <graph> commit. The mdgraph skill has storage, registry and setup.
=== Graphs on this host:
CARD
printf '%s' "$out"
exit 0
