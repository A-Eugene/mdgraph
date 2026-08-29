# mdgraph

Cross-session memory for a repository, in plain markdown. An append-only
WORKLOG that routes to evidence, kept on a dedicated `mdgraph` branch (or in
`.mdgraph/` when the project is not a git repo). The conventions live in
[`SKILL.md`](SKILL.md) — that file is the contract, this one is why it looks
the way it does.

## Why not an extraction engine

LLM memory engines (cognee, mem0, and kin) read your text, extract entities and
relations, and store the extraction. Writes amplify (~26× tokens out per token
stored on my corpus), the payload that survives is not your text (the number
and the mechanism are what triples drop), and merged nodes destroy history.
mdgraph inverts all three: you draw the boundaries, the payload never passes
through a model, and history is git.

## The shape

- **WORKLOG.md** — an append-only ledger of what happened, newest last. Each
  entry ends with a `**Pointer:**` line naming where the evidence lives: a
  notebook, a repo file, a note, or "this entry" when the entry is all there
  is. The ledger is a router, not the archive.
- **No verdicts.** Entries carry numbers and mechanism so a reader can infer
  the conclusion; they never issue one. "Pursuit stopped on this result" is a
  fact and belongs. "DEAD — do not re-attempt" is an opinion and does not.
- **Corrections are new entries.** Nothing is rewritten; a later entry states
  what was wrong and the corrected number. Append-only is an operational rule,
  not a philosophy: several sessions share the file, appends interleave
  harmlessly, and an in-place rewrite silently drops concurrent writes.
- **`#constraint`** marks a standing precondition (a residency rule, a latency
  budget) that must never scroll out of context.
- **`Kills: [[idea-name]]`** on an entry records that a pursuit ended there,
  so the idea is not re-attempted cold.

## Enforcement (hooks)

The contract binds only when loaded, so the read side is mechanical. Three
scripts under `hooks/`; copy them out and register two:

```bash
mkdir -p ~/.claude/hooks && cp hooks/*.sh ~/.claude/hooks/
```

```json
"hooks": {
  "SessionStart": [{"hooks": [{"type": "command", "command": "$HOME/.claude/hooks/mdgraph-index.sh"}]}],
  "Stop":         [{"hooks": [{"type": "command", "command": "$HOME/.claude/hooks/mdgraph-nudge.sh"}]}]
}
```

- `mdgraph-index.sh` (SessionStart) — injects each vault's recent headings,
  every `#constraint` line in full regardless of age, and the `Kills:` list.
- `mdgraph-nudge.sh` (Stop) — warns when code commits have outpaced the vault.
- `mdgraph-vault.sh` — the resolver both call; not registered itself.

Both scan `/root/Projects/*/`; change that glob to wherever your repos live.

## Reading

No tooling and no query layer: `grep -rn <term> <vault>`. There used to be a
`graph.py` here; it was deleted once measurement showed its useful output was
a subset of what the SessionStart hook already injects, and its graph commands
walked a graph that was 90% dangling links.

## Install

```bash
mkdir -p ~/.claude/skills/mdgraph
cp SKILL.md ~/.claude/skills/mdgraph/
```

Then register the hooks as above, and add one line to your always-loaded agent
instructions telling sessions the vault convention exists — a skill body only
loads when invoked.
