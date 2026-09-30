---
name: mdgraph
description: >-
  Durable memory for a repository: one markdown file per thing worth
  remembering, linked by name, kept on a dedicated `mdgraph` branch. Load this
  skill whenever something should outlive the session: a result and its
  numbers, a question still open, a constraint learned the hard way, a decision
  and who made it, a trap that cost time, a correction to an earlier entry, or a
  last note before the context is compacted. Load it at the END of any
  substantive task in a repository that has a graph, even when nobody asked you
  to record anything, because that is the moment the knowledge would be lost.
  Load it before you propose, price or shortlist any option (a firm, a vendor, a
  library, a venue), since a recorded constraint may already rule a candidate
  out. Load it before you assert anything about past work, because a compacted
  session keeps its conclusions and loses the reasons behind them. Use it to set
  up memory in a repository that has none. Reading an existing graph needs no
  skill: grep it.
---

# mdgraph

mdgraph is plain markdown that you write yourself. No model sits between a
finding and the file it lands in, so nothing is lost in extraction and a write
costs nothing extra.

**Entries record what happened. They do not argue.** Give enough mechanism and
enough numbers that a reader can reach their own conclusion. "p99 went from
4.2 s to 11 s because retries stacked up behind the same lock" carries
everything. "DEAD, do not re-attempt" is an opinion, and it does not belong.
Never mark anything as closed.

Record a decision only when you can name **who or what made it**: a stopping
rule declared before the test ran, the operator's call, the date something was
adopted. Those are facts about the world. When a session reads a result and
concludes that the work should stop, it has not observed a decision. It has made
one. So record the number and the mechanism, name the authority if there was
one, and leave the conclusion to the reader.

## What an entry looks like

Each thing worth remembering gets its own file, flat at the root of the graph.
**The filename is the entry's identity and its link target**, so name it after
the thing, not the date:

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

**Both frontmatter fields are required.**

- `description` is one line that has to make sense on its own. It is the whole
  index: sessions read the descriptions and little else, so for most readers it
  is the entire entry. Say what you found, not what the entry is about.
- `date` is when you found it. File times do not survive a clone, and git dates
  describe the commit, so this is the only date that lasts.

**Frontmatter is what makes a file an entry.** A README or a scratch file at the
root of the graph has none, so nothing indexes it. That is the only boundary.
There is no directory rule to break, and no way to start a second graph by
accident.

Below the frontmatter, write what happened. Two optional lines can follow, one
pointing out of the graph and one pointing within it:

- `- **Source:**` says where the evidence lives: a notebook, a file in the
  repository, a URL, or simply "this entry" when the entry is all there is.
- `- **Relates:** [[name]]` names another entry in this graph, by its filename
  without the extension.

**Write `[[name]]` only when an entry with that name exists.** A notebook, a
topic or a concept with no entry of its own goes on the `Source:` line or in
plain text, never in brackets. A reader has to be able to follow any bracket
without checking it first, and a single bracket that leads nowhere means every
other bracket has to be checked too. Plain text costs nothing: the name can
still be grepped, and it still counts toward whatever refers to it.

## The rules

1. **One entry, one file, written once.** Two sessions writing at the same time
   touch different files, so they cannot collide. A correction is a new entry
   that links to the one it corrects, and the earlier entry stays exactly as it
   was written: it is what makes the correction make sense. The rule protects
   what the writer believed, not how they typed it, so a few things may be
   fixed in place because no claim changes: brackets around a word that never
   named an entry, a misspelled field name, a typo.
2. **Write when a future session would otherwise repeat the work.** That means a
   result and its numbers, a dead end, an open question, a constraint found the
   hard way, or a trap that cost an afternoon. Progress narration such as
   "refactored the parser" does not qualify.
3. **Date everything, in the text.** Put the date in `date:`, and put it in the
   prose wherever a number depends on when it was measured. Without dates, a
   session cannot tell last week's result from last year's, and nobody notices
   when an entry has gone stale.

## Where a graph lives

In a git repository, the graph lives on an orphan branch named `mdgraph`,
checked out as a worktree next to the repository. Anywhere else, it is a plain
`<repo>/.mdgraph/` directory. That choice is fixed, so the only question to ask
the user is whether to keep a graph at all, and the time to ask is the first
write, not the moment you arrive.

```
git switch --orphan mdgraph && git commit --allow-empty -m "graph" && git switch -
git worktree add ../<repo>-mdgraph mdgraph
```

Put the worktree beside the repository, not inside it. Inside, it would sit in
an ignored path, and `git clean -ffxd` would delete it. To find a graph, ask git
rather than guessing the directory name:

```
git -C <repo> worktree list --porcelain |
  awk '/^worktree /{w=$2} /^branch refs\/heads\/mdgraph$/{print w; exit}'
```

Commit with `git -C <graph> commit`, and push the branch like any other. If a
`WORKLOG.md` or entry files already exist in your directory or above it, that is
the graph. Starting a second one splits the memory in two: it gets indexed under
its own name and reads as a separate project, and nothing reports an error.

## The registry

`~/.claude/mdgraph-registry.txt` is tab-separated:
`<project-abs-path> <mode> <graph-abs-path> <YYYY-MM-DD>`, where mode is
`branch`, `plain` or `declined`. A line means the project has already been
asked, so nothing asks again. Fill in the graph path only when the conventions
above would not find it.

**The registry answers "was this project asked?", not "what graphs exist?"** A
graph created without a registry line is a normal graph, and the hooks index it
anyway because they resolve through git. So never treat the registry as an
inventory. To list every graph, look at the disk:

```bash
# worktrees on the mdgraph branch
for r in <projects>/*/; do
  git -C "$r" worktree list --porcelain 2>/dev/null |
    awk '/^worktree /{w=$2} /^branch refs\/heads\/mdgraph$/{print w; exit}'
done | sort -u
# plain graphs
find <projects> -maxdepth 3 -type d -name .mdgraph
```

Run both. The first misses plain graphs, and the second misses every branch
graph. Add a registry line for anything the scan finds that the registry lacks.
Getting this wrong fails silently: you conclude that a project has no memory
while the hooks have been indexing its entries in every session.

## Reading

Reading takes three exact operations. There is no similarity search, no query
layer and no tooling:

```bash
grep -rn "<term>" <graph>              # find a word
grep -rl "\[\[<name>\]\]" <graph>      # find what links to an entry
grep -h "^description:" <graph>/*.md   # the whole index
```

At the start of every session, a hook prints one line per graph on the host:
its name, how many entries it has, and its path. It does not print any
contents, because a graph is memory for one repository and a session working
elsewhere has no use for it. When you start working in a repository, read that
graph's index yourself with the third command. That read is what keeps a
standing constraint in front of you.

## Housekeeping

- If an entry is junk (a misfire, a duplicate, an entry about work that never
  happened), delete the file. Not everything recorded is worth keeping.
- If a secret ends up in an entry, redact it and rotate it. Git history keeps
  the old copy either way, so rotating is the real fix.
- A repository that already keeps its findings somewhere else keeps them there.
  Each repository needs one home for its memory, not necessarily this one.
