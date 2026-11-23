#!/usr/bin/env bash
set -uo pipefail

[ $# -gt 0 ] || {
  echo "usage: triage.sh <pr-number>... (in merge order)" >&2
  exit 2
}
here="$(cd "$(dirname "$0")" && pwd)"
log="$(mktemp -t triage-prs.XXXXXX)" || exit 2
echo "log: $log"

for n in "$@"; do
  row="$("$here/prs.sh" 2>>"$log" | awk -F'\t' -v n="$n" '$1 == n')"
  [ -n "$row" ] || {
    echo "#$n not open"
    continue
  }
  IFS=$'\t' read -r _ branch head on_main _ pane status <<<"$row"
  case "$status" in
  working | blocked)
    echo "#$n skip: agent $pane is $status"
    continue
    ;;
  esac
  sha="$(git -C "$here" rev-parse "$head")"
  if [ "$on_main" = no ]; then
    wt="$(git -C "$here" worktree list --porcelain | awk -v b="branch refs/heads/$branch" '/^worktree /{w = substr($0, 10)} $0 == b {print w}')"
    [ -n "$wt" ] || {
      echo "#$n skip: no local worktree for $branch"
      continue
    }
    sha="$("$here/rebase-push.sh" "$wt" 2>>"$log")" || {
      echo "#$n rebase failed, delegate to $pane: $sha"
      continue
    }
  fi
  "$here/ci-state.sh" "$sha" --wait 1800 >/dev/null 2>>"$log"
  case $? in
  0) ;;
  1)
    echo "#$n CI failed on $sha, delegate to $pane"
    continue
    ;;
  3)
    echo "#$n CI still pending on $sha after 30 min"
    continue
    ;;
  *)
    echo "#$n ci-state.sh errored on $sha; see the log"
    continue
    ;;
  esac
  if "$here/merge.sh" "$n" >>"$log" 2>&1; then
    echo "#$n merged $sha"
  else
    echo "#$n $(tail -1 "$log")"
  fi
done
