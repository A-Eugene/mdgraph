#!/usr/bin/env bash
# Claude Code: skill, hooks, and the host graph. Copies, never symlinks.
#   PROJECTS  where repos live, as <repo>/ or <repo>/<branch>/ (default /root/Projects)
#   HOST      a plain-mode graph for work not about one repository (default $HOME/.mdgraph)
set -eu; cd "$(dirname "$0")"
PROJECTS="${PROJECTS:-/root/Projects}"; HOST="${HOST:-$HOME/.mdgraph}"

mkdir -p ~/.claude/skills/mdgraph ~/.claude/hooks
cp SKILL.md ~/.claude/skills/mdgraph/SKILL.md
for h in hooks/mdgraph-*.sh; do
  sed "s|/root/Projects/\*/|$PROJECTS/*/|g; s|/root/ |$HOME/ |g; s|:-/root/Projects}|:-$PROJECTS}|" "$h" > ~/.claude/hooks/"$(basename "$h")"
  chmod +x ~/.claude/hooks/"$(basename "$h")"
done

# register the two event hooks, leaving every other hook alone
python3 - "$HOME/.claude/settings.json" <<'PY'
import json,sys,os
p=sys.argv[1]; d=json.load(open(p)) if os.path.exists(p) else {}
h=d.setdefault("hooks",{})
want=[("SessionStart",None,"mdgraph-index.sh"),("Stop",None,"mdgraph-nudge.sh"),
      ("PreToolUse","Edit|Write|MultiEdit|NotebookEdit|Bash|Grep","mdgraph-guard.sh")]
for ev,matcher,script in want:
    cmd=os.path.expanduser(f"~/.claude/hooks/{script}")
    entries=h.setdefault(ev,[])
    if not any(cmd in x.get("command","") for e in entries for x in e.get("hooks",[])):
        e={"hooks":[{"type":"command","command":cmd}]}
        if matcher: e["matcher"]=matcher
        entries.append(e)
json.dump(d,open(p,"w"),indent=2); print("  hooks registered in settings.json")
PY

# the host graph: plain mode, since $HOME is not a repository
mkdir -p "$HOST"
REG=~/.claude/mdgraph-registry.txt
grep -qs "^$(dirname "$HOST")	" "$REG" || printf '%s\tplain\t%s\t%s\n' "$(dirname "$HOST")" "$HOST" "$(date +%F)" >> "$REG"
echo "installed: skill, 4 hooks (repos under $PROJECTS, and $HOME/), host graph $HOST, registry line"
