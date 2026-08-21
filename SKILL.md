---
name: mdgraph
description: >-
  Durable cross-session memory for any repository — an append-only WORKLOG plus
  linked markdown notes, kept on their own `mdgraph` branch (or in `.mdgraph/`).
  Use when recording what was decided, tried, or ended; when asked "did we try
  this already", "why was that dropped", "what did we conclude"; when starting
  work in a repo that has a vault; before compacting context; BEFORE
  asserting or recommending anything that rests on past work; and before you
  propose, price, compare, shortlist, or recommend an option of any kind — a
  firm, a vendor, a broker, a venue, a library, a data source — even when the
  work feels new and nobody has mentioned the past. Undertriggering is the known
  failure mode here, so when in doubt, consult the vault.
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

At the vault root — `../<repo>-mdgraph/` on the `mdgraph` branch for a git repo,
`<repo>/.mdgraph/` when the project is not a git repo:

```
WORKLOG.md            append-only ledger: what happened, in order
WORKLOG-<area>.md     one ledger per implementation / sub-project
notes/<slug>.md       one finding / decision / ended pursuit — SHARED
WORKLOG-<year>.md     rolled tail, once a log gets long
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

**Storage follows the project, and is not a preference.** A git repo gets the
vault branch; anything else gets a plain directory. Nothing to choose — the only
question put to the user is whether to keep a vault at all.

**Git repo — the `mdgraph` branch.** A vault committed on a code branch is
invisible from every other branch until a merge: entries written on a feature
branch silently vanish from the reader's view on main. So the vault does NOT
live on a code branch. It lives on its own orphan branch `mdgraph`, checked out
as a sibling worktree. Setup, once per repo, two commands:

    git switch --orphan mdgraph && git commit --allow-empty -m "vault" && git switch -
    git worktree add ../<repo>-mdgraph mdgraph

Put it BESIDE the repo, not inside. Inside, the mount sits in an ignored path
where `git clean -ffxd` can remove it, and one checkout becomes privileged.
Beside, no checkout owns it and every worktree reaches it equally.

**Finding it: ask git, never guess a path.**

    git -C <repo> worktree list --porcelain |
      awk '/^worktree /{w=$2} /^branch refs\/heads\/mdgraph$/{print w; exit}'

This answers correctly from ANY worktree of the repo. A sibling-name rule looks
equivalent and is not: from a checkout named `foo-news` it resolves
`foo-news-mdgraph`, finds nothing, and reports no vault while the entries sit in
`foo-mdgraph`. Memory that reads as "there was never any" is worse than an error.

No symlink and no `.mdgraph` entry in `.gitignore` are needed for this mode —
the vault is outside the repo, so nothing to ignore and nothing to link.
Read and write it at the path git reports; commit with `git -C <vault> commit`
and push it like any branch. After a fresh clone, re-run the `worktree add` line
alone. Cost of the design: the vault no longer snapshots with a code commit —
entries are dated, which is the compensation.

**Not a git repo — a plain `.mdgraph/` directory.** No branches, so there is no
visibility problem to solve: create it and use it. Say once, at setup, that it
is not versioned and will not travel — a real limitation, still far better than
nothing.

**An in-tree `.mdgraph/` inside a git repo is the pre-2026-08 layout.** Offer to
migrate it to the branch, so one repo does not carry two conventions. Copy the
logs and notes onto the branch, then remove the in-tree copy — and make the copy
and the removal ONE operation. If they are separated, entries written in between
are dropped and the migrated ledger still looks complete, which is the failure
that is hard to notice. Verify by diffing against the source's last state:
`git show <removal-commit>~1:.mdgraph/WORKLOG.md`. The old entries stay in that
branch's history either way.

**Concurrent sessions** share that one physical vault. Appends coexist (that is
what append-only buys operationally, not just philosophically); a whole-file
rewrite clobbers, so never rewrite a WORKLOG to edit it. Two simultaneous
commits race on `index.lock` — transient, retry, or let the next commit sweep
up both entries.

**Rebinding:** if a repo already keeps its findings elsewhere (a reports tree, a
docs site), leave them there and record the location in that repo's agent
instructions — the point is one home per repo, not this one.

## Adopting a vault in a project that has none

**Do not prompt on arrival.** Most visits are "answer one question and leave",
and a setup dialog on entry is noise — noise is how a good habit gets switched
off. Prompt at the FIRST WRITE: the moment rule 4 fires and there is something a
future session would otherwise repeat. The question then arrives carrying its own
justification.

**Never create a vault inside a vault.** Before setting one up, check that you are
not already in one: a `WORKLOG.md` at the directory root, or a vault directory at or
above the current path. `hooks/mdgraph-vault.sh` answers this. Getting it wrong fails
quietly — the nested vault indexes under its own name, reads as a separate project,
and the corpus splits in two without any error. (Observed 2026-08-14: a nested vault
reached 18 entries before anyone noticed it was not the real one.)

**Always ask; ask only the question that is actually open.** That question is
whether to keep a vault here at all — yes or no. Which storage it uses is not a
question: git repo → the branch, otherwise → a plain directory. State which one
it will be, get the yes, then set it up. Never create a vault unasked.

## The registry

`~/.claude/mdgraph-registry.txt`, tab-separated, one line per project:

```
<project-abs-path>	<mode>	<vault-abs-path>	<YYYY-MM-DD>
```

`mode` is `branch` | `plain` | `declined` (`in-tree` appears in older rows and is
still read). It does two jobs:

- **Answers "was this project asked?"** — a line means yes, so nothing is
  re-prompted across sessions. `declined` means never auto-prompt again; an
  explicit request from the user always overrides.
- **Answers "where is the vault?"** — fill the third column when the path is
  unconventional, or leave it EMPTY to fall through to `.mdgraph/` and then the
  git query. This is the only way to express a vault that neither convention
  finds: a hand-named worktree, a vault outside the project tree, one shared by
  several repos.

Plain text rather than JSON, for the same reason the vault is markdown: greppable,
appendable with `>>`, editable by hand, diffable. Keep it OUTSIDE the skill
directory — that directory is a copy of an upstream repo, so state written there
can be clobbered by a re-sync or committed upstream and publish local paths.

## Reading and writing across areas

- **On entering a repo:** resolve the vault (registry -> `.mdgraph/` -> git query;
  `hooks/mdgraph-vault.sh` is that resolver), then tail-read the log for the area you
  are working in (`WORKLOG-<area>.md` where one exists, `WORKLOG.md` otherwise),
  ~10 entries. No vault and no registry line: the project has never been asked.
- **Before asserting anything about past work:** grep the WHOLE `.mdgraph/` —
  every log and every note. `grep -rn` spans them; `graph.py` reads all `*.md`
  under the vault, so edges resolve across files with no configuration.
- **Writing — one question decides the file: who reads this next?** Only a
  future session in that area → its own log. The framework, a shared component,
  or a decision that binds other areas → `WORKLOG.md`. Both → the main log, and
  link it from the other. Notes are always shared.

`graph.py` takes any directory, so pointing it at a parent sweeps every vault at
once — sibling `<repo>-mdgraph` worktrees and `.mdgraph/` directories alike, since
both are ordinary directories of markdown. `[[slug]]` resolves by name, not path,
so links cross repos.

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

## Standing constraints

Most entries are events: something happened, on a date. A few are **preconditions** —
facts that bind every later decision and never expire. Where the operator lives. A
latency budget. A licence term. A hardware limit.

A dated log ages a precondition at the same rate as everything else, and that is
backwards. The log is read newest-first, and a precondition is most needed long after
it was written, by someone who does not know to look for it.

Tag those lines `#constraint`. The SessionStart hook prints every tagged line in full
and ignores the tail window, so the fact stays in context however long the log grows.

```markdown
- #constraint The operator is resident in Indonesia. Check any prop firm against that
  firm's own restricted-country page before you propose, price, or survey it. Per-firm
  results are in the cited entries. Do not restate a firm's status from memory.
- Cites: [[eval-convexity-firm-survey]]
```

State the rule and cite the entries. Do not copy the per-firm results up here — that
duplicates a fact that later entries may correct, and the copy will not be corrected
with them.

Keep the set small. Every tagged line is in every session forever. The test: would a
session that did not know this produce work you have to throw away?

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

**Something that corrects an earlier entry** — the shape rule 1 asks for. The old
entry is never edited; it gets a banner and stays:

```markdown
## 2026-03-22 — upload-retry, corrected
- The 11s p99 in [[retry-backoff]] was a measurement artifact. The load generator
  shared the lock it was measuring. Re-run with a separate generator: p99 4.2s → 4.4s,
  no regression. The backoff change was reverted for a reason that did not hold.
- Supersedes: [[retry-backoff]]
- **Pointer:** .mdgraph/notes/upload-queue-contention.md
```

Then one italic line at the top of the superseded note, and nothing else changes:
*Superseded by [[upload-retry-corrected]] (2026-03-22).*

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
