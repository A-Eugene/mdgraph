#!/usr/bin/env bash
# Installs mdgraph for Claude Code: the skill, the CLI, three hooks and the home graph.
# Runs on Linux, macOS and Windows (Git Bash). Copies files, never symlinks.
#   PROJECTS  where repositories live, as <repo>/ or <repo>/<branch>/ (default $HOME/Projects)
#   HOST      a plain graph for work not about one repository (default $HOME/.mdgraph)
set -eu; cd "$(dirname "$0")"
HOST="${HOST:-$HOME/.mdgraph}"
SKILL="$HOME/.claude/skills/mdgraph"
BIN="$SKILL/bin/mdgraph"
SETTINGS="$HOME/.claude/settings.json"

for need in git perl; do
  command -v $need >/dev/null || { echo "install.sh: $need is required" >&2; exit 1; }
done
[ "${BASH_VERSINFO[0]}" -ge 4 ] || { echo "install.sh: bash 4 or later is required (macOS: brew install bash)" >&2; exit 1; }

mkdir -p "$SKILL/bin"
cp skills/mdgraph/SKILL.md "$SKILL/SKILL.md"
if [ -n "${PROJECTS:-}" ]; then sed "s|:-\$HOME/Projects}|:-$PROJECTS}|" skills/mdgraph/bin/mdgraph > "$BIN"; else cp skills/mdgraph/bin/mdgraph "$BIN"; fi
chmod +x "$BIN"
rm -f "$HOME"/.claude/hooks/mdgraph-{guard,index,nudge,resolve}.sh

# Register the three hooks, replacing any earlier mdgraph hooks and leaving every other hook alone.
[ -f "$SETTINGS" ] && cp "$SETTINGS" "$SETTINGS.bak-mdgraph"
perl -MJSON::PP -e '
  my ($path, $bin) = @ARGV;
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
  my $hook = sub { {type => "command", shell => "bash", command => "\"$bin\" hook $_[0]"} };
  push @{$h->{SessionStart}}, {hooks => [$hook->("index")]};
  push @{$h->{Stop}}, {hooks => [$hook->("nudge")]};
  push @{$h->{PreToolUse}}, {matcher => "Edit|Write|MultiEdit|NotebookEdit|Bash|Grep", hooks => [$hook->("guard")]};
  open my $f, ">", $path or die "$path: $!"; print $f $json->encode($d);
' "$SETTINGS" "$BIN"

# The home graph: plain mode, since $HOME is not a repository.
mkdir -p "$HOST"
REG="$HOME/.claude/mdgraph-registry.txt"
grep -qs "^$(dirname "$HOST")	" "$REG" || printf '%s\tplain\t%s\t%s\n' "$(dirname "$HOST")" "$HOST" "$(date +%F)" >> "$REG"
echo "installed: skill and CLI in $SKILL, 3 hooks in $SETTINGS (backup at $SETTINGS.bak-mdgraph), home graph $HOST"
