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

mdgraph is plain markdown that you write yourself. No model sits between a
finding and its storage, so extraction loses nothing and a write costs nothing.

**Entries are informative, never argumentative.** Record what happened with
enough mechanism and number that a reader can draw their own conclusion. "p99
went 4.2s → 11s: retries stacked behind the same lock" carries everything.
"DEAD — do not re-attempt" is an opinion and does not belong. Never mark anything
closed.

A decision belongs only when you can name **who or what made it**: a stopping
rule declared before the test ran, an operator's call, a date when something
was adopted. Those are facts about the world. A session that reads a result and
concludes that the work should stop does not observe a decision. It makes one.
Record the number and the mechanism. Name the authority if there was one.
Leave the conclusion to the reader.

## An entry

Write one file per thing worth remembering, flat at the vault root. **The
filename is the identity and the link target**, so name it for the thing, not
the date:

```markdown
---
description: MGC Tokyo burst fade and continuation — five constructions, none survives a split
date: 2026-08-21
---

Tried absorption-timing fade and continuation on MGC Tokyo bursts. Five
constructions, train/test split on the 2024-2026 cohort. Best cell reached
t=1.4 in-sample and 0.2 out. The burst is real. The direction is not.

- **Source:** src/notebooks/reports/topics/mgc_tokyo/mgc_tokyo.ipynb
- **Relates:** [[mgc-open-one-sided-commitment]]
```

**There are two fields, and both are required.**

- `description` — one line, written to be read on its own. This is the whole
  index: every session gets every description, so it is the only part of the
  entry that most readers will ever see. Say what you found, not what the
  entry is about.
- `date` — when you found it. File times do not survive a clone and git dates
  describe the commit, so this is the only durable one.

**Frontmatter is what makes a file an entry.** A README or a scratch file at the
vault root has no frontmatter, so no session indexes it. Nothing else marks the
boundary. There is no directory rule to violate, and there is no way to grow a
second vault by accident.

Below the fields, write what happened. Then there are two optional lines, one
pointing out of the vault and one pointing inside it:

- `- **Source:**` — where the evidence lives. It is a notebook, a repo file,
  a URL, or plainly "this entry" when the entry is all there is.
- `- **Relates:** [[name]]` — another entry in this vault, by filename without
  the extension.

**Write `[[name]]` only when an entry of that name exists.** A notebook, a
topic, or a concept that has no entry goes on `Source:` or in plain text,
never in brackets. A session must be able to follow any bracket without
checking it first. One bracket that does not resolve forces a session to check
every other bracket too. Plain text costs nothing: the name is still greppable and still
counts its referrers.

## The rules

1. **One entry, one file, written once.** Two sessions writing at the same time
   touch different files, so there is nothing to collide. Corrections are new
   entries that link the old one. The old entry stays as written. Do not edit an
   entry to fix it: the earlier entry is what makes the correction legible. This
   protects what the writer believed, not how the writer typed it. Fix these in
   place: a bracket around a word that never named an entry, a broken field
   name, a typo.
   No claim changes, so there is nothing for a correction entry to record.
2. **Write when a future session would otherwise repeat the work.** Write a
   result and its numbers, a dead end, an open question, a constraint found the
   hard way, or a trap that cost an afternoon. Do not write progress narration
   such as "refactored the parser".
3. **Date everything, in the text.** Put it in `date:`. Put it in the prose
   wherever a number is time-sensitive. Without a date, a session cannot tell
   last week's result from last year's result. Staleness then becomes
   invisible.

## Storage

A git repo gets an orphan branch `mdgraph`, checked out as a sibling worktree.
Anything else gets a plain `<repo>/.mdgraph/` directory. This is not a
preference. Ask the user only one question, ever: whether to keep a vault at
all. Ask it at the first write, never on arrival.

```
git switch --orphan mdgraph && git commit --allow-empty -m "vault" && git switch -
git worktree add ../<repo>-mdgraph mdgraph
```

The worktree goes beside the repo, not inside it. Inside, it sits in an
ignored path that `git clean -ffxd` removes. Find it by asking git, never by guessing a name:

```
git -C <repo> worktree list --porcelain |
  awk '/^worktree /{w=$2} /^branch refs\/heads\/mdgraph$/{print w; exit}'
```

Commit with `git -C <vault> commit`. Push it like any branch. If a
`WORKLOG.md` or entry files already exist at or above you, that is the vault. A
second one indexes under its own name and reads as a separate project, so the
corpus splits with no error to notice.

## The registry

The registry is `~/.claude/mdgraph-registry.txt`, tab-separated:
`<project-abs-path> <mode> <vault-abs-path> <YYYY-MM-DD>`, with mode one of
`branch | plain | declined`. A line means the project was already asked, so
nothing re-prompts. Fill the vault path only when the conventions above would
not find it.

**The registry answers "was this asked", not "what exists."** A vault created
without a registry line is a normal vault. The hooks resolve through git, so
they index it anyway. Never read the registry as an inventory. To list every
vault, ask the disk:

```bash
# sibling worktrees on the mdgraph branch
for r in <projects>/*/; do
  git -C "$r" worktree list --porcelain 2>/dev/null |
    awk '/^worktree /{w=$2} /^branch refs\/heads\/mdgraph$/{print w; exit}'
done | sort -u
# plain-mode vaults
find <projects> -maxdepth 3 -type d -name .mdgraph
```

Run both, not either: the first misses plain-mode vaults and the second misses
every branch vault. Append a registry line for anything the scan finds that the
registry lacks. Getting this wrong is quiet — you conclude that a project
has no memory while the hooks index its entries in every session.

## Reading

Reading uses three exact operations, with no similarity, no query layer, and
no tooling:

```bash
grep -rn "<term>" <vault>              # lexical
grep -rl "\[\[<name>\]\]" <vault>      # structural: what references this
grep -h "^description:" <vault>/*.md   # the whole index, on demand
```

The SessionStart hook prints one line per vault on the host: name, entry
count, path. It does not print contents, because a vault is memory for one
repository and a session outside that repository has no use for it. On entering
a repository, read that vault's index yourself — the third command above — and
you know what it holds. That read is what keeps a standing constraint in view.

## Housekeeping

- If an entry is junk — a mis-fire, a duplicate, an entry about work that
  never happened — delete the file. Not everything that you record is worth
  keeping.
- If a secret landed in an entry, redact the credential. Also rotate it. Git
  history holds the old copy either way, so rotation is the real fix.
- A repo that already keeps findings elsewhere keeps them there. Each repo gets one
  home, not necessarily this one.
