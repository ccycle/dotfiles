#!/usr/bin/env bash
set -euo pipefail

[ $# -eq 4 ] || {
  cat >&2 <<'EOF'
usage: rebase-push.sh <worktree> <remote> <base-branch> <verify-command>

Rebase the worktree's branch onto <remote>/<base-branch>, keeping both sides
of a conflict where both only appended to the end of a file, run
<verify-command> in the worktree, and push with --force-with-lease.
Prints the new head on success, otherwise one line saying why.

Exit status:
  0  pushed (or already on top of the base)
  1  not pushed: conflict, verification failed, or the branch is not pushable
  2  bad arguments
  3  rebase stopped without a conflict, e.g. commit signing failed
EOF
  exit 2
}
wt="$1" remote="$2" base="$3" verify="$4"
g() { git -C "$wt" "$@"; }
fail() {
  echo "$*"
  exit 1
}
blocked() {
  echo "$*"
  exit 3
}
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

branch="$(g symbolic-ref --short HEAD)" || fail "detached HEAD in $wt"
[ -z "$(g status --porcelain)" ] || fail "uncommitted changes in $wt"
g fetch -q "$remote"
[ "$(g rev-parse HEAD)" = "$(g rev-parse "$remote/$branch")" ] || fail "local $branch differs from $remote/$branch"

keep_both_appends() {
  local f s n
  while IFS= read -r f; do
    for s in 1 2 3; do
      g show ":$s:$f" >"$tmp/$s" 2>/dev/null || return 1
    done
    n=$(($(wc -c <"$tmp/1")))
    head -c "$n" "$tmp/2" | cmp -s - "$tmp/1" || return 1
    head -c "$n" "$tmp/3" | cmp -s - "$tmp/1" || return 1
    { cat "$tmp/2" && tail -c +$((n + 1)) "$tmp/3"; } >"$wt/$f"
    g add -- "$f"
  done < <(g diff --name-only --diff-filter=U)
}

if ! GIT_EDITOR=true g rebase "$remote/$base" >"$tmp/log" 2>&1; then
  while :; do
    conflicted="$(g diff --name-only --diff-filter=U | paste -sd, -)"
    if [ -z "$conflicted" ]; then
      g rebase --abort
      blocked "rebase stopped without a conflict: $(grep -m1 -o 'error: .*' "$tmp/log" || tail -1 "$tmp/log")"
    fi
    keep_both_appends || {
      g rebase --abort
      fail "conflict in $conflicted"
    }
    GIT_EDITOR=true g rebase --continue >"$tmp/log" 2>&1 && break
  done
fi

(cd "$wt" && bash -c "$verify") >&2 || fail "verification failed after rebase; $branch is rebased locally but not pushed"
g push -q --force-with-lease "$remote" "$branch" >&2 || fail "push of $branch was rejected"
g rev-parse HEAD
