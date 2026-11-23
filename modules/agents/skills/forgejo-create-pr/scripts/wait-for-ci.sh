#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage: wait-for-ci.sh <remote> <commit> <timeout-seconds> <no-runs-timeout-seconds>

Block until the newest Forgejo Actions run of every workflow triggered by
<commit> is in a terminal state (success, failure, cancelled, skipped), then
print those runs. <remote> must have an https URL.

Exit status:
  0  every run succeeded or was skipped
  1  at least one run failed or was cancelled
  2  bad arguments
  3  no run for <commit> appeared within <no-runs-timeout-seconds>
  4  a run was still not terminal after <timeout-seconds>
EOF
  exit 2
}

[ $# -eq 4 ] || usage
timeout_seconds="$3"
no_runs_timeout_seconds="$4"
[[ $timeout_seconds =~ ^[0-9]+$ && $no_runs_timeout_seconds =~ ^[0-9]+$ ]] || usage
remote_url="$(git remote get-url "$1")"
[[ $remote_url =~ ^(https://[^/]+)/([^/]+)/([^/]+)$ ]] || {
  echo "error: remote $1 URL is not https://<host>/<owner>/<repo>: $remote_url" >&2
  exit 2
}
runs_url="${BASH_REMATCH[1]}/api/v1/repos/${BASH_REMATCH[2]}/${BASH_REMATCH[3]%.git}/actions/runs"
sha="$(git rev-parse --verify "$2^{commit}")"
poll_interval_seconds=10

newest_run_per_workflow() {
  curl -fsS "$runs_url?head_sha=$sha&limit=50" | jq -r '
    .workflow_runs | group_by(.workflow_id) | map(max_by(.id)) | sort_by(.workflow_id)[]
    | "\(.status)\t\(.workflow_id)\t\(.html_url)"'
}

verdict() {
  awk -F'\t' '
    $1 !~ /^(success|failure|cancelled|skipped)$/ { pending = 1 }
    $1 ~ /^(failure|cancelled)$/ { failed = 1 }
    END { print pending ? "pending" : failed ? "failed" : "passed" }'
}

start="$SECONDS"
while :; do
  runs="$(newest_run_per_workflow)"
  elapsed=$((SECONDS - start))
  if [ -z "$runs" ]; then
    if [ "$elapsed" -ge "$no_runs_timeout_seconds" ]; then
      echo "error: no CI run for $sha at $runs_url after ${elapsed}s" >&2
      exit 3
    fi
  else
    state="$(verdict <<<"$runs")"
    case "$state" in
    passed | failed)
      echo "$runs"
      echo "CI $state for $sha after ${elapsed}s"
      [ "$state" = passed ]
      exit
      ;;
    esac
    if [ "$elapsed" -ge "$timeout_seconds" ]; then
      echo "$runs" >&2
      echo "error: CI for $sha still not finished after ${elapsed}s" >&2
      exit 4
    fi
  fi
  sleep "$poll_interval_seconds"
done
