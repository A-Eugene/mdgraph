---
name: mdgraph
description: >-
  How to WRITE a repository's long-term memory: an append-only WORKLOG that
  routes to evidence, plus the `#constraint` tag for facts that must never age
  out of context. Use it whenever something is about to be written down for a
  future session — a run that finished and its numbers, a pursuit that ended,
  a constraint learned the hard way, a correction to an earlier entry, or a
  last note before compacting context. Use it before proposing, pricing, or
  shortlisting any option — a firm, a vendor, a library, a venue — since a
  recorded constraint may already rule a candidate out. Use it when setting up
  memory in a repo that has none. Reading an existing vault needs no skill:
  grep it.
---

# mdgraph

Plain markdown you write yourself. No model sits between a finding and its
storage, so nothing is lost in extraction and a write costs nothing.

**Entries are informative, never argumentative.** Record what happened with
enough mechanism and number that a future reader can infer the conclusion —
never write the conclusion as a judgment. "p99 went 4.2s → 11s: retries stacked
behind the same lock" carries everything; "DEAD — do not re-attempt" is an
opinion and does not belong.

A decision belongs only when you can name **who or what made it**: a stopping
rule declared before the test ran, an operator's call, a date something was
adopted. Those are facts about the world. A session that reads a result and
concludes the work should stop has not observed a decision, it has made one,
and writing it as a decision hides whose it was. Record the number and the
mechanism, name the authority if there was one, and leave the conclusion to
the reader.

## Storage

A git repo gets a dedicated orphan branch `mdgraph`, checked out as a sibling
worktree. Anything else gets a plain `<repo>/.mdgraph/` directory. Not a
preference — the only question ever put to the user is whether to keep a vault
at all, and it is asked at the first write, never on arrival.

    git switch --orphan mdgraph && git commit --allow-empty -m "vault" && git switch -
    git worktree add ../<repo>-mdgraph mdgraph

Beside the repo, not inside — inside, `git clean -ffxd` can remove it. Find it
by asking git, never by guessing a name:

    git -C <repo> worktree list --porcelain |
      awk '/^worktree /{w=$2} /^branch refs\/heads\/mdgraph$/{print w; exit}'

Commit with `git -C <vault> commit`, push like any branch. **Never create a
vault inside a vault** — if a `WORKLOG.md` already exists at or above you, that
is the vault. A nested one indexes under its own name and reads as a separate
project, so the corpus splits with no error to notice.

The layout inside:

    WORKLOG.md          append-only ledger: what happened, in order
    WORKLOG-<area>.md   optional per-area ledger, so tail-reads stay short
    notes/<slug>.md     optional longer write-ups; link them as [[slug]]

## The registry

`~/.claude/mdgraph-registry.txt`, tab-separated:
`<project-abs-path> <mode> <vault-abs-path> <YYYY-MM-DD>`, mode one of
`branch | plain | declined`. A line means the project was already asked, so
nothing re-prompts; `declined` means never auto-prompt again. Fill the vault
path only when the conventions above would not find it.

## The rules

1. **Append-only, because the log is shared.** Other sessions have this file
   open. An append is one small write; an in-place edit is read-modify-write
   and silently drops anything that landed in between. Git already holds the
   history; what an in-place edit destroys is a concurrent write. Corrections are new
   entries: a heading, what was wrong, the corrected number. Nothing is ever
   rewritten.
2. **The log routes; the evidence is elsewhere.** End each entry with a
   `**Pointer:**` line naming where the evidence lives — a notebook, a repo
   file, a note in `notes/`, or honestly "this entry" when the entry is all
   there is. A number in the log is a dated hint; open the pointed thing
   before acting on it.
3. **Write when a future session would otherwise repeat the work.** A result
   and its numbers, a dead end, a constraint found the hard way — yes.
   Progress narration ("refactored the parser") — no. Nothing is ever marked
   closed: a heading that states what was tried and what came back is what
   stops the work being repeated, and it leaves the reader free to disagree.
4. **Standing constraints get `#constraint`.** Most entries are events and may
   age out of the injected index; a precondition must not. Start a bullet with
   `#constraint` and the SessionStart hook prints it in full forever. Keep the
   set small — every tagged line is in every session. State the rule, point at
   the entries, and never copy result details up into the tag where later
   corrections cannot reach them.

5. **Date everything, in the text.** A WORKLOG heading is
   `## YYYY-MM-DD — what happened`. A note opens with a `Date: YYYY-MM-DD`
   line under its title, and every later addition to that note carries its own
   date. File mtimes do not survive a clone and git dates describe the commit,
   not the finding — so the date has to be in the prose or it is gone. Without
   it a reader cannot tell a result from last week from one from last year,
   and staleness becomes invisible.

## Entry shapes

```markdown
## 2026-03-14 — retry-backoff
- Tried exponential backoff on the upload queue to cut 429s → p99 4.2s → 11s:
  retries stacked behind the same lock. Pursuit stopped on this result.
- **Pointer:** notes/upload-queue-contention.md

## 2026-03-19 — systemd-path
- A systemd unit's PATH omits `~/.local/bin`, so a binary installed there is
  not found under systemd-run even though an interactive shell resolves it.
- **Pointer:** this entry

## 2026-03-22 — retry-backoff, corrected
- The 11s p99 above was a measurement artifact: the load generator shared the
  lock it measured. Separate generator: p99 4.2s → 4.4s, no regression.
- **Pointer:** notes/upload-queue-contention.md
```

A note under `notes/`:

```markdown
# Upload queue contention

Date: 2026-03-14

The upload path serialises on one lock ... (what was found, with numbers)

Date: 2026-03-22 — the 11s figure above came from a generator sharing the lock.
Re-measured at 4.4s.
```

## Housekeeping

- Log grew long → roll: `git mv WORKLOG.md WORKLOG-2026.md`, start a fresh
  tail. Old entries stay greppable.
- A secret landed in an entry → redact and rotate the credential; git history
  has the old copy either way, so rotation is the real fix.
- Genuinely junk (mis-fire, duplicate) → delete it. Not everything written is
  a finding.
- A repo that already keeps findings elsewhere (a reports tree) keeps them
  there — one home per repo, not necessarily this one.

## Reading

No tooling. `grep -rn <term> <vault>` answers "did we try this"; the
SessionStart hook already injects each vault's recent headings and every
`#constraint` line into every session. Headings are the index — which is why a
heading should say what was tried and what came back, not just name a topic.
