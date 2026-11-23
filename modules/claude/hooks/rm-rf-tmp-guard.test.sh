#!/usr/bin/env bash
set -euo pipefail

hook="$(dirname "$0")/rm-rf-tmp-guard.py"
work=$(mktemp -d)
mkdir -p "$work/a/b" "$HOME/.rm-rf-guard-test-target"
trap 'rm -rf "$work"; rmdir "$HOME/.rm-rf-guard-test-target"' EXIT
ln -s "$HOME/.rm-rf-guard-test-target" "$work/escape"

decision() {
  jq -nc --arg c "$1" --arg d "${2:-$HOME}" '{tool_name:"Bash",tool_input:{command:$c},cwd:$d}' |
    python3 "$hook" | jq -rs '.[0].hookSpecificOutput.permissionDecision // "none"'
}

failures=0
expect() {
  local want=$1 cmd=$2 cwd=${3:-$HOME} got
  got=$(decision "$cmd" "$cwd")
  if [ "$got" != "$want" ]; then
    echo "FAIL: [$cmd] in $cwd: want $want, got $got"
    failures=$((failures + 1))
  fi
}

expect allow "rm -rf $work/a"
expect allow "rm -rf /tmp/some-new-dir"
expect allow "rm -r -f '$work/a/b' $work/a"
expect allow "rm -rf $work/a/*"
expect ask "rm -rf $work/*"
expect allow "rm -rf b" "$work/a"
expect ask "rm -rf /tmp"
expect ask "rm -rf /tmp/"
expect ask "rm -rf /private/var/folders"
expect ask "rm -rf $work/escape/"
expect ask "rm -rf $work/../.."
expect ask "rm -rf ~/foo"
expect ask "rm -rf foo"
expect ask "rm -rf /tmp/x /Users/x"
expect ask "rm -rf /tmp/x; rm -rf ~"
expect ask "rm -rf /tmp/x && rm -rf ~"
expect ask "rm -rf \$HOME"
expect ask "cd / && rm -rf usr"
expect ask "rm -Rf /etc"
expect none "rm /tmp/file"
expect none "ls -la"

[ "$failures" -eq 0 ] && echo "all passed"
exit "$failures"
