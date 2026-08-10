---
name: mdgraph
description: >-
  Durable cross-session memory for any repository — an append-only WORKLOG plus
  linked markdown notes under `.mdgraph/`. Use when recording what was decided,
  tried, or ended; when asked "did we try this already", "why was that dropped",
  "what did we conclude"; when starting work in a repo that has a `.mdgraph/`
  directory; before compacting context; and BEFORE asserting or recommending
  anything that rests on past work — consult the vault, never reconstruct from
  memory.
---

# mdgraph

Notes are markdown you write; edges are links you type. No model sits between a
finding and its storage, so nothing is lost in extraction and a write costs
nothing.

**Entries are exposition, not opinion.** Record what happened with enough
mechanism and number that a future reader can infer the conclusion themselves —
never write the conclusion as a judgment. "p99 went 4.2s → 11s" alone is a log
line; add the mechanism — "retries stacked behind the same lock" — and the entry
now carries everything needed to infer what to do, without telling anyone what
to think. Decisions that actually happened are facts and belong ("pursuit
stopped after this result", "the operator hit the country wall at signup");
verdicts and directives ("DEAD — do not re-attempt", "deploy it") are opinions
and do not.

## Layout

```
<repo>/.mdgraph/WORKLOG.md        append-only ledger: what happened, in order
<repo>/.mdgraph/WORKLOG-<area>.md one ledger per implementation / sub-project
<repo>/.mdgraph/notes/<slug>.md   one finding / decision / ended pursuit — SHARED
<repo>/.mdgraph/WORKLOG-<year>.md rolled tail, once a log gets long
```

**One vault per repo; split the LOG by area, never the notes.** A repo whose
branches are separate implementations (a UI, a deployment, a research line)
gives each its own `WORKLOG-<area>.md` so the tail-read stays short and
relevant, while `notes/` stays common — a finding is a finding regardless of
which area uncovered it, and both areas must be able to cite the same
`[[slug]]`. Branches are not the unit of memory; the repo is the vault and the
area is the file.

The filename under `notes/` is the `[[slug]]` other notes link to, so name it
for the finding (`upload-queue-contention.md`), not for the date. Nothing stores
a graph — the edges are inside the notes, and `graph.py` keeps nothing between
runs.

**Storage — the vault branch (default for a git repo).** A vault committed on a
code branch is invisible from every other branch until a merge: entries written
on a feature branch silently vanish from the reader's view on main. So the vault
does NOT live on a code branch. It lives on its own orphan branch `mdgraph`,
checked out as a SIBLING worktree, with a `.mdgraph` symlink into each code
checkout and `.mdgraph` gitignored everywhere. Setup, once per repo:

    git switch --orphan mdgraph && git commit --allow-empty -m "vault" && git switch -
    printf '.mdgraph\n' >> .gitignore && printf '.mdgraph\n' >> .git/info/exclude
    git worktree add ../<repo>-mdgraph mdgraph
    ln -s "$PWD/../<repo>-mdgraph" .mdgraph          # and in every other checkout

Put the real worktree BESIDE the repo, not inside it. Inside, one checkout
becomes privileged — delete it and every other checkout's link dies — and the
mount sits in an ignored path where `git clean -ffxd` can remove it. Beside, no
checkout owns it. `.git/info/exclude` is worth setting too: it covers every
worktree at once, including branches you must not modify.

A branch can be checked out in only ONE worktree, which is why the others are
symlinks rather than mounts. Commits go `git -C .mdgraph add -A && git -C
.mdgraph commit`; push it like any branch. After a fresh clone, re-run the
`worktree add` + `ln -s` lines. Cost of the design: the vault no longer
snapshots with a code commit — entries are dated, which is the compensation.

**The symlink is discovery, not mechanism.** Writing straight to
`../<repo>-mdgraph/WORKLOG.md` is the same file, branch and commit. What
`.mdgraph` buys is that one rule — "a repo with a `.mdgraph/` has a vault" —
holds for all three storage modes, so every instruction, hook and query works
unchanged whether the vault is a plain directory, an in-tree folder, or a
branch worktree. So **look for `.mdgraph/` first and a sibling `<repo>-mdgraph`
second**: setup is two manual steps, and someone who runs `worktree add` but
skips `ln -s` would otherwise see no vault at all while its entries sit intact
on the branch. Missing memory that reads as "there was never any" is worse than
an error.

**Concurrent sessions** share that one physical vault. Appends coexist (that is
what append-only buys operationally, not just philosophically); a whole-file
rewrite clobbers, so never rewrite a WORKLOG to edit it. Two simultaneous
commits race on `index.lock` — transient, retry, or let the next commit sweep
up both entries.

**No git? Plain directory.** With no branches there is no visibility problem to
solve: just create `.mdgraph/` and use it. Say once, at setup, that it is not
versioned and will not travel — a real limitation, still far better than
nothing.

**Fallback — in-tree vault:** a repo with a single long-lived branch may simply
commit `.mdgraph/` on it. Migrate when a second long-lived branch starts
producing findings. **Rebinding:** if a repo already keeps its findings
elsewhere (a reports tree, a docs site), leave them there and record the
location in that repo's agent instructions — the point is one home per repo,
not this one.

## Adopting a vault in a project that has none

**Do not prompt on arrival.** Most visits are "answer one question and leave",
and a setup dialog on entry is noise — noise is how a good habit gets switched
off. Prompt at the FIRST WRITE: the moment rule 4 fires and there is something a
future session would otherwise repeat. The question then arrives carrying its own
justification.

Ask once, offering: **branch** (orphan + sibling worktree — the default),
**in-tree** (single-branch repos), **plain** (not a git repo), or **no**.

Record the answer in `~/.claude/mdgraph-registry.json` so no project is asked
twice, across sessions:

```json
{"/abs/path/to/repo": {"mode": "branch", "since": "YYYY-MM-DD"},
 "/abs/path/to/other": {"mode": "declined", "since": "YYYY-MM-DD"}}
```

`declined` means never auto-prompt there again; an explicit request from the
user always overrides. Keep this registry OUTSIDE the skill directory — that
directory is a copy of an upstream repo, so state written there can be clobbered
by a re-sync or, worse, committed upstream and publish local paths.

## Reading and writing across areas

- **On entering a repo:** tail-read the log for the area you are working in
  (`WORKLOG-platform.md` for platform work, `WORKLOG.md` otherwise), ~10 entries.
- **Before asserting anything about past work:** grep the WHOLE `.mdgraph/` —
  every log and every note. `grep -rn` spans them; `graph.py` reads all `*.md`
  under the vault, so edges resolve across files with no configuration.
- **Writing — one question decides the file: who reads this next?** Only a
  future session in that area → its own log. The framework, a shared component,
  or a decision that binds other areas → `WORKLOG.md`. Both → the main log, and
  link it from the other. Notes are always shared.

`graph.py` takes any directory, so pointing it at a parent sweeps every repo's
`.mdgraph/` at once (worktree mounts included — they are real directories).
`[[slug]]` resolves by name, not path — links cross repos.

## The five rules that aren't default

0. **Consult before asserting.** Any claim about past decisions, results, or why
   something was rejected gets a vault grep *first* — `dead` for ended pursuits,
   `grep -in <term> WORKLOG.md` for rationale. A compressed memory of a conclusion
   without its reason is how rationales get fabricated around true facts: the vault
   holds the reason precisely so it never has to be reconstructed. (Learned twice on
   2026-08-07: an already-ended pursuit re-recommended, a recorded jurisdiction rationale
   replaced with an invented one.)
1. **Append-only.** Never edit or delete a note to correct it. Add the new note,
   and put one italic banner atop the old one:
   *Superseded by [[new-slug]] (YYYY-MM-DD).* History is how you tell a finding
   from a finding that used to be true.
2. **The log routes; the notes carry the detail.** Any number in WORKLOG is a
   dated hint. Open the pointed file before acting on it. Neither layer is
   "true" — a note records what was found and when, and a later note can
   supersede it. Stale entries are corrected by newer entries, never rewritten
   in place, which also makes concurrent sessions safe since appends to the
   tail merge cleanly.
3. **An ended pursuit is the highest-value entry.** Recording that an attempt
   ended, with the result and the mechanism that ended it, is what stops the
   work being repeated. Every ended pursuit gets `Kills:` (see below) — the
   edge records the decision event, and the query finds it.
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
  Old entries stay greppable and `graph.py` still sees them, while the tail-read
  stays cheap.
- **Genuinely junk** — a mis-fired entry, a duplicate, a note about work that
  never happened → delete it. Not everything written down is a finding.

## Edge syntax

Each on its own line. This is what `graph.py` parses, so the form is exact:

| syntax | meaning |
|---|---|
| `[[slug]]` | relates to |
| `Supersedes: [[x]]` / `Superseded-by: [[x]]` | this replaces that |
| `Kills: [[x]]` / `Killed-by: [[x]]` | pursuit of that idea ended here |
| `Cites: [[x]]` | evidence — restate the number here, don't outsource it |

A `[[slug]]` with no file yet is fine; it marks a note worth writing, and
`graph.py orphans` lists them.

## WORKLOG entry

Newest entry last. Two shapes, both pure exposition.

**Something you tried** — what was tried, the result with its numbers, the
mechanism, and the decision event if one occurred. No status words, no verdict
sentences — the reader infers:

```markdown
## 2026-03-14 — retry-backoff
- Tried exponential backoff on the upload queue to cut 429s → tail latency
  worsened (p99 4.2s → 11s): retries stacked behind the same lock. Pursuit
  stopped on this result.
- Kills: [[exponential-backoff-upload]]
- **Pointer:** .mdgraph/notes/upload-queue-contention.md
```

**Something you learned** — a measurement, a constraint, a trap:

```markdown
## 2026-03-19 — systemd-path
- A systemd unit's PATH omits `~/.local/bin`, so a binary installed there is
  not found under `systemd-run` even though it resolves in an interactive
  shell. Cost two silent failures before it was diagnosed.
- **Pointer:** .mdgraph/notes/minimal-environment-traps.md
```

**Keep an entry short.** A few lines carrying the numbers, the mechanism, and
the decision event — the detail belongs in the pointed note, not the log. The
tail-read is ten entries at a glance, so length in the log costs every future
reader; and a long entry is usually narration that rule 4 already excludes.

**No STATUS marks and no verdicts.** Lifecycle lives in the edges (`Kills:`,
`Superseded-by:`) and in later entries; a recorded decision ("pursuit stopped",
"adopted on date X by Y") is a fact — the judgment behind it stays with whoever
made it. An entry that ended a pursuit carries the `Kills:` edge, since the
edge is what the query reads.

## Queries

```bash
python3 ~/.claude/skills/mdgraph/graph.py <dir> dead            # every ended pursuit, by edge (legacy STATUS also parsed)
python3 ~/.claude/skills/mdgraph/graph.py <dir> neighbors <slug> [--hops 2]
python3 ~/.claude/skills/mdgraph/graph.py <dir> orphans
```

Plain grep answers most questions (`grep -rn "\[\[slug\]\]"` finds incoming
edges). The script re-parses on every run and stores nothing; if a vault ever
outgrows that, emit SQLite derived from the markdown — gitignored, never
authoritative.
