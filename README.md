# mdgraph

Memory for a repository, kept as plain markdown files that a coding agent reads and writes.

- One file per thing worth remembering: a result and its numbers, a dead end, an open question, a constraint found the hard way.
- Files link to each other by name, as `[[name]]`.
- The files live on their own `mdgraph` branch, checked out beside the repository. Outside git, they live in a plain `.mdgraph/` folder.
- No model sits between a finding and its file, so nothing is lost in extraction and a write costs nothing extra.

[`skills/mdgraph/SKILL.md`](skills/mdgraph/SKILL.md) holds the full rules a session follows.

## How it works

**An entry** is a markdown file with two frontmatter fields. The filename is its name and its link target.

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

- `description` is one sentence under 200 characters. The descriptions together are the index a session reads.
- An entry records numbers and mechanism, never a verdict. A correction is a new entry, and the earlier one gets a `Corrected by [[new-name]]` marker.

**The `mdgraph` CLI** does every operation. `-g` picks a graph by repository path, graph path or name. Without it, the CLI uses the current directory's graph.

| Command | What it does |
|---|---|
| `mdgraph index [topic]` | Prints entry names and descriptions, filtered by a topic |
| `mdgraph grep <term>` | Searches entry bodies |
| `mdgraph refs <name>` | Lists the entries that link to `[[name]]` |
| `mdgraph new <name> "<description>"` | Writes an entry dated today, with the body from stdin |
| `mdgraph correct <old> <new> "<why>"` | Marks `<old>` as corrected by `<new>` |
| `mdgraph commit` | Commits the graph's files |
| `mdgraph list` | Lists every graph on the machine |
| `mdgraph check [--fix]` | Finds broken entries and graphs, and with `--fix` repairs what needs no judgement |

**Three hooks** make sessions follow the rules without loading the skill:

| Hook | Runs on | What it does |
|---|---|---|
| `mdgraph hook index` | session start | Prints the rules and one line per graph on the machine |
| `mdgraph hook guard` | before a tool call | Refuses the first write to a repository until the session has read its graph's index, once per session |
| `mdgraph hook nudge` | end of a turn | Warns when the code has had commits since the last graph entry |

`scripts/convert-to-entries.py` (Python 3) splits an older `WORKLOG.md` graph into one file per entry. It runs as a dry run first, and `--apply` writes the entries.

## Install

Install it once per tool, with the tool's plugin system or with `install.sh`. Don't use both in one tool, or every hook runs twice.

| Tool | Plugin | Script | Hooks run |
|---|---|---|---|
| Claude Code | `/plugin install mdgraph@mdgraph` | `./install.sh claude` | yes |
| Codex | `codex plugin add mdgraph@mdgraph` | `./install.sh codex` | yes, after you trust them in `/hooks` |
| Antigravity (agy) | `agy plugin install ./mdgraph` | `./install.sh agy` | no |

### Claude Code

```text
/plugin marketplace add A-Eugene/mdgraph
/plugin install mdgraph@mdgraph
```

This puts `mdgraph` on the Bash tool's `PATH`. Update with `/plugin marketplace update mdgraph`.

### Codex

```bash
codex plugin marketplace add A-Eugene/mdgraph
codex plugin add mdgraph@mdgraph
```

Then open `/hooks` in Codex and trust the three mdgraph hooks. Codex skips a plugin's hooks until you trust them.

### Antigravity

```bash
git clone https://github.com/A-Eugene/mdgraph
agy plugin install ./mdgraph
```

agy converts the Claude Code plugin. In a test with agy 1.4.9 on 2026-10-29, agy ran none of the hooks, so the skill tells the session to run `mdgraph list` and `mdgraph index` itself.

### By script

```bash
git clone https://github.com/A-Eugene/mdgraph
cd mdgraph
./install.sh                  # every tool whose folder exists: ~/.claude, ~/.codex, ~/.gemini
./install.sh claude codex     # only the tools you name
```

| Tool | Skill and CLI | Hooks |
|---|---|---|
| `claude` | `~/.claude/skills/mdgraph/` | `~/.claude/settings.json` |
| `codex` | `~/.codex/skills/mdgraph/` | `~/.codex/hooks.json`. Trust them with `/hooks` |
| `agy` | `~/.gemini/skills/mdgraph/` | none |

- Each hooks file keeps its other hooks, and gets a backup at `<file>.bak-mdgraph` first.
- Every run also creates a home graph at `~/.mdgraph` for work that is not about one repository.
- The CLI looks for repositories under `~/Projects`. Set `PROJECTS` when you run `install.sh`, or `MDGRAPH_PROJECTS` at run time, if yours are elsewhere.
- Run it again after pulling, since it copies files.

### Requirements

| System | Needs |
|---|---|
| Linux | bash 4 or later, git and perl |
| Windows | Git for Windows, whose Git Bash brings bash, perl, GNU sed and coreutils. Run `install.sh` from Git Bash. |
| macOS | `brew install bash gnu-sed coreutils`, with GNU sed and coreutils first on `PATH` |

Linux is tested. Windows and macOS have not been run yet.

## License

MIT
