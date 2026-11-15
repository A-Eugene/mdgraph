#!/usr/bin/env bash
# SessionStart hook: when the source repo's main has moved past the installed commit, reinstalls from it
# in the background with the command that installed it. The new version loads in the next session.
# A dirty or unpushed local install is never an ancestor of main, so it is left alone.
export GIT_TERMINAL_PROMPT=0
main() {
  local dir; dir=$(cd "$(dirname "$0")" && pwd)
  local source installed; source=$(cat "$dir/.source" 2>/dev/null) || return
  installed=$(cat "$dir/.commit" 2>/dev/null)
  (
    latest=$(git ls-remote "$source" HEAD 2>/dev/null | cut -f1)
    [ -n "$latest" ] && [ "$latest" != "$installed" ] || exit
    # ponytail: mkdir lock, since flock is missing on macOS; a lock older than 10 minutes is stale
    find "$dir/.updating" -maxdepth 0 -mmin +10 -exec rmdir {} \; 2>/dev/null
    mkdir "$dir/.updating" 2>/dev/null || exit
    tmp=$(mktemp -d); trap 'rm -rf "$tmp"; rmdir "$dir/.updating"' EXIT
    git clone -q --filter=blob:none "$source" "$tmp/repo" && cd "$tmp/repo" || exit
    [ -z "$installed" ] || git merge-base --is-ancestor "$installed" HEAD || exit
    eval "$(cat "$dir/.install" 2>/dev/null || echo ./install.sh)"
  ) </dev/null >/dev/null 2>&1 &
}
main "$@"; exit 0
