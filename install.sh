#!/usr/bin/env bash
# Installs mdgraph without a plugin system: the skill and its CLI, the hooks, and the home graph.
#   ./install.sh [claude] [codex] [agy]   (default: every one whose folder exists: ~/.claude, ~/.codex, ~/.gemini)
# Runs on Linux, macOS and Windows (Git Bash). Copies files, never symlinks.
#   PROJECTS  where repositories live, as <repo>/ or <repo>/<branch>/ (default $HOME/Projects)
#   HOST      a plain graph for work not about one repository (default $HOME/.mdgraph)
set -eu; cd "$(dirname "$0")"
HOST="${HOST:-$HOME/.mdgraph}"
GUARDED="Edit|Write|MultiEdit|NotebookEdit|Bash|Grep"

for need in git perl; do
  command -v $need >/dev/null || { echo "install.sh: $need is required" >&2; exit 1; }
done
[ "${BASH_VERSINFO[0]}" -ge 4 ] || { echo "install.sh: bash 4 or later is required (macOS: brew install bash)" >&2; exit 1; }

targets=("$@")
if [ ${#targets[@]} -eq 0 ]; then
  [ -d "$HOME/.claude" ] && targets+=(claude)
  [ -d "$HOME/.codex" ] && targets+=(codex)
  [ -d "$HOME/.gemini" ] && targets+=(agy)
  [ ${#targets[@]} -gt 0 ] || targets=(claude)
fi

install_skill() {
  # Copies the skill folder with its CLI to $1 and prints the CLI's path.
  mkdir -p "$1/bin"
  cp skills/mdgraph/SKILL.md "$1/SKILL.md"
  if [ -n "${PROJECTS:-}" ]; then sed "s|:-\$HOME/Projects}|:-$PROJECTS}|" skills/mdgraph/bin/mdgraph > "$1/bin/mdgraph"
  else cp skills/mdgraph/bin/mdgraph "$1/bin/mdgraph"; fi
  chmod +x "$1/bin/mdgraph"
  echo "$1/bin/mdgraph"
}

register_hooks() {
  # register_hooks <hooks file> <cli> <PreToolUse matcher> [shell]: replaces earlier mdgraph
  # hooks and leaves every other hook alone. Backs the file up first.
  [ -f "$1" ] && cp "$1" "$1.bak-mdgraph"
  perl -MJSON::PP -e '
    my ($path, $bin, $matcher, $shell) = @ARGV;
    my $json = JSON::PP->new->utf8->pretty->canonical->indent_length(2);
    my $d = {};
    if (-e $path) { local $/; open my $f, "<", $path or die "$path: $!"; $d = $json->decode(<$f>) }
    my $h = $d->{hooks} //= {};
    for my $event (keys %$h) {
      for my $e (@{$h->{$event}}) {
        $e->{hooks} = [grep { ($_->{command} // "") !~ m{mdgraph-(guard|index|nudge)\.sh|/mdgraph"? hook } } @{$e->{hooks} || []}];
      }
      $h->{$event} = [grep { @{$_->{hooks}} } @{$h->{$event}}];
    }
    my $hook = sub { {type => "command", command => "\"$bin\" hook $_[0]", ($shell ? (shell => $shell) : ())} };
    push @{$h->{SessionStart}}, {hooks => [$hook->("index")]};
    push @{$h->{Stop}}, {hooks => [$hook->("nudge")]};
    push @{$h->{PreToolUse}}, {matcher => $matcher, hooks => [$hook->("guard")]};
    open my $f, ">", $path or die "$path: $!"; print $f $json->encode($d);
  ' "$@"
}

for t in "${targets[@]}"; do
  case $t in
    claude)
      bin=$(install_skill "$HOME/.claude/skills/mdgraph")
      rm -f "$HOME"/.claude/hooks/mdgraph-{guard,index,nudge,resolve}.sh
      register_hooks "$HOME/.claude/settings.json" "$bin" "$GUARDED" bash
      echo "claude: skill and CLI in $HOME/.claude/skills/mdgraph, 3 hooks in $HOME/.claude/settings.json" ;;
    codex)
      bin=$(install_skill "$HOME/.codex/skills/mdgraph")
      register_hooks "$HOME/.codex/hooks.json" "$bin" "$GUARDED|apply_patch"
      echo "codex: skill and CLI in $HOME/.codex/skills/mdgraph, 3 hooks in $HOME/.codex/hooks.json. Trust them in Codex with /hooks" ;;
    agy)
      install_skill "$HOME/.gemini/skills/mdgraph" >/dev/null
      echo "agy: skill and CLI in $HOME/.gemini/skills/mdgraph (agy runs no hooks)" ;;
    *) echo "install.sh: unknown target $t. Use claude, codex or agy" >&2; exit 1 ;;
  esac
done

# The home graph: plain mode, since $HOME is not a repository.
mkdir -p "$HOST" "$HOME/.claude"
REG="$HOME/.claude/mdgraph-registry.txt"
grep -qs "^$(dirname "$HOST")	" "$REG" || printf '%s\tplain\t%s\t%s\n' "$(dirname "$HOST")" "$HOST" "$(date +%F)" >> "$REG"
echo "home graph: $HOST"
