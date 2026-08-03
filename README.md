# mdgraph

Cross-session memory for a repository, in plain markdown. An append-only
WORKLOG plus linked notes under `.mdgraph/`. No model sits between a finding and
its storage, so nothing is lost in extraction and a write costs nothing.

The conventions themselves live in [`SKILL.md`](SKILL.md) — that file is the
contract, and this one is why it looks the way it does.

![architecture](architecture.svg)

## Why not an extraction engine

LLM memory engines (cognee, mem0, and kin) read your text, extract entities and
relations, and store the extraction. Three consequences, all measured or
structural rather than hypothetical:

- **Writes amplify.** Extraction *expands* — entities, relations, and summaries
  per chunk. On my own corpus that ran ~26× tokens out per token stored.
- **The payload is what survives, and it isn't your text.** A finding like
  "NFP killed at tick level, t=0.1–0.6, ZN-only" becomes triples that keep the
  nouns and drop the number, the threshold, and the verdict.
- **Merging destroys history.** Once a node is updated, what it used to say is
  gone — so you cannot rebuild the log from the graph.

mdgraph inverts each: the author draws the node boundaries, the payload never
passes through a model, and the graph is written in the text.

## The shape

```
log → view   cheap, lossless, repeatable
view → log   impossible
```

So the append-only text is the source of truth and every index is a cache.
`graph.py` holds to that literally — it re-parses on each run and stores nothing.

Three layers, and it matters which is which:

| layer | what | role |
|---|---|---|
| **notes** | `.mdgraph/notes/<slug>.md` | truth — verbatim, append-only, numbers with provenance |
| **WORKLOG** | `.mdgraph/WORKLOG.md` | router — dated verdicts and pointers, read on arrival |
| **queries** | `graph.py` output | cache — derived, disposable, never authoritative |

```
<repo>/.mdgraph/
├── WORKLOG.md              the router
├── WORKLOG-2026.md         rolled tail, once the log gets long
└── notes/
    ├── upload-queue-contention.md
    ├── pool-sizing.md          (superseded, banner on top, kept)
    └── pool-sizing-revised.md
```

The filename under `notes/` is the `[[slug]]` other notes link to — name it for
the finding, not the date. There is no `graphs/` directory because no graph is
ever stored: the edges live in the notes, and `graph.py` keeps nothing between
runs.

The router/truth split is the load-bearing one. Memory's job is not to hand you
the answer; it is to tell you where to look and whether looking is worth it. A
number in the log is a dated hint — the note it points at is what you act on.
That is also what keeps the two from drifting: only one of them is ever right by
construction.

## Why markdown and not a database

Markdown *is* the database: git-versioned, greppable, diffable, human-auditable,
and readable by an agent with no tool layer between. SQL is the right query
engine and the wrong source of truth — a store you author *into* becomes opaque
to `git diff` and to anyone reading it raw, which is the failure this replaces
with the LLM merely removed. If a vault outgrows a whole-directory rescan, emit
SQLite *derived* from the markdown: gitignored, rebuildable, never authoritative.

## Scope

Good at: durable conclusions, dead ends that must not be re-attempted, decisions
whose rationale outlives the session that made them.

Not this: an episodic record of everything that happened (your agent transcripts
already are that), nor a substitute for a project's existing docs. If a repo
already keeps findings somewhere, leave them there — one home per repo, not
necessarily this one.

## Install

```bash
mkdir -p ~/.claude/skills/mdgraph
cp SKILL.md graph.py ~/.claude/skills/mdgraph/
```

Then add the trigger to your always-loaded agent instructions — a skill body
only loads when the skill is invoked, so "read the WORKLOG on arrival" has to
live somewhere that is read on arrival:

> Any repo containing `.mdgraph/`: read the tail of `.mdgraph/WORKLOG.md` before
> substantive work; append an entry at task end if a future session would
> otherwise repeat the work.

In a project, create `.mdgraph/WORKLOG.md` and `.mdgraph/notes/`, then add
entries as findings land.
Backfilling existing work is optional — start with the kills, since those are
the entries that pay for themselves.
