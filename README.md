# mdgraph

Cross-session memory for a repository, in plain markdown. An append-only
WORKLOG plus linked notes, kept on their own git branch. No model sits between a finding and
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
  "NFP on crypto perps netted 1–6 bps at tick level, t=0.1–0.6, so the pursuit
  stopped and the family stayed ZN-only" becomes triples that keep the nouns and
  drop the number, the threshold, and the mechanism.
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
| **notes** | `<vault>/notes/<slug>.md` | truth — verbatim, append-only, numbers with provenance |
| **WORKLOG** | `<vault>/WORKLOG.md` | router — dated exposition and pointers, read on arrival |
| **queries** | `graph.py` output | cache — derived, disposable, never authoritative |

```
<repo>-mdgraph/             the `mdgraph` branch, checked out beside the repo
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

Good at: durable findings, pursuits that ended and the mechanism that ended them,
decisions whose rationale outlives the session that made them.

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

> Any repo with a vault (an `mdgraph` branch worktree, or `.mdgraph/`): read its
> WORKLOG tail before
> substantive work; append an entry at task end if a future session would
> otherwise repeat the work.

In a project, ask first, then create the vault — `git worktree add ../<repo>-mdgraph mdgraph`
for a git repo, a plain `.mdgraph/` otherwise — with `WORKLOG.md` and `notes/`, and add
entries as findings land.
Backfilling existing work is optional — start with the ended pursuits, since those are
the entries that pay for themselves.

## Enforcement (hooks)

The skill text binds only when loaded, and it loads at write time — so the read-side
discipline (rule 0) gets a mechanical layer. Three scripts under `hooks/`. Copy them out, then register two of them in
`~/.claude/settings.json`:

```bash
mkdir -p ~/.claude/hooks && cp hooks/*.sh ~/.claude/hooks/
```

```json
"hooks": {
  "SessionStart": [{"hooks": [{"type": "command", "command": "$HOME/.claude/hooks/mdgraph-index.sh"}]}],
  "Stop":         [{"hooks": [{"type": "command", "command": "$HOME/.claude/hooks/mdgraph-nudge.sh"}]}]
}
```

`mdgraph-vault.sh` is not registered. The other two call it to resolve a vault, so it
must sit beside them.

Both scripts scan `/root/Projects/*/`. Change that glob to wherever your repos live —
it is the one path in this project that is not portable, and it is the first thing to
edit after copying.

- `mdgraph-index.sh` (SessionStart) — injects each vault's newest 45 WORKLOG headings,
  every `#constraint` line regardless of age, and the full `Kills:` list (~1–2k tokens).
  The constraint pass exists because a tail window ages out preconditions at the same
  rate as events, which is exactly backwards. Read-side: facts that are in
  context do not get fabricated around; out-of-context ones do — both 2026-08-07
  incidents were out-of-context assertions.
- `mdgraph-nudge.sh` (Stop) — warns when code commits have outpaced the WORKLOG.
  Write-side: existed since the format transition, sat unregistered until 2026-08-07.

Deployment: this repo is the source; `~/.claude/skills/mdgraph/` and
`~/.claude/hooks/` are copies. Edit here, commit, then copy out — never edit the
global copies directly.
