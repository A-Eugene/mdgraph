---
name: mdgraph
description: >-
  Durable memory for a repository — one markdown file per thing worth
  remembering, linked by name, kept on a dedicated `mdgraph` branch. Use it
  whenever something should outlive this session: a result and its numbers, a
  question still open, a constraint learned the hard way, a decision and who
  made it, a trap that cost time, a correction to an earlier entry, or a last
  note before compacting context. Use it before proposing, pricing, or
  shortlisting any option — a firm, a vendor, a library, a venue — since a
  recorded constraint may already rule a candidate out. Use it when setting up
  memory in a repo that has none. Reading an existing vault needs no skill:
  grep it.
---

# mdgraph

Plain markdown you write yourself. No model sits between a finding and its
storage, so nothing is lost in extraction and a write costs nothing.

**Entries are informative, never argumentative.** Record what happened with
enough mechanism and number that a reader can draw their own conclusion. "p99
went 4.2s → 11s: retries stacked behind the same lock" carries everything;
"DEAD — do not re-attempt" is an opinion and does not belong. Nothing is ever
marked closed.

A decision belongs only when you can name **who or what made it**: a stopping
rule declared before the test ran, an operator's call, a date something was
adopted. Those are facts about the world. A session that reads a result and
concludes the work should stop has not observed a decision, it has made one.
Record the number and the mechanism, name the authority if there was one, and
leave the conclusion to the reader.

## An entry

One file per thing worth remembering, flat at the vault root. **The filename is
the identity and the link target**, so name it for the thing, not the date:

```markdown
---
description: MGC Tokyo burst fade and continuation — five constructions, none survives a split
date: 2026-08-21
---

Tried absorption-timing fade and continuation on MGC Tokyo bursts. Five
constructions, train/test split on the 2024-2026 cohort. Best cell reached
t=1.4 in-sample and 0.2 out. The burst itself is real; the direction is not.

Source: src/notebooks/reports/topics/mgc_tokyo/mgc_tokyo.ipynb
Relates: [[mgc-open-one-sided-commitment]]
```

**Two fields, both required.**

- `description` — one line, written to be read on its own. This is the whole
  index: every session gets every description, so it is the only part of the
  entry most readers will ever see. Say what was found, not what the entry is
  about.
- `date` — when it was found. File times do not survive a clone and git dates
  describe the commit, so this is the only durable one.

**Frontmatter is what makes a file an entry.** A README or a scratch file at the
vault root has none and is ignored. Nothing else marks the boundary — no
directory rule to violate, and no way to grow a second vault by accident.

Below the fields, write what happened. Point at the evidence wherever it
lives — a notebook, a repo file, a URL — or say plainly that the entry is all
there is. Link related entries with `[[filename-without-extension]]`.

## The rules

1. **One entry, one file, written once.** Two sessions writing at the same time
   touch different files, so there is nothing to collide. Corrections are new
   entries that link the old one; the old entry stays as written. Do not edit an
   entry to fix it — the record of what was believed is the thing that makes the
   correction legible.
2. **Write when a future session would otherwise repeat the work.** A result and
   its numbers, a dead end, an open question, a constraint found the hard way,
   a trap that cost an afternoon — yes. Progress narration ("refactored the
   parser") — no.
3. **Date everything, in the text.** Both in `date:` and in prose where a number
   is time-sensitive. Without it a reader cannot tell last week's result from
   last year's, and staleness becomes invisible.

## Storage

A git repo gets an orphan branch `mdgraph`, checked out as a sibling worktree.
Anything else gets a plain `<repo>/.mdgraph/` directory. Not a preference. The
only question ever put to the user is whether to keep a vault at all, and it is
asked at the first write, never on arrival.

```
git switch --orphan mdgraph && git commit --allow-empty -m "vault" && git switch -
git worktree add ../<repo>-mdgraph mdgraph
```

Beside the repo, not inside — inside, it sits in an ignored path that
`git clean -ffxd` removes. Find it by asking git, never by guessing a name:

```
git -C <repo> worktree list --porcelain |
  awk '/^worktree /{w=$2} /^branch refs\/heads\/mdgraph$/{print w; exit}'
```

Commit with `git -C <vault> commit` and push it like any branch. If a
`WORKLOG.md` or entry files already exist at or above you, that is the vault. A
second one indexes under its own name and reads as a separate project, so the
corpus splits with no error to notice.

## The registry

`~/.claude/mdgraph-registry.txt`, tab-separated:
`<project-abs-path> <mode> <vault-abs-path> <YYYY-MM-DD>`, mode one of
`branch | plain | declined`. A line means the project was already asked, so
nothing re-prompts. Fill the vault path only when the conventions above would
not find it.

## Reading

Three exact operations. No similarity, no query layer, no tooling:

```bash
grep -rn "<term>" <vault>              # lexical
grep -rl "\[\[<name>\]\]" <vault>      # structural: what references this
grep -h "^description:" <vault>/*.md   # the whole index, on demand
```

The SessionStart hook already prints every entry's description, so a session
arrives knowing what the vault holds and greps for the rest.

## Housekeeping

- Junk — a mis-fire, a duplicate, an entry about work that never happened →
  delete the file. Not everything written down is worth keeping.
- A secret landed in an entry → redact and rotate the credential. Git history
  holds the old copy either way, so rotation is the real fix.
- A repo that already keeps findings elsewhere keeps them there. One home per
  repo, not necessarily this one.
