# mdgraph

Memory for a repository, kept as plain markdown files.

- One file per thing worth remembering.
- Files link to each other by name.
- The files live on their own `mdgraph` branch, checked out beside the repository.
- One CLI, `mdgraph`, reads, writes, checks and repairs them, and runs the Claude Code hooks.

[`SKILL.md`](skills/mdgraph/SKILL.md) holds the rules a session follows. This file explains the design.

![How a session, the graph, the repository and the hooks connect](architecture.svg)

## Start here

1. Install it for your agent, as described under [Install](#install).
2. Open a session. It prints the rules and the graphs on this machine.
3. Read a graph with the commands under [Read a graph](#read-a-graph).
4. Write an entry with `mdgraph new`, in the format under [An entry](#an-entry).

## An entry

A markdown file with two frontmatter fields:

```markdown
---
description: MGC Tokyo burst fade and continuation — five constructions, none survives a split
date: 2026-08-21
---

Five constructions, train/test split on the 2024-2026 cohort. Best cell reached
t=1.4 in-sample and 0.2 out. The burst itself is real. The direction is not.

- **Source:** src/notebooks/reports/topics/mgc_tokyo/mgc_tokyo.ipynb
- **Relates:** [[mgc-open-one-sided-commitment]]
```

| Part | Rule |
|---|---|
| Filename | The entry's identity and its link target. |
| Frontmatter | Makes a file an entry. A README at the graph root has none, so the index ignores it. No directory rule exists to break. |
| `Source:` | Where the evidence lives outside the graph: a notebook, a file in the repository, a URL. |
| `Relates: [[name]]` | Another entry inside the graph. |
| `[[name]]` | Written only when that entry exists, so a reader can follow any bracket without checking it first. |
| Anything else | A path or plain text. Grep finds it just as well. |

## The four rules of the design

**1. No hierarchy.** Files sit side by side and refer to each other by name.
- A tree gives every entry exactly one home, and a finding has none.
- Example: a range-breakout test on gold during Tokyo hours belongs under four topics at once. A tree makes you pick one and hides the entry from the other three.
- Links can point anywhere, and they are exact.

**2. No verdicts.** An entry carries numbers and mechanism. It never pronounces a conclusion.
- Nothing is marked closed.
- A decision is recorded only when you can name who or what made it: a stopping rule declared before the test ran, or the operator's call.
- A session that reads a result and decides the work should stop has not observed a decision. It has made one.

**3. A correction is a new entry.** It links the entry it corrects.
- The earlier entry stays as written. Knowing what was believed makes the correction make sense.
- The earlier entry's description gets the prefix `Corrected by [[new-name]] (YYYY-MM-DD): `, so the index shows the correction. `mdgraph correct` adds it.
- A typo, or a description shortened to under 200 characters with the same meaning, may be fixed in place.

**4. One file per entry.** Two sessions writing at the same time touch different files, so they never collide.

## Read a graph

Three commands. There are no embeddings, no similarity search and no query layer. Each command wraps one grep, shown beside it:

```bash
mdgraph -g <repo> grep <term>     # find a word         grep -rn "<term>" <graph>
mdgraph -g <repo> refs <name>     # what links here     grep -rl "\[\[<name>\]\]" <graph>
mdgraph -g <repo> index [topic]   # the whole index     grep -h "^description:" <graph>/*.md
```

- `-g` takes a repository path, a graph path or a repository name. Without it, the CLI uses the current directory's graph.
- `grep` searches entry bodies as well as descriptions.
- `refs` finds the entries that correct an entry, because a correction links what it corrects.
- Claude Code cuts a command's output past 30,000 characters without warning. `index` refuses to print an index that long, so filter it for a topic: `mdgraph index <topic>`.

A query tool would not earn its keep. Walking the links returns very little, because most links point at entries nobody has written yet. Whatever a walk would find is already in the index or one `refs` away.

## Write an entry

```bash
mdgraph -g <repo> new <name> "<description>" <<'EOF'
<body>
EOF
mdgraph -g <repo> correct <old> <new> "<what changed>"
mdgraph -g <repo> commit
```

- `new` dates the entry today. It refuses an existing name, a description over 200 characters or on several lines, and a `[[name]]` with no entry.
- `correct` adds the `Corrected by` prefix to the old description and the same line at the top of its body.
- `commit` commits only the graph's files.

## Check and repair

`mdgraph check` lists every broken entry and graph on the machine. `mdgraph check --fix` repairs what needs no judgement and lists the rest. [`SKILL.md`](skills/mdgraph/SKILL.md#checking-and-repairing) has the full table.

- Repaired: field names in the wrong case, descriptions split over several lines, missing or badly written dates, `[[name]]` links to no entry, missing `Corrected by` lines in a body, entries in subfolders, worktrees whose folders are gone, an `mdgraph` branch with no worktree, graphs with no registry line.
- Reported only: descriptions over 200 characters, missing or broken frontmatter, uncommitted changes, registry lines that point nowhere, a repository with two graphs.
- A full check of 800 entries takes about 4 seconds.

## Why not an extraction engine

An LLM memory engine reads your text, pulls out entities and relations, and stores what it extracted.

| Problem with extraction | What mdgraph does |
|---|---|
| Writing is expensive. On my own corpus, about 26 tokens went out for every token stored. | Your words never pass through a model. |
| Your text does not survive. "NFP killed at tick level, t=0.1–0.6, ZN-only" becomes triples that keep the nouns and drop the number, the threshold and the mechanism. | You decide where one entry ends and the next begins. |
| The engine merges what it stores, so the history is gone. You cannot rebuild the log from the graph. | git keeps the history. |

## Find the graphs on a machine

`mdgraph list` scans the disk for both kinds of graph:

1. Worktrees on the `mdgraph` branch.
2. Plain `.mdgraph/` directories.

Do not use the registry as the list.
- `~/.claude/mdgraph-registry.txt` records which projects have been asked whether they want a graph. It is not a list of graphs.
- A graph created without a registry line works fine, because the hooks find graphs through git and not through that file.
- Treating the registry as the list fails silently when it is incomplete. You conclude that a project has no memory while the hooks have indexed its entries all along.

## Install

Use one method per machine. A plugin install and `install.sh` together register every hook twice.

### Claude Code

```text
/plugin marketplace add A-Eugene/mdgraph
/plugin install mdgraph@mdgraph
```

- This loads the skill and the three hooks, and puts `mdgraph` on the Bash tool's `PATH`.
- Update with `/plugin marketplace update mdgraph`.

### Codex

```bash
codex plugin marketplace add A-Eugene/mdgraph
codex plugin add mdgraph@mdgraph
```

- Then open `/hooks` in Codex and trust the three mdgraph hooks. Codex skips a plugin's hooks until you trust them.
- Codex sends every file edit as one `apply_patch` call. The guard reads the file names out of the patch.

### Antigravity CLI (agy)

```bash
git clone https://github.com/A-Eugene/mdgraph
agy plugin install ./mdgraph
```

- agy converts the Claude Code plugin and installs the skill and the hooks.
- In a test with agy 1.4.9 on 2026-10-29, agy ran none of the hooks. The skill then tells the session to run `mdgraph list` and `mdgraph index` itself.

### Other agents

Any agent that reads Agent Skills (a folder holding a `SKILL.md`) can load `skills/mdgraph/`. Copy or link that folder into the agent's skills folder. The CLI comes with it, at `skills/mdgraph/bin/mdgraph`. The hooks need an agent that reads Claude Code's hook format.

### By script

`install.sh` installs into `~/.claude` without the plugin system:

```bash
./install.sh
```

It does five things:

1. Copies the skill to `~/.claude/skills/mdgraph/` and the CLI to `~/.claude/skills/mdgraph/bin/mdgraph`.
2. Deletes the hook scripts of earlier versions (`~/.claude/hooks/mdgraph-*.sh`).
3. Registers three hooks in `~/.claude/settings.json` and replaces any earlier mdgraph hooks. Your other hooks and settings stay. It backs the file up to `settings.json.bak-mdgraph` first.
4. Creates a plain home graph at `~/.mdgraph` for work that is not about one repository.
5. Adds the home graph's line to the registry.

- The CLI looks for repositories under `~/Projects`. Set `PROJECTS` when you run `install.sh` if yours are elsewhere, or set `MDGRAPH_PROJECTS` at run time.
- Set `HOST` to put the home graph somewhere other than `~/.mdgraph`.
- Files are copied, never symlinked. Run `install.sh` again after pulling.

### Requirements

| System | Needs |
|---|---|
| Linux | bash 4 or later, git, perl. All three come with most distributions. |
| Windows | Git for Windows. Claude Code already needs it, and its Git Bash brings bash, perl, GNU sed and coreutils. Run `install.sh` from Git Bash. The hooks run with `"shell": "bash"`, and the CLI converts `C:\` paths with `cygpath`. |
| macOS | bash 4 or later, GNU sed and GNU coreutils first on `PATH`: `brew install bash gnu-sed coreutils`. The system bash is 3.2, and BSD `sed -i` and `date -d` behave differently. |

The Linux build is tested. The Windows and macOS support has not been run on those systems yet.

### Layout

One repository serves every agent. Each agent reads its own manifest, and all of them share the skill folder and the hooks file.

| Path | Read by |
|---|---|
| `skills/mdgraph/SKILL.md` | Every agent: the rules a session follows |
| `skills/mdgraph/bin/mdgraph` | Every agent: the CLI |
| `hooks/hooks.json` | Claude Code, Codex and agy plugin installs |
| `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json` | Claude Code, and agy, which converts it |
| `.codex-plugin/plugin.json`, `.agents/plugins/marketplace.json` | Codex |
| `bin/mdgraph` | Claude Code, which puts `bin/` on the Bash tool's `PATH`. It runs the CLI in `skills/mdgraph/bin/` |
| `install.sh` | The script install |

## The hooks

A rule binds only a session that has loaded it. The hooks handle what cannot be left to chance. Each is a subcommand of the CLI. A plugin install registers them from `hooks/hooks.json`. `install.sh` writes them into `~/.claude/settings.json`.

| Hook | Runs on | What it does |
|---|---|---|
| `mdgraph hook index` | SessionStart | Prints the entry rules, then one line per graph on the machine. |
| `mdgraph hook guard` | PreToolUse | Makes a session read a graph's index before it changes that graph's repository. |
| `mdgraph hook nudge` | Stop | Warns when the code has had more commits than the graph has had entries. Under Codex, which needs JSON from this event, it prints the warning as a `systemMessage`. |

**`hook index`**
- Each graph's line shows its name, its entry count, how many of its descriptions run past 200 characters, whether its index is too long to print whole, and its path.
- The whole output is about 700 tokens.
- It prints the rules because a skill's body loads only when a session calls for it, and in practice sessions write entries without ever loading it.
- It prints no graph contents, because a graph is memory for one repository.
- It deletes guard marks older than seven days.

**`hook guard`**
- The first touch of the repository gets a notice.
- The first write is refused until the session has read the graph's index, with `mdgraph index` or a grep of its descriptions.
- Both happen once per repository per session.
- Writing to the graph itself is never held.

**`hook nudge`**
- For a repository with a graph, it counts the commits made since the last graph entry.
- For a repository with no graph and two or more commits in the last 14 days, it suggests starting one. A `declined` line in the registry silences this for good.

## Convert an existing graph

`scripts/convert-to-entries.py` splits a `WORKLOG.md` graph into one file per entry. It needs Python 3.

```bash
python3 scripts/convert-to-entries.py <graph>                        # 1. dry run
python3 scripts/convert-to-entries.py <graph> --apply                # 2. write entries, keep logs
python3 scripts/convert-to-entries.py <graph> --apply --remove-log   # 3. remove the logs
```

What the script guarantees:

- It refuses to run on a graph with uncommitted changes, since another session may be halfway through writing.
- Before touching anything, it writes a tarball to `~/backups/mdgraph-preconvert/` and records the commit it started from.
- It reports every `## ` heading it did not convert.
- It leaves the logs in place until you pass `--remove-log`.
- It recognises and skips entries it already wrote, so step 3 gets to the removal. Keep `--apply` on that run.
- A file that exists with different content makes it stop, so it can never overwrite a real name collision.

**Commit before renaming anything.** New entry files are untracked until the first commit, so `git mv` on one fails with "not under version control". The order:

1. Find links to the old name with `mdgraph refs <old-name>`.
2. Commit.
3. Rename.

The index hook reads both formats, so a graph keeps working throughout the conversion.

## License

MIT
