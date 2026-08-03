#!/usr/bin/env python3
"""research-vault graph traversal — parses [[links]] + typed edges from markdown.

Derived view only: rebuilt from the markdown every run, never authoritative.
Usage:
  graph.py <vault-dir> neighbors <slug> [--hops N]   nodes within N hops (default 1)
  graph.py <vault-dir> dead                          all Kills:/Killed-by: targets
  graph.py <vault-dir> orphans                       link targets with no node
"""
import re, sys
from collections import defaultdict
from pathlib import Path

LINK = re.compile(r"\[\[([^\]#|]+)(?:#[^\]|]*)?(?:\|[^\]]*)?\]\]")
# Leading list markers / bold are allowed: inside a WORKLOG entry the natural
# form is "- Kills: [[x]]", and anchoring hard at line start silently downgraded
# those to untyped links.
TYPED = re.compile(r"^\s*(?:[-*+]\s*)?\*{0,2}(Supersedes|Superseded-by|Kills|Killed-by|Cites)\*{0,2}:\s*(.+)$", re.M | re.I)
HEAD = re.compile(r"^#{1,6}\s+(.+?)\s*$", re.M)
SECTION = re.compile(r"^##\s+(.+?)\s*$", re.M)
STATUS = re.compile(r"\*{0,2}STATUS:?\*{0,2}\s*:?\s*(ALIVE|DEAD|WATCH|FROZEN)", re.I)

def slugify(s):
    return re.sub(r"-+", "-", re.sub(r"[^a-z0-9]+", "-", s.lower())).strip("-")

def build(vault):
    edges = defaultdict(set)          # slug -> {(type, target)}
    nodes = set()
    statuses = []                     # (section-slug, STATUS, file)
    for f in Path(vault).rglob("*.md"):
        text = f.read_text(errors="ignore")
        nodes.add(slugify(f.stem))
        nodes.update(slugify(h) for h in HEAD.findall(text))
        src = slugify(f.stem)
        for m in TYPED.finditer(text):
            for tgt in LINK.findall(m.group(2)):
                edges[src].add((m.group(1).lower(), slugify(tgt)))
        for tgt in LINK.findall(text):
            edges[src].add(("relates", slugify(tgt)))
        # A status word is the human-facing marker and an edge is the machine one;
        # read both so a kill recorded with only one of them is never invisible.
        parts = SECTION.split(text)
        for head, body in zip(parts[1::2], parts[2::2]):
            m = STATUS.search(body)
            if m:
                statuses.append((slugify(head), m.group(1).upper(), f.name))
    return nodes, edges, statuses

def main():
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    vault, cmd = sys.argv[1], sys.argv[2]
    nodes, edges, statuses = build(vault)
    # undirected adjacency for neighbors
    adj = defaultdict(set)
    for s, es in edges.items():
        for _, t in es:
            adj[s].add(t); adj[t].add(s)

    if cmd == "neighbors":
        slug = slugify(sys.argv[3])
        hops = int(sys.argv[sys.argv.index("--hops") + 1]) if "--hops" in sys.argv else 1
        seen, frontier = {slug}, {slug}
        for h in range(hops):
            frontier = {n for f in frontier for n in adj[f]} - seen
            for n in sorted(frontier):
                print(f"hop{h+1}  {n}")
            seen |= frontier
    elif cmd == "dead":
        for s, es in sorted(edges.items()):
            for typ, t in sorted(es):
                if typ in ("kills", "killed-by"):
                    print(f"edge    {typ}  {s} -> {t}")
        for slug, st, fname in sorted(statuses):
            if st == "DEAD":
                print(f"status  DEAD  {slug}  ({fname})")
    elif cmd == "orphans":
        linked = {t for es in edges.values() for _, t in es}
        for t in sorted(linked - nodes):
            print(t)
    else:
        sys.exit(__doc__)

if __name__ == "__main__":
    # ponytail: regex parse, whole-vault rescan per run — index to SQLite if a vault outgrows it
    main()
