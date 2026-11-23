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
check "pending right after a push, before any status exists" \
  "$(classify)" pending
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

exit "$failures"
