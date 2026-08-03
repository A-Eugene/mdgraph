# mdgraph

A knowledge graph for research projects, in plain markdown. Nodes are sections
you write; edges are links you type; history is append-only. No LLM sits between
a finding and its storage, so nothing is lost in extraction — and reads/writes
cost approximately nothing.

Built as the boring alternative to LLM-extraction memory engines (cognee, mem0,
et al.), whose measured write amplification (~26× tokens out per token stored,
on my corpus) buys a graph that shreds curated structure and drops the numbers.
mdgraph inverts the design: **the author draws the node boundaries, the payload
never passes through a model, and the graph is explicit in the text.**

![architecture](architecture.svg)

## The three layers

| layer | file(s) | role |
|---|---|---|
| **TRUTH** | reports / topic files / `GLOSSARY.md` | Nodes = verbatim sections. Append-only. All numbers with provenance, inline. |
| **ROUTER** | `WORKLOG.md` | Dated ledger of verdicts + pointers. The push layer — read at session start, appended at task end. |
| **CACHE** | anything `graph.py` emits | Derived from the markdown on demand. Disposable, rebuildable, never authoritative. |

The direction of derivation is the whole design: **log → view is cheap and
lossless; view → log is impossible** (a merged graph node has destroyed its
history). So truth lives in the append-only text, and every index is a cache.

## Nodes

- A node is a **section or file with a stable heading**. One concept, finding,
  or kill per node. Granularity is chosen by the author, never by extraction.
- Node body is self-contained and verdict-first. For concepts, four parts:
  **what it is · how it's measured/used · how it affects · what was
  expected/found.**
- Load-bearing numbers appear in the node itself with provenance (date, dataset,
  statistic). A number that lives only in a link target is a broken node.

## Edges

| syntax | meaning |
|---|---|
| `[[slug]]` or `[[file#Section]]` | relates-to (untyped association) |
| `Supersedes: [[x]]` / `Superseded-by: [[x]]` | temporal edge — this node replaces that one |
| `Kills: [[x]]` / `Killed-by: [[x]]` | verdict edge — the idea is dead; do not re-fund it |
| `Cites: [[x]]` | evidence edge — restate the number at the citing site, never outsource it |

- A `[[slug]]` with no target yet is fine — it marks a node worth writing
  (`graph.py orphans` lists them).
- Superseded nodes are **never edited or deleted**. They get one italic banner —
  *Superseded by [[x]] (date): numbers below are old-convention.* — and stay.
  History is append-only; correction happens forward.

## WORKLOG.md — the router

Append-only, newest **last**, at the project's reports root.

```markdown
## YYYY-MM-DD — slug
- **STATUS:** ALIVE | DEAD | WATCH | FROZEN
- tried → why → result, one line
- **Pointer:** path/to/node.md#section
```

Rules:

- **WORKLOG is routing, nodes are truth.** Any number in the log is a dated
  hint — ground in the pointed node before acting on it.
- The log is never edited retroactively; stale entries are corrected by newer
  entries. (Same mechanics as supersession banners — and it makes concurrent
  sessions safe: appends to the tail merge trivially.)
- **Session start: read the tail** (~last 10 entries). Re-read it again right
  before appending, to catch entries from concurrent sessions.
- **Task end / before any context compaction: append an entry.** A finding that
  lives only in a context window is not recorded.
- Kills always get an entry. The deterministic kill-list push is the system's
  highest-value function: retrieval is *pull* and only answers questions you
  thought to ask — the do-not-re-fund list has to arrive *unprompted*.

## Traversal

`grep` answers most queries (`grep -rn "\[\[slug\]\]"` = incoming edges).
For the rest:

```bash
python3 graph.py <vault-dir> neighbors <slug> [--hops N]   # nodes within N hops
python3 graph.py <vault-dir> dead                          # every kill edge
python3 graph.py <vault-dir> orphans                       # linked but unwritten nodes
```

Stdlib only, no dependencies. Re-parses the vault every run; if a vault ever
outgrows that, emit SQLite *derived from the markdown* — gitignored, never
authoritative.

## Adopting in a project

Default home is a **`.mdgraph/` directory at the repo root** — `WORKLOG.md` plus
one node file per finding, committed with the repo (so it clones, versions, and
stays private exactly when the repo does). Cross-repo queries need no central
store: run `graph.py` on a parent directory (`~/Projects`) and every repo's
`.mdgraph/` is swept in one pass; `[[slug]]` resolution is name-based, so links
work across repos. A repo whose truth layer already exists elsewhere (a reports
tree) declares that override in its CLAUDE.md instead — never duplicate an
existing truth layer into `.mdgraph/`.

1. Create `.mdgraph/WORKLOG.md` with the entry format at top.
2. Add to the project's agent instructions (e.g. `CLAUDE.md`): read the WORKLOG
   tail at session start; append at task end / before compacting; nodes are
   append-only with supersession banners.
3. Backfill one WORKLOG entry per existing report — status word, tried→why→
   result, pointer. Kills first; they are the do-not-re-fund list.

## Using with Claude Code

Drop `SKILL.md` + `graph.py` into `~/.claude/skills/mdgraph/` (or symlink this
repo there). The skill teaches the conventions; the script does the traversal.

## Why not a database?

Markdown *is* the database: git-versioned, greppable, diffable, human-auditable,
and readable by an agent with no tool layer. A DB as primary storage re-creates
the failure mode this replaces — an opaque store with machinery between you and
your own knowledge. Databases here are views, and views are disposable.
