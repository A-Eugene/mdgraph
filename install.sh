#!/usr/bin/env bash
# Claude Code: skill, hooks, and the host vault. Copies, never symlinks.
#   PROJECTS  where repos live; the hooks glob "$PROJECTS/*/" (default /root/Projects)
#   HOST      a plain-mode vault for work not about one repository (default $HOME/.mdgraph)
set -eu; cd "$(dirname "$0")"
PROJECTS="${PROJECTS:-/root/Projects}"; HOST="${HOST:-$HOME/.mdgraph}"

mkdir -p ~/.claude/skills/mdgraph ~/.claude/hooks
cp SKILL.md ~/.claude/skills/mdgraph/SKILL.md
for h in hooks/mdgraph-*.sh; do
  sed "s|/root/Projects/\*/|$PROJECTS/*/|g; s|/root/ |$HOME/ |g" "$h" > ~/.claude/hooks/"$(basename "$h")"
  chmod +x ~/.claude/hooks/"$(basename "$h")"
done

# register the two event hooks, leaving every other hook alone
python3 - "$HOME/.claude/settings.json" <<'PY'
import json,sys,os
p=sys.argv[1]; d=json.load(open(p)) if os.path.exists(p) else {}
h=d.setdefault("hooks",{})
want={"SessionStart":"mdgraph-index.sh","Stop":"mdgraph-nudge.sh"}
for ev,script in want.items():
    cmd=os.path.expanduser(f"~/.claude/hooks/{script}")
    entries=h.setdefault(ev,[])
    if not any(cmd in x.get("command","") for e in entries for x in e.get("hooks",[])):
        entries.append({"hooks":[{"type":"command","command":cmd}]})
json.dump(d,open(p,"w"),indent=2); print("  hooks registered in settings.json")
PY

# the host vault: plain mode, since $HOME is not a repository
mkdir -p "$HOST"
REG=~/.claude/mdgraph-registry.txt
grep -qs "^$(dirname "$HOST")	" "$REG" || printf '%s\tplain\t%s\t%s\n' "$(dirname "$HOST")" "$HOST" "$(date +%F)" >> "$REG"
echo "installed: skill, 3 hooks (glob $PROJECTS/*/ and $HOME/), host vault $HOST, registry line"
