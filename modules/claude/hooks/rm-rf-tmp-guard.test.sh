#!/usr/bin/env bash
set -euo pipefail

hook="$(dirname "$0")/rm-rf-tmp-guard.py"
work=$(mktemp -d /tmp/rm-guard-test.XXXXXX)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/a/b"
ln -s "$HOME" "$work/escape"
ln -s "$work/a" "$work/inside"

wt="$work/home/.herdr/worktrees/repo/branch"
mkdir -p "$wt/build/out" "$wt/build/.github" "$work/home/.herdr/worktrees/repo/other" "$work/main/.git"
touch "$wt/.git" "$work/home/.herdr/worktrees/repo/other/.git"
ln -s "$work/main" "$wt/escape"
ln -s "$wt/build" "$wt/inside"

decision() {
  jq -nc --arg c "$1" --arg d "${cwd:-$work}" '{tool_name:"Bash",tool_input:{command:$c},cwd:$d}' |
    HOME="$work/home" python3 "$hook" | jq -rs '.[0].hookSpecificOutput.permissionDecision // "none"'
}

failures=0
expect() {
  local want=$1 cmd=$2 got
  got=$(decision "$cmd")
  if [ "$got" = "$want" ]; then
    printf 'ok   %-5s %q\n' "$got" "$cmd"
  else
    printf 'FAIL want %s, got %s: %q\n' "$want" "$got" "$cmd"
    failures=$((failures + 1))
  fi
}

expect allow "rm /tmp/x"
expect allow "rm -f /tmp/x"
expect allow "rm -r /tmp/x"
expect allow "rm -rf /tmp/x"
expect allow "rm -r -f /tmp/x"
expect allow "rm --recursive --force /tmp/x"
expect allow "rm -rf -- /tmp/x"
expect allow "rm -rf /private/tmp/claude-501/session/scratchpad/x"
expect allow "rm -f /tmp/x /private/tmp/y $work/a"
expect allow "rm -rf '$work/a/b' \"$work/with space\""
expect allow "rm -rf $work/a/"
expect allow "rm -rf $work/a/*"
expect allow "rm -f $work/a/*.log"
expect allow "rm -rf $work/inside/b"
expect allow "rm $work/escape"
expect allow "rm -rf $work/escape"

for root in /tmp /tmp/ /tmp// /tmp/. /private/tmp /private/tmp/ '/tmp/*' '/tmp/?*' '/private/tmp/*' /var/folders /private/var/folders; do
  expect none "rm $root"
  expect ask "rm -rf $root"
done
expect ask "rm -rf /tmp/../Users/x"
expect ask "rm -rf /tmp/a/../../etc"
expect ask "rm -rf $work/../.."
expect none "rm /tmp/a/../../etc/hosts"
expect ask "rm -rf /tmp/a ~/b"
expect none "rm /tmp/a /etc/hosts"
expect none "rm /etc/hosts /tmp/a"
expect ask "rm -rf /tmp/x /Users/x"
for lookalike in /tmpfoo /tmpfoo/x /private/tmpfoo/x ./tmp/x tmp/x ./x x '~/tmp/x'; do
  expect none "rm $lookalike"
  expect ask "rm -rf $lookalike"
done
expect ask "rm -rf foo"
expect ask "rm -rf ~/foo"
expect ask "rm -Rf /etc"
expect ask 'rm /tmp/a && rm -rf ~'
expect ask "rm -rf /tmp/a && rm -rf ~"
expect ask "rm -rf /tmp/a; ls"
expect none "rm /tmp/a; ls"
expect none "rm /tmp/a & ls"
expect none "rm /tmp/a | ls"
expect ask "cd / && rm -rf usr"
# shellcheck disable=SC2016
for substituted in '$(cat list)' '/tmp/$(cat list)' '`cat list`' '/tmp/`cat list`' '$HOME' '/tmp/$X' '"/tmp/$X"' '"/tmp/${X}/y"' '<(ls)' '/tmp/{a,../../etc}' '/tmp/[a]x' '/tmp/a\ b' '/tmp/a >/etc/hosts'; do
  expect none "rm $substituted"
  expect ask "rm -rf $substituted"
done
expect none $'rm /tmp/a\n/etc/hosts'
expect ask $'rm -rf /tmp/a\nrm -rf /etc'
expect ask $'rm -rf /tmp/a\r/etc'
expect none $'rm /tmp/a\n'
expect none "rm $work/escape/x"
expect ask "rm -rf $work/escape/x"
expect ask "rm -rf $work/escape/"
expect ask "rm -rf $work/escape/*"
expect ask "rm -rf $work/*/x"
expect ask "rm -rf $work/*/"
expect ask "rm -rf $work/a/**"
expect ask "rm -rf /tmp/***/x"
expect none "sudo rm /tmp/a"
expect ask "sudo rm -rf /tmp/a"
expect none "/bin/rm /tmp/a"
expect none "FOO=1 rm /tmp/a"
expect ask "rm -rf /tmp/a -- -b"
expect none "rm /tmp/a -rf"
expect ask "rm -rf --no-preserve-root /tmp/a"
for zsh_expansion in '~-' '~+' '~1' '=ls' '-- ~-'; do
  expect ask "rm -rf $zsh_expansion"
done
expect none "rm"
expect none "rm -f"
expect none "rm '/tmp/a"
expect none "ls -la"

if [ "$(uname)" = Darwin ]; then
  expect allow "rm -rf /var/folders/aa/bb/T/tmp.x"
  expect allow "rm -rf $(getconf DARWIN_USER_TEMP_DIR)x"
  expect ask "rm -rf /var/folders/aa/bb/T"
  expect ask "rm -rf /var/folders/aa/bb/T/*"
  expect ask "rm -rf /var/folders/aa/bb/C/x"
fi

cwd=$wt
expect allow "rm -rf build"
expect allow "rm -rf build/out result"
expect allow "rm -rf build/"
expect allow "rm -rf build/*"
expect allow "rm -rf inside/out"
expect allow "rm -rf build/.github"
expect allow "rm -rf build /tmp/x"
expect ask "rm -rf *"
expect ask "rm -rf ./build"
expect ask "rm -rf ../other/x"
expect ask "rm -rf escape/x"
expect ask "rm -rf escape/"
expect ask "rm -rf .git"
expect ask "rm -rf build/.git/x"
expect ask "rm -rf build ~/x"
expect ask "rm -rf build && rm -rf ~"
expect ask "cd .. && rm -rf other"
expect ask "rm -rf -build"
cwd="$wt/build"
expect allow "rm -rf out"
cwd="$work/home/.herdr/worktrees/repo"
expect ask "rm -rf branch"
expect ask "rm -rf branch/build"
cwd="$work/main"
expect ask "rm -rf build"
cwd="$work/home/.herdr/worktrees/repo/nogit"
mkdir -p "$cwd/x"
expect ask "rm -rf x"
unset cwd

[ "$failures" -eq 0 ] || {
  echo "$failures failure(s)"
  exit 1
}
echo "all passed"
