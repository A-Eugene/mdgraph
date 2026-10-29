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
  session keeps its conclusions and loses the reasons behind them. Load it when
  `mdgraph check` reports problems or a graph looks broken. Use it to set up
  memory in a repository that has none. Reading an existing graph needs no
  skill: run `mdgraph index` or grep it.
---

# mdgraph

mdgraph is plain markdown that you write yourself. No model sits between a
finding and its file, so extraction loses nothing and a write costs nothing
extra.

The `mdgraph` CLI does every operation below. It is `bin/mdgraph` inside this
skill's folder. In Claude Code's plugin install, `mdgraph` is also on the Bash
tool's `PATH`. Otherwise call it by its full path, which the session-start card
prints. `-g <repo>` picks a graph by repository path, graph path or repository
name. Without `-g`, the CLI uses the graph of the current directory.

**Without hooks,** nothing prints the session-start card and nothing holds your
first write. This happens in an agent that runs no hooks, such as Antigravity.
Do the hooks' work yourself: run `mdgraph list` once per session, and run
`mdgraph -g <repo> index` before your first change in a repository.

**Entries record what happened. They do not argue.** Give enough mechanism and
numbers for a reader to reach their own conclusion. "p99 went from 4.2 s to
11 s because retries stacked up behind the same lock" carries everything. "DEAD,
do not re-attempt" is an opinion and does not belong. Never mark anything
closed.

Record a decision only when you can name **who or what made it**: a stopping
rule declared before the test ran, the operator's call, the date something was
adopted. Those are facts about the world. A session that reads a result and
concludes the work should stop has not observed a decision. It has made one.
So record the number and the mechanism, name the authority if there was one,
and leave the conclusion to the reader.

## What an entry looks like

Each thing worth remembering gets its own file, flat at the graph root. **The
filename is the entry's identity and its link target**, so name it after the
thing, not the date:

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

- `description` is one sentence of under about 200 characters that makes sense
  alone. It is the whole index. Sessions read descriptions and little else, and
  every session that reads the index pays for every description. Say what you
  found, not what the entry is about.
- `date` is the day you found it. File times do not survive a clone, and git
  dates describe the commit, so this is the only date that lasts.

**Frontmatter makes a file an entry.** A README or scratch file at the graph
root has none, so nothing indexes it. That is the only boundary. No directory
rule exists to break, and you cannot start a second graph by accident.

Below the frontmatter, write what happened. **The body holds everything a reader
needs to reproduce the result or rule it out without you:** the setup, the
parameters, the numbers, the mechanism, and what was tried and failed. A body
costs nothing until someone opens it, so leave nothing out.

Two optional lines can follow. One points out of the graph, one points within
it:

- `- **Source:**` names where the evidence lives: a notebook, a file in the
  repository, a URL, or "this entry" when the entry is all there is.
- `- **Relates:** [[name]]` names another entry in this graph by its filename
  without the extension.

**Write `[[name]]` only when an entry with that name exists.** A notebook, topic
or concept with no entry of its own goes on the `Source:` line or in plain
text, never in brackets. A reader must be able to follow any bracket without
checking it first. One bracket that leads nowhere means every other bracket
needs checking too. Plain text costs nothing: grep still finds the name, and it
still counts toward whatever refers to it.

## Writing

```bash
mdgraph -g <repo> new <name> "<description>" <<'EOF'
<body>
EOF
mdgraph -g <repo> correct <old> <new> "<what changed>"
mdgraph -g <repo> commit ["<message>"]
```

- `new` writes `<name>.md` dated today. It refuses a name that exists, a name
  that is not lowercase words joined by `-`, a description over 200 characters
  or on several lines, and a `[[name]]` that names no entry.
- `correct` marks `<old>` as corrected by `<new>`, as rule 1 below describes.
  `<new>` must exist and must link `[[old]]`.
- `commit` commits only the graph's files. The default message lists the entry
  names.
- Writing a file by hand in the format above also works.

## The rules

1. **One entry, one file, written once.** Two sessions writing at once touch
   different files, so they cannot collide. A correction is a new entry that
   links the one it corrects. The earlier entry stays exactly as written,
   because it is what makes the correction make sense. The rule protects what
   the writer believed, not how they typed it. So you may fix a few things in
   place, since no claim changes: brackets around a word that never named an
   entry, a misspelled field name, a typo, and a description shortened to fit
   200 characters that still says the same thing.

   **Mark the corrected entry where the index shows it.** The writer of a
   correction puts `Corrected by [[new-name]] (YYYY-MM-DD): ` at the start of
   the earlier entry's description, and the same line at the top of its body.
   `mdgraph correct` does both. Sessions read the index and little else, so a
   correction that only links back stays invisible to a session that never
   opens the earlier entry. The marker is a pointer, not a claim, and it may
   push the description past 200 characters.
2. **Write when a future session would otherwise repeat the work.** That means
   a result and its numbers, a dead end, an open question, a constraint found
   the hard way, or a trap that cost an afternoon. Progress narration such as
   "refactored the parser" does not qualify.
3. **Date everything, in the text.** Put the date in `date:`. Also put it in the
   prose wherever a number depends on when it was measured. Without dates, a
   session cannot tell last week's result from last year's, and nobody notices
   when an entry goes stale.

## Where a graph lives

In a git repository, the graph lives on an orphan branch named `mdgraph`,
checked out as a worktree in the repository's folder. A repository keeps every
checkout in one folder, one subfolder per branch: `<repo>/main`,
`<repo>/mdgraph`. Anywhere else, the graph is a plain `<repo>/.mdgraph/`
directory. That choice is fixed. The only question for the user is whether to
keep a graph at all, and the time to ask is the first write, not the moment you
arrive.

