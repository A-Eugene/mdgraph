#!/usr/bin/env bash
# SessionStart hook: the entry rules, then one line per graph on this host (name,
# entry count, path, how many descriptions run past 200 characters, and whether
# the index is too long to print whole).
#
# No graph contents. A graph is memory for ONE repository, and a session that has
# not entered that repository has no use for them. A session that enters one
# reads its index itself, and mdgraph-guard.sh holds its first write until it has.
#
# The rules are printed here, not left to the skill, because a skill's body loads
# only when a session calls for it, and most sessions that write entries never do.
set -u
# mdgraph_resolve, checkouts and name_of
. "$(dirname "$(readlink -f "$0")")/mdgraph-resolve.sh"
# mdgraph-guard.sh writes one mark per session and repository. Delete marks older than seven days.
find /tmp/mdgraph-guard -type f -mtime +7 -delete 2>/dev/null
seen=""; out=""
while read -r repo; do
  real=$(mdgraph_resolve "$repo")
  [ -n "$real" ] && [ -d "$real" ] || continue
  case " $seen " in *" $real "*) continue ;; esac
  seen="$seen $real"
  n=$(grep -l '^description:' "$real"/*.md 2>/dev/null | wc -l)
  shopt -s nullglob; logs=("$real"/WORKLOG*.md); shopt -u nullglob
  [ "$n" -gt 0 ] || [ "${#logs[@]}" -gt 0 ] || continue
  long=$(grep -h '^description:' "$real"/*.md 2>/dev/null | awk 'length($0) > 213' | wc -l)
  extra=""; [ "$long" -eq 1 ] && extra=", 1 description over 200 characters"
  [ "$long" -gt 1 ] && extra=", $long descriptions over 200 characters"
  # Claude Code shows 30,000 characters of a command's output by default
  size=$(grep -h '^description:' "$real"/*.md 2>/dev/null | wc -c)
  [ "$size" -gt 30000 ] && extra="$extra, index too long to print whole"
  out="$out  $(name_of "$repo"): $n entries$extra, $real"$'\n'
done < <(checkouts)
[ -n "$out" ] || exit 0
cat <<'CARD'
=== mdgraph: durable memory for a repository, one markdown file per entry. The rules:
- Before working in a repository with a graph, read its index:
    grep -h '^description:' <graph>/*.md
  A command's output past 30,000 characters is cut short without warning, so never print
  an index marked too long below. Filter it for your topic: ... | grep -i <topic>
- Before any claim about past work, grep the graph, entry bodies as well as descriptions:
    grep -rli <term> <graph>
- Before relying on an entry, find the later entries that correct it:
    grep -rl '\[\[<name>\]\]' <graph>
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
  as [[name]], and the earlier entry's description gets the prefix
  "Corrected by [[new-name]] (YYYY-MM-DD): ". A description that starts with it has a
  correction: read that entry. Write [[name]] only for an entry that exists.
- A typo, or a description shortened to under 200 characters with the same meaning, may
  be fixed in place.
- Commit with: git -C <graph> commit. The mdgraph skill has storage, registry and setup.
=== Graphs on this host:
CARD
printf '%s' "$out"
exit 0
