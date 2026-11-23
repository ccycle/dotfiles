#!/usr/bin/env bash
set -euo pipefail

[ $# -eq 1 ] || {
  echo "usage: rebase-push.sh <worktree>" >&2
  exit 2
}
wt="$1"
g() { git -C "$wt" "$@"; }
fail() {
  echo "$*"
  exit 1
}

branch="$(g symbolic-ref --short HEAD)" || fail "detached HEAD in $wt"
[ -z "$(g status --porcelain)" ] || fail "uncommitted changes in $wt"
g fetch -q origin
[ "$(g rev-parse HEAD)" = "$(g rev-parse "origin/$branch")" ] || fail "local $branch differs from origin/$branch"
if ! g rebase -q origin/main >&2; then
  files="$(g diff --name-only --diff-filter=U | paste -sd, -)"
  g rebase --abort
  fail "conflict in $files"
fi
g push -q --force-with-lease origin "$branch" >&2 || fail "push of $branch was rejected"
g rev-parse HEAD
