#!/usr/bin/env bash
set -uo pipefail

script="$(cd "$(dirname "$0")" && pwd)/wait-for-ci.sh"
stub_dir="$(mktemp -d)"
trap 'rm -rf "$stub_dir"' EXIT
sha="$(git rev-parse HEAD)"
p="${sha:0:10}"
failures=0

fixture() {
  printf '%s\n' "$@" >"$stub_dir/tasks"
  printf '#!/bin/sh\necho "3 tasks"\ncat "%s"\n' "$stub_dir/tasks" >"$stub_dir/fj"
  chmod +x "$stub_dir/fj"
}

check() {
  local name="$1" expected="$2" expected_line="${3:-}"
  PATH="$stub_dir:$PATH" "$script" origin "$sha" "${4:-0}" 0 >"$stub_dir/out" 2>&1
  local actual=$?
  if [ "$actual" = "$expected" ] && grep -qF -- "$expected_line" "$stub_dir/out"; then
    echo "ok   $name"
  else
    echo "FAIL $name: expected exit $expected with line [$expected_line], got $actual"
    cat "$stub_dir/out"
    failures=$((failures + 1))
  fi
}

fixture "#3 ($p) success Syntax + Structure + Build 1m9s (push): t" \
  "#2 ($p) skipped References 3s (push): t" \
  "#1 (0000000000) failure Formatter 4s (push): other commit"
check "passes when every job succeeded or was skipped" 0

fixture "#3 ($p) success Syntax + Structure + Build 1m9s (push): t" \
  "#2 ($p) failure Formatter 4s (push): t"
check "fails when a job failed and prints the failed job" 1 "failure Formatter"

fixture "#2 ($p) cancelled Syntax + Structure + Build 39s (push): t"
check "fails when a job was cancelled" 1

fixture "#6 ($p) running Syntax + Structure + Build 57s (push): t" \
  "#3 ($p) success Syntax + Structure + Build 1m5s (push): t"
check "waits for the newest re-run, not an older finished run" 4

fixture "#9 ($p) success Syntax + Structure + Build 1m5s (push): t" \
  "#8 ($p) waiting Formatter (pull_request): t"
check "waits for a job without a duration" 4

fixture "#1 (0000000000) success Formatter 4s (push): other commit"
check "fails hard when the commit has no task" 3

fixture
check "rejects a non-numeric timeout" 2 "Usage:" soon

exit "$failures"