```bash
git switch --orphan mdgraph && git commit --allow-empty -m "graph" && git switch -
git worktree add ../mdgraph mdgraph
```

Run it from a checkout inside the repository's folder, such as `<repo>/main`.
A repository that is still a single checkout moves into that layout first:

```bash
mv <repo> <repo>.tmp && mkdir <repo> && mv <repo>.tmp <repo>/main
git -C <repo>/main worktree repair
```

Put the worktree beside the checkout, not inside it. Inside, it would sit in an
ignored path, and `git clean -ffxd` would delete it. To find a graph, ask the
CLI with `mdgraph -g <repo> resolve`. It asks git, never guesses a directory
name. The git query it runs:

```bash
git -C <repo> worktree list --porcelain |
  awk '/^worktree /{w=$2} /^branch refs\/heads\/mdgraph$/{print w; exit}'
```

Push the branch like any other. If a `WORKLOG.md` or entry files already exist
in your directory or above it, that is the graph. A second one splits the
memory in two: it gets indexed under its own name, reads as a separate project,
and nothing reports an error.

## The registry

`~/.claude/mdgraph-registry.txt` is tab-separated:
`<project-abs-path> <mode> <graph-abs-path> <YYYY-MM-DD>`, where mode is
`branch`, `in-tree`, `plain` or `declined`. A line means someone already asked
the project, so nothing asks again. Fill in the graph path only when the
conventions above would not find it.

**The registry answers "was this project asked?", not "what graphs exist?"** A
graph created without a registry line is a normal graph, and the hooks index it
anyway because they resolve through git. Never treat the registry as an
inventory. `mdgraph list` scans the disk for both kinds of graph: worktrees on
the `mdgraph` branch and plain `.mdgraph/` directories. By hand, run both of
these, since the first misses plain graphs and the second misses every branch
graph:

```bash
for r in <projects>/*/; do
  git -C "$r" worktree list --porcelain 2>/dev/null |
    awk '/^worktree /{w=$2} /^branch refs\/heads\/mdgraph$/{print w; exit}'
done | sort -u
find <projects> -maxdepth 3 -type d -name .mdgraph
```

`mdgraph check --fix` adds a registry line for any graph the scan finds and the
registry lacks. Getting this wrong fails silently: you conclude that a project
has no memory while the hooks have indexed its entries in every session.

## Reading

Reading takes three operations. There is no similarity search and no query
layer. Each command wraps one grep:

| Command | What it prints | The grep it runs |
|---|---|---|
| `mdgraph index [topic]` | every entry name and description, or those matching `topic` | `grep -h "^description:" <graph>/*.md` |
| `mdgraph grep <term>` | matching lines in entry bodies | `grep -rn "<term>" <graph>` |
| `mdgraph refs <name>` | entries that link to `[[name]]` | `grep -rl "\[\[<name>\]\]" <graph>` |

Before any claim about past work, search entry bodies with `grep`, not only the
index. A description that starts with `Corrected by [[name]]` has a
correction: read that entry. Before relying on an entry, also run `refs` on its
name, since a later entry can qualify it without marking it corrected.

At the start of every session, a hook prints one line per graph on the machine:
its name, its entry count, and its path. It prints no contents, because a graph
is memory for one repository and a session working elsewhere has no use for it.
When you start work in a repository, read that graph's index yourself with
`mdgraph index`. Claude Code cuts a command's output past 30,000 characters
without warning. The startup line marks an index that long as too long to print
whole, and `mdgraph index` then refuses to print it. Filter it for your topic:
`mdgraph index <topic>`. That read keeps a standing constraint in front of you.
Until a session has read the index, the first write it makes in that repository
is refused, once, so that the read happens before the change.

## Checking and repairing

`mdgraph check` lists every problem in every graph on the machine, or in one
graph with `-g`. `mdgraph check --fix` repairs the problems that need no
judgement, then lists what is left. Run it after a crash, after editing entries
by hand, or when the startup line shows descriptions over 200 characters.

| Problem | What `--fix` does |
|---|---|
| A field is spelled `Description:` or `Date:` | Lowercases the field name. |
| The description spans several lines (`description: >-`) | Joins it onto one line. |
| No `date:` | Adds the day git first committed the file, or the file's modification day in a graph with no git history. |
| A date not in `YYYY-MM-DD` | Rewrites it, if `date -d` can read it. |
| A `[[name]]` with no entry | Points it at the entry whose name matches after lowercasing and dropping `.md`, `#section` or `\|alias`. Otherwise removes the brackets, which rule 1 allows. |
| `Corrected by` in the description but not at the top of the body | Adds the line to the body. |
| An entry in a subfolder | Moves it to the graph root, unless that name is taken. |
| Worktrees whose folders are gone | Runs `git worktree prune`. |
| An `mdgraph` branch with no worktree | Checks it out at `<repo folder>/mdgraph`. |
| A graph with no registry line | Appends one. |

Some problems need judgement, so `check` reports them and leaves them:

- A description over 200 characters. Shorten it in place with the same meaning.
- No description, several descriptions, or frontmatter that is missing or never
  closed.
- Uncommitted changes in a graph. Another session may be writing, so look
  before you commit.
- A registry line for a path or graph that does not exist, or for a branch graph
  checked out on another branch.
- A repository with both `.mdgraph/` and an `mdgraph` branch.

## Housekeeping

- If an entry is junk (a misfire, a duplicate, an entry about work that never
  happened), delete the file. Not everything recorded is worth keeping.
- If a secret ends up in an entry, redact it and rotate it. Git history keeps
  the old copy either way, so rotating is the real fix.
- A repository that already keeps its findings somewhere else keeps them there.
  Each repository needs one home for its memory, not necessarily this one.
