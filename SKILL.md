---
name: mdgraph
description: >-
  Durable cross-session memory for any repository — an append-only WORKLOG plus
  linked markdown notes under `.mdgraph/`. Use when recording what was decided,
  tried, or killed; when asked "did we try this already", "why was that dropped",
  "what did we conclude"; when starting work in a repo that has a `.mdgraph/`
  directory; and before compacting context.
---

# mdgraph

Notes are markdown you write; edges are links you type. No model sits between a
finding and its storage, so nothing is lost in extraction and a write costs
nothing.

**Every entry carries a verdict.** Record what it *means*, not only what
happened — the interpretation is the one thing nothing else derives. Git
history, the transcript, and any code-graph tool already hold what happened.
"p99 went 4.2s → 11s" is data; "backoff made it worse because retries stack
behind the same lock, so the problem is contention, not rate" is memory. An
entry with no verdict is a log line, and you already have logs.

## Layout

```
<repo>/.mdgraph/WORKLOG.md        append-only ledger: what happened, in order
<repo>/.mdgraph/notes/<slug>.md   one finding / decision / kill per file
<repo>/.mdgraph/WORKLOG-<year>.md rolled tail, once the log gets long
```

The filename under `notes/` is the `[[slug]]` other notes link to, so name it
for the finding (`upload-queue-contention.md`), not for the date. Nothing stores
a graph — the edges are inside the notes, and `graph.py` keeps nothing between
runs.

Committed with the repo, so it clones, versions, and stays private exactly when
the repo does. **Rebinding:** if a repo already keeps its findings elsewhere
(a reports tree, a docs site), leave them there and record the location in that
repo's agent instructions — the point is one home per repo, not this one.

`graph.py` takes any directory, so pointing it at a parent sweeps every repo's
`.mdgraph/` at once. `[[slug]]` resolves by name, not path — links cross repos.

## The four rules that aren't default

1. **Append-only.** Never edit or delete a note to correct it. Add the new note,
   and put one italic banner atop the old one:
   *Superseded by [[new-slug]] (YYYY-MM-DD).* History is how you tell a finding
   from a finding that used to be true.
2. **The log routes; the notes are true.** Any number in WORKLOG is a dated
   hint. Open the pointed file before acting on it. Stale entries are corrected
   by newer entries, never rewritten in place — which also makes concurrent
   sessions safe, since appends to the tail merge cleanly.
3. **A kill is the highest-value entry.** Recording that something failed, with
   why, is what stops it being re-attempted. Every dead idea gets `Kills:` (see
   below) so the query finds it.
4. **Write when a future session would otherwise repeat the work.** That is the
   whole test. A decision, a result, a dead end, a constraint discovered the
   hard way — yes. Progress narration ("refactored the parser") — no.

## Removing things

Append-only governs corrections. It is not a ban on housekeeping.

- **Wrong, outdated, reversed** → supersede, never edit in place. The old entry
  is evidence of what was believed and why; deleting it destroys the reason the
  correction was needed, which is usually the more valuable half.
- **A secret landed in a note** → redact now, and treat the file as one copy of
  many: git history still has it, so removing the line is theater. Rotate the
  credential; rewrite history only if rotation is impossible.
- **Scope abandoned, or the log grew long** → roll, don't delete.
  `git mv .mdgraph/WORKLOG.md .mdgraph/WORKLOG-2026.md` and start a fresh tail.
  Old kills stay greppable and `graph.py` still sees them, while the tail-read
  stays cheap.
- **Genuinely junk** — a mis-fired entry, a duplicate, a note about work that
  never happened → delete it. Not everything written down is a finding.

## Edge syntax

Each on its own line. This is what `graph.py` parses, so the form is exact:

| syntax | meaning |
|---|---|
| `[[slug]]` | relates to |
| `Supersedes: [[x]]` / `Superseded-by: [[x]]` | this replaces that |
| `Kills: [[x]]` / `Killed-by: [[x]]` | that idea is dead |
| `Cites: [[x]]` | evidence — restate the number here, don't outsource it |

A `[[slug]]` with no file yet is fine; it marks a note worth writing, and
`graph.py orphans` lists them.

## WORKLOG entry

Newest entry last. Two shapes, depending on whether the thing has a lifecycle.

**Something you tried, that can live or die** — status earns its place here:

```markdown
## 2026-03-14 — retry-backoff
- **STATUS:** DEAD
- Tried exponential backoff on the upload queue to cut 429s → made the tail
  latency worse (p99 4.2s → 11s) because retries stacked behind the same lock.
- Kills: [[exponential-backoff-upload]]
- **Pointer:** .mdgraph/notes/upload-queue-contention.md
```

**Something you learned** — a measurement, a constraint, a trap. No lifecycle,
so no status; the verdict is in the prose:

```markdown
## 2026-03-19 — systemd-path
- A systemd unit's PATH omits `~/.local/bin`, so a binary installed there is
  not found under `systemd-run` even though it resolves in an interactive
  shell. Cost two silent failures before it was diagnosed.
- **Pointer:** .mdgraph/notes/minimal-environment-traps.md
```

**Status is optional**, and only discriminates for things you will revisit:
**ALIVE / DEAD / WATCH / FROZEN**. Something you merely learned has no lifecycle
— its validity is handled by supersession, not a status word, and tagging it
`ALIVE` says nothing. Optional status never means optional judgment: both shapes
state what the thing means, one of them just also tracks whether it's still live.

A DEAD entry does carry a `Kills:` edge, since the edge is what the query reads.

## Queries

```bash
python3 ~/.claude/skills/mdgraph/graph.py <dir> dead            # every kill, by edge and by status
python3 ~/.claude/skills/mdgraph/graph.py <dir> neighbors <slug> [--hops 2]
python3 ~/.claude/skills/mdgraph/graph.py <dir> orphans
```

Plain grep answers most questions (`grep -rn "\[\[slug\]\]"` finds incoming
edges). The script re-parses on every run and stores nothing; if a vault ever
outgrows that, emit SQLite derived from the markdown — gitignored, never
authoritative.
