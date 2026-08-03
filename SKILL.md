---
name: mdgraph
description: Author-curated knowledge graph in plain markdown for any research project — nodes are verbatim sections, edges are typed links, history is append-only. Use when creating/linking/superseding/killing findings, or traversing the graph.
---

# mdgraph — lossless knowledge graph in markdown

A zettelkasten with typed edges. The graph is explicit in the text; no LLM ever
sits between a finding and its storage, so nothing can be lost in extraction.

## Structure (three layers, fixed roles)

```
node files               TRUTH.   Nodes = sections. Verbatim, append-only.
WORKLOG.md               ROUTER.  Dated ledger of verdicts + pointers. Push layer.
derived indexes          CACHE.   Built from markdown on demand. Disposable.
```

Truth is never stored in a DB. A DB may be *derived* (see Traversal) and
deleted at will.

## Where it lives: `.mdgraph/`

Default home in every repo — memory infrastructure, hidden like `.claude/`:

```
<repo>/.mdgraph/WORKLOG.md   the router
<repo>/.mdgraph/*.md         node files (one finding/decision/kill per file)
```

Committed with the repo: clones, versions, and stays private exactly when the
repo does. Cross-repo queries need no central store — `graph.py` on a parent
directory (e.g. `~/Projects`) sweeps every repo's `.mdgraph/` in one pass, and
`[[slug]]` resolution is by name, not path, so links work across repos.

**Rebinding:** a repo whose truth layer already exists elsewhere (e.g. a
reports/ tree with its own conventions) declares the override in its CLAUDE.md —
nodes stay where they are, WORKLOG stays with them. Never duplicate an existing
truth layer into `.mdgraph/`.

## Nodes

- A node is a **section or file with a stable heading** — granularity is chosen
  by the author, never by extraction. One concept / finding / kill per node.
- Node body is self-contained, verdict-first, four parts where it's a concept:
  **what it is · how measured/used · how it affects · what was expected/found.**
- Load-bearing numbers appear in the node itself with provenance (date, dataset,
  stat). A number that lives only in a link target is a broken node.

## Edges (typed, hand-written)

| syntax | meaning |
|---|---|
| `[[slug]]` or `[[file#Section]]` | relates-to (untyped association) |
| `Supersedes: [[x]]` / `Superseded-by: [[x]]` on its own line | temporal edge — new node replaces old |
| `Kills: [[x]]` / `Killed-by: [[x]]` | verdict edge — idea is dead, do not re-fund |
| `Cites: [[x]]` | evidence edge — restate the number at the citing site, never outsource it |

- A `[[slug]]` with no target yet is allowed — it marks a node worth writing.
- Superseded nodes are **never edited or deleted**. They get one italic banner at
  top — *Superseded by [[x]] (date): numbers below are <era> convention.* — and
  stay in place. History is append-only; correction happens forward.

## WORKLOG.md (the router)

- Append-only, newest **last**, at the project's reports root (or repo root).
- Entry: `## YYYY-MM-DD — slug` + status word (**ALIVE / DEAD / WATCH / FROZEN**)
  + one line tried→why→result + pointer to the node.
- WORKLOG is routing, nodes are truth: any number in the log is a dated hint —
  ground in the pointed node before acting on it. The log is never edited
  retroactively; stale entries are corrected by newer entries.
- **Session start: read the tail (~last 10 entries).** Re-read the tail again
  immediately before appending (catches entries from concurrent sessions).
- **Task end / before any compact: append an entry.** A finding that lives only
  in the context window is not recorded. Kills always get an entry — the
  deterministic kill-list push is the vault's highest-value function.

## Traversal

Grep answers most queries (`grep -rn "\[\[slug\]\]"` = incoming edges). For hop
queries, materialize the adjacency with the bundled script:

```bash
python3 ~/.claude/skills/mdgraph/graph.py <vault-dir> neighbors <slug> [--hops 2]
python3 ~/.claude/skills/mdgraph/graph.py <vault-dir> dead        # all kill targets
python3 ~/.claude/skills/mdgraph/graph.py <vault-dir> orphans     # link targets with no node
```

The script parses `[[links]]` and typed-edge lines into an in-memory graph per
run. If a project ever needs a persistent index, emit it as SQLite *derived
from the markdown* — rebuildable, gitignored, never authoritative.

## Adopting in a project

1. Create `WORKLOG.md` (reports root) with the entry format at top.
2. Add to the project's CLAUDE.md: read WORKLOG tail at session start; append at
   task end / before compact; nodes append-only with supersession banners.
3. Backfill: one WORKLOG entry per existing report — status word, tried→why→
   result one-liner, pointer. Kills first; they are the do-not-re-fund list.
