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
TYPED = re.compile(r"^(Supersedes|Superseded-by|Kills|Killed-by|Cites):\s*(.+)$", re.M)
HEAD = re.compile(r"^#{1,6}\s+(.+?)\s*$", re.M)

def slugify(s):
    return re.sub(r"-+", "-", re.sub(r"[^a-z0-9]+", "-", s.lower())).strip("-")

def build(vault):
    edges = defaultdict(set)          # slug -> {(type, target)}
    nodes = set()
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
    return nodes, edges

def main():
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    vault, cmd = sys.argv[1], sys.argv[2]
    nodes, edges = build(vault)
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
                    print(f"{typ}  {s} -> {t}")
    elif cmd == "orphans":
        linked = {t for es in edges.values() for _, t in es}
        for t in sorted(linked - nodes):
            print(t)
    else:
        sys.exit(__doc__)

if __name__ == "__main__":
    # ponytail: regex parse, whole-vault rescan per run — index to SQLite if a vault outgrows it
    main()
