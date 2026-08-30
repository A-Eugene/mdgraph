#!/usr/bin/env bash
# SessionStart hook: one line per vault on this host — name, entry count, path.
#
# Nothing more. A vault is memory for ONE repository, and a session that has not
# entered that repository has no use for its contents. The session that does
# enter it reads the index itself, for that vault only:
#     grep -h "^description:" <vault>/*.md
# That is one of the three exact operations the contract already names, and it
# costs tokens only for the vault the session is actually working in.
set -u
seen=""; out=""
for repo in /root/Projects/*/; do
  real=$("$(dirname "$0")/mdgraph-vault.sh" "$repo")
  [ -n "$real" ] && [ -d "$real" ] || continue
  case " $seen " in *" $real "*) continue ;; esac
  seen="$seen $real"
  n=$(grep -l '^description:' "$real"/*.md 2>/dev/null | wc -l)
  shopt -s nullglob; logs=("$real"/WORKLOG*.md); shopt -u nullglob
  [ "$n" -gt 0 ] || [ "${#logs[@]}" -gt 0 ] || continue
  out="$out  $(basename "$repo"): $n entries, $real"$'\n'
done
[ -n "$out" ] || exit 0
echo "=== mdgraph vaults on this host. Entering one of these repos? Read its index first:"
echo "===   grep -h '^description:' <vault>/*.md   — then grep the vault before any claim about past work ==="
printf '%s' "$out"
exit 0
