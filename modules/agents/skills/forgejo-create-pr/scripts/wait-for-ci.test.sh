#!/usr/bin/env bash
set -uo pipefail

script="$(cd "$(dirname "$0")" && pwd)/wait-for-ci.sh"
stub_dir="$(mktemp -d)"
trap 'rm -rf "$stub_dir"' EXIT
sha="$(git rev-parse HEAD)"
failures=0

fixture() {
  local runs="" id=1 status workflow
  for run in "$@"; do
    status="${run%% *}" workflow="${run#* }"
    runs="$runs${runs:+,}{\"id\":$id,\"status\":\"$status\",\"workflow_id\":\"$workflow\",\"html_url\":\"https://f/runs/$id\"}"
    id=$((id + 1))
  done
  printf '{"workflow_runs":[%s]}\n' "$runs" >"$stub_dir/runs.json"
  printf '#!/bin/sh\ncat "%s"\n' "$stub_dir/runs.json" >"$stub_dir/curl"
  chmod +x "$stub_dir/curl"
}

check() {
  local name="$1" expected="$2" expected_line="$3" timeout="$4"
  PATH="$stub_dir:$PATH" "$script" origin "$sha" "$timeout" 0 >"$stub_dir/out" 2>&1
  local actual=$?
  if [ "$actual" = "$expected" ] && grep -qF -- "$expected_line" "$stub_dir/out"; then
    echo "ok   $name"
  else
    echo "FAIL $name: expected exit $expected with line [$expected_line], got $actual"
    cat "$stub_dir/out"
    failures=$((failures + 1))
  fi
}

fixture "success verify.yaml" "skipped lint.yaml" "success md-links.yaml"
check "passes when every run succeeded or was skipped" 0 "CI passed" 0

fixture "success verify.yaml" "failure lint.yaml"
check "fails when a run failed and prints the failed run" 1 "failure	lint.yaml" 0

fixture "cancelled verify.yaml"
check "fails when a run was cancelled" 1 "CI failed" 0

fixture "success verify.yaml" "running verify.yaml"
check "judges the newest run of a workflow, not an older finished one" 4 "still not finished" 0

fixture "success md-links.yaml" "waiting verify.yaml"
check "waits for a run that has no task yet" 4 "waiting	verify.yaml" 0

fixture
check "fails hard when the commit has no run" 3 "no CI run" 0

check "rejects a non-numeric timeout" 2 "Usage:" soon

exit "$failures"
