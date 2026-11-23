#!/usr/bin/env bash
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
expected='["Markdown links / References (push)","Verify / Syntax + Structure + Build (push)"]'
failures=0

check() {
  if [ "$2" = "$3" ]; then
    echo "ok   $1"
  else
    echo "FAIL $1: expected [$3], got [$2]"
    failures=$((failures + 1))
  fi
}

classify() {
  local statuses="" s
  for s in "$@"; do
    statuses="$statuses${statuses:+,}{\"status\":\"${s%%=*}\",\"context\":\"${s#*=}\"}"
  done
  jq -r --argjson expected "$expected" -f "$here/ci-state.jq" <<<"{\"statuses\":[$statuses]}"
}

check "green when every expected context passed and path-filtered Lint did not run" \
  "$(classify "success=Markdown links / References (push)" "success=Verify / Syntax + Structure + Build (push)")" success
check "red as soon as one context fails while Build is still pending" \
  "$(classify "failure=Lint / Formatter (push)" "success=Markdown links / References (push)" "pending=Verify / Syntax + Structure + Build (push)")" failure
check "pending while an expected context has not been reported" \
  "$(classify "success=Markdown links / References (push)")" pending
check "pending right after a push, when Forgejo reports statuses as null" \
  "$(jq -r --argjson expected "$expected" -f "$here/ci-state.jq" <<<'{"statuses":null}' 2>&1)" pending
check "pending while a path-filtered workflow that did run is unfinished" \
  "$(classify "pending=Lint / Formatter (push)" "success=Markdown links / References (push)" "success=Verify / Syntax + Structure + Build (push)")" pending

"$here/ci-state.sh" >/dev/null 2>&1
check "ci-state.sh rejects a missing sha" "$?" 2
"$here/ci-state.sh" HEAD --wait soon >/dev/null 2>&1
check "ci-state.sh rejects a non-numeric timeout" "$?" 2
"$here/merge.sh" >/dev/null 2>&1
check "merge.sh rejects a missing PR number" "$?" 1
check "merge.sh refuses an already merged PR before reading the token" \
  "$("$here/merge.sh" 104 2>&1)" "refusing to merge #104: already merged"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
git init -q --bare -b main "$tmp/remote.git"
git clone -q "$tmp/remote.git" "$tmp/main" 2>/dev/null
git -C "$tmp/main" config user.name test
git -C "$tmp/main" config user.email test@invalid
git -C "$tmp/main" config commit.gpgsign false
commit() { # commit <repo> <file> <content>
  echo "$3" >"$1/$2" && git -C "$1" add "$2" && git -C "$1" commit -qm "$2"
}
commit "$tmp/main" shared base
git -C "$tmp/main" push -q origin main
for b in clean conflicting; do
  git -C "$tmp/main" worktree add -q -b "$b" "$tmp/$b" main
done
commit "$tmp/clean" own clean
commit "$tmp/conflicting" shared conflicting
git -C "$tmp/main" push -q origin clean conflicting
commit "$tmp/main" shared moved
git -C "$tmp/main" push -q origin main

"$here/rebase-push.sh" "$tmp/clean" >/dev/null 2>&1
check "rebase-push.sh rebases a clean branch" "$?" 0
git -C "$tmp/main" fetch -q origin
git -C "$tmp/main" merge-base --is-ancestor origin/main origin/clean
check "rebase-push.sh pushed the branch on top of main" "$?" 0
before="$(git -C "$tmp/conflicting" rev-parse HEAD)"
check "rebase-push.sh names the conflicting file" "$("$here/rebase-push.sh" "$tmp/conflicting" 2>/dev/null)" "conflict in shared"
check "rebase-push.sh leaves a conflicting branch as it was" "$(git -C "$tmp/conflicting" rev-parse HEAD):$(git -C "$tmp/conflicting" status --porcelain)" "$before:"
echo dirty >"$tmp/clean/own"
check "rebase-push.sh refuses uncommitted changes" "$("$here/rebase-push.sh" "$tmp/clean" 2>/dev/null)" "uncommitted changes in $tmp/clean"

exit "$failures"
