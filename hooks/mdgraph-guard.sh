#!/usr/bin/env bash
# PreToolUse(Edit|Write|MultiEdit|NotebookEdit|Bash|Grep) hook: before a session
# changes a repository that has a graph, it reads the graph's index.
#
# A session that searches the graph's descriptions (a Bash grep naming the graph
# and "description", or the Grep tool on the graph) counts as having read it.
# Until then, the first touch of the repository gets a notice, and the first
# write into it is refused, once per session per repository. The refusal is what
# works: a notice alone is read and ignored.
PROJECTS_DIR="${MDGRAPH_PROJECTS:-/root/Projects}"
RESOLVE="$(dirname "$(readlink -f "$0")")/mdgraph-resolve.sh"
PY=python3; [ -x /usr/bin/python3 ] && PY=/usr/bin/python3
exec "$PY" - "$PROJECTS_DIR" "$RESOLVE" 3<&0 <<'PY'
import json, os, re, subprocess, sys

projects, resolve = sys.argv[1].rstrip("/"), sys.argv[2]
try:
    d = json.load(os.fdopen(3))
except Exception:
    sys.exit(0)
tool = d.get("tool_name", "")
ti = d.get("tool_input") or {}
sid = re.sub(r"[^A-Za-z0-9_-]", "", d.get("session_id") or "nosession")
cmd = ti.get("command") or ""

paths = [p for p in (ti.get("file_path"), ti.get("notebook_path"), ti.get("path")) if p]
if tool == "Bash":
    paths += re.findall(r"(?<![\w.-])(/[^\s'\"`;|&<>()]+)", cmd)

marks = "/tmp/mdgraph-guard"
os.makedirs(marks, exist_ok=True)
mark = lambda graph, kind: os.path.join(marks, sid + graph.replace("/", "_") + "." + kind)


def graph_of(repo):
    try:
        out = subprocess.run([resolve, repo], capture_output=True, text=True, timeout=10).stdout.strip()
    except Exception:
        return ""
    return os.path.realpath(out) if out and os.path.isdir(out) else ""


def repo_of(path):
    """The checkout holding path: $projects/<repo>, or $projects/<repo>/<branch> when a
    repository keeps one checkout per branch."""
    p = os.path.realpath(path)
    if not p.startswith(projects + "/"):
        return None
    parts = p[len(projects) + 1:].split("/")
    if not parts[0]:
        return None
    top = os.path.join(projects, parts[0])
    if not os.path.exists(os.path.join(top, ".git")) and len(parts) > 1:
        nested = os.path.join(top, parts[1])
        if os.path.exists(os.path.join(nested, ".git")):
            return nested
    return top


# Reading a graph's index marks it read. A graph directory is itself a
# repository-shaped path under PROJECTS, so check this before anything else.
reading = (tool == "Grep" and "description" in (ti.get("pattern") or "")) or \
          (tool == "Bash" and "description" in cmd)
for p in paths:
    rp = os.path.realpath(p)
    for repo in {repo_of(p)} - {None}:
        g = graph_of(repo)
        if g and (rp == g or rp.startswith(g + "/")):
            if reading:
                open(mark(g, "read"), "w").close()
            sys.exit(0)

repo = next((r for r in map(repo_of, paths) if r), None)
if not repo:
    sys.exit(0)
g = graph_of(repo)
if not g or os.path.exists(mark(g, "read")):
    sys.exit(0)

mutating = tool in ("Edit", "Write", "MultiEdit", "NotebookEdit") or (
    tool == "Bash" and re.search(r"sed -i| > | >> |\btee |\bcp |\bmv |\brm |git commit", cmd) is not None)
kind = "deny" if mutating else "ctx"
if os.path.exists(mark(g, kind)):
    sys.exit(0)
open(mark(g, kind), "w").close()

n = sum(1 for f in os.listdir(g) if f.endswith(".md"))
size = 0
for f in os.listdir(g):
    if f.endswith(".md"):
        with open(os.path.join(g, f), errors="replace") as fh:
            size += sum(len(l) for l in fh if l.startswith("description:"))
if size > 30000:  # Claude Code shows 30,000 characters of a command's output by default
    how = (f"Its index is {size:,} characters, more than one command's output shows, and the "
           f"rest is cut without warning. Filter it for your topic: grep -h '^description:' "
           f"{g}/*.md | grep -i <topic> .")
else:
    how = f"Read its index: grep -h '^description:' {g}/*.md ."
body = (f"{repo} has a memory graph at {g} ({n} entries), to read before changing this "
        f"repository. {how} Search entry bodies too: grep -rli <term> {g} . A recorded "
        f"constraint, dead end or open question may already cover what you are about to do.")
out = {"hookEventName": "PreToolUse"}
if mutating:
    out["permissionDecision"] = "deny"
    out["permissionDecisionReason"] = body + (" This first write is refused so that the read "
        "happens before the change. Read the index, then retry. This fires once per "
        "repository per session.")
else:
    out["additionalContext"] = body
print(json.dumps({"hookSpecificOutput": out}))
PY
