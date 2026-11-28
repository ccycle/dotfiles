#!/usr/bin/env bash
set -uo pipefail

[ $# -eq 3 ] || {
  cat >&2 <<'EOF'
usage: mergeable.sh <remote> <pr-number> <verify-command>

Run from the PR's worktree. Decide whether the Forgejo PR can be merged by
fast-forward and print one verdict line. A PR behind its base is rebased
(rebase-push.sh, with <verify-command> before the push) and CI is awaited on
the new head, up to max_rebases times. Never merges.

Exit status:
  0  mergeable (fast-forward)
  1  not mergeable: merged/closed, CI failed, conflict, or verification failed
  2  inconclusive: bad arguments, PR or API unreadable, wrong branch
  3  blocked on the user: signing failed (rbw locked?), CI not running
EOF
  exit 2
}
remote="$1" n="$2" verify="$3" pushed=""
here="$(cd "$(dirname "$0")" && pwd)"
api="$("$here/api-url.sh" "$remote")" || exit 2
max_rebases=3
ci_timeout_seconds=480
no_runs_timeout_seconds=60

verdict() {
  echo "$2"
  exit "$1"
}

for ((rebases = 0; ; rebases++)); do
  pr="$(curl -fsS "$api/pulls/$n")" || verdict 2 "inconclusive: cannot read PR #$n from $api"
  IFS=$'\t' read -r state merged sha branch base < <(jq -r '[.state, .merged, .head.sha, .head.ref, .base.ref] | @tsv' <<<"$pr")
  [ -n "${base:-}" ] || verdict 2 "inconclusive: PR #$n response lacks state/head/base: $pr"
  [ "$merged" = false ] || verdict 1 "not mergeable: PR #$n is already merged"
  [ "$state" = open ] || verdict 1 "not mergeable: PR #$n is $state"
  git fetch -q "$remote" || verdict 2 "inconclusive: git fetch $remote failed"
  sha="${pushed:-$sha}"

  if git merge-base --is-ancestor "$remote/$base" "$sha"; then
    "$here/wait-for-ci.sh" "$remote" "$sha" "$ci_timeout_seconds" "$no_runs_timeout_seconds" >&2
    case $? in
    0) verdict 0 "mergeable (fast-forward): PR #$n head $sha is on top of $remote/$base and CI is green" ;;
    1) verdict 1 "not mergeable: CI failed on $sha" ;;
    3) verdict 3 "blocked: no CI run appeared for $sha (CI not triggered?)" ;;
    4) verdict 3 "blocked: CI not running on $sha after ${ci_timeout_seconds}s (runner stuck?)" ;;
    *) verdict 2 "inconclusive: wait-for-ci.sh failed on $sha" ;;
    esac
  fi

  [ "$rebases" -lt "$max_rebases" ] || verdict 1 "not mergeable: still behind $remote/$base after $max_rebases rebases"
  [ "$(git symbolic-ref --short HEAD 2>/dev/null)" = "$branch" ] || verdict 2 "inconclusive: run from the worktree of PR #$n's branch $branch"
  out="$("$here/rebase-push.sh" . "$remote" "$base" "$verify")"
  case $? in
  0) pushed="$out" ;;
  3) verdict 3 "blocked: $out" ;;
  *) verdict 1 "not mergeable: $out" ;;
  esac
done
