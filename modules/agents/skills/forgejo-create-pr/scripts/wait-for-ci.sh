#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage: wait-for-ci.sh <remote> <commit> <timeout-seconds> <no-tasks-timeout-seconds>

Block until the newest Forgejo Actions task of every job for <commit> is in a
terminal state (success, failure, cancelled, skipped), then print those tasks.

Exit status:
  0  every job succeeded or was skipped
  1  at least one job failed or was cancelled
  2  bad arguments
  3  no task for <commit> appeared within <no-tasks-timeout-seconds>
  4  a job was still not terminal after <timeout-seconds>
EOF
  exit 2
}

[ $# -eq 4 ] || usage
remote="$1"
timeout_seconds="$3"
no_tasks_timeout_seconds="$4"
[[ $timeout_seconds =~ ^[0-9]+$ && $no_tasks_timeout_seconds =~ ^[0-9]+$ ]] || usage
sha="$(git rev-parse --verify "$2^{commit}")"
poll_interval_seconds=10

newest_task_per_job() {
  fj actions -R "$remote" tasks | awk -v sha="$sha" '
    NR > 1 {
      prefix = substr($2, 2, length($2) - 2)
      if (prefix == "" || index(sha, prefix) != 1) next
      for (end = 4; end <= NF && $end !~ /^\(.*\):$/; end++) {}
      last = end - 1
      if ($last ~ /^([0-9]+h)?([0-9]+m)?[0-9]+s$/) last--
      job = $4
      for (i = 5; i <= last; i++) job = job " " $i
      if (!(job in seen)) { seen[job] = 1; print $3 "\t" $0 }
    }'
}

verdict() {
  awk -F'\t' '
    $1 !~ /^(success|failure|cancelled|skipped)$/ { pending = 1 }
    $1 ~ /^(failure|cancelled)$/ { failed = 1 }
    END { print pending ? "pending" : failed ? "failed" : "passed" }'
}

start="$SECONDS"
while :; do
  tasks="$(newest_task_per_job)"
  elapsed=$((SECONDS - start))
  if [ -z "$tasks" ]; then
    if [ "$elapsed" -ge "$no_tasks_timeout_seconds" ]; then
      echo "error: no CI task for $sha on the newest page of 'fj actions -R $remote tasks' after ${elapsed}s" >&2
      exit 3
    fi
  else
    state="$(verdict <<<"$tasks")"
    case "$state" in
    passed | failed)
      cut -f2- <<<"$tasks"
      echo "CI $state for $sha after ${elapsed}s"
      [ "$state" = passed ]
      exit
      ;;
    esac
    if [ "$elapsed" -ge "$timeout_seconds" ]; then
      cut -f2- <<<"$tasks" >&2
      echo "error: CI for $sha still not finished after ${elapsed}s" >&2
      exit 4
    fi
  fi
  sleep "$poll_interval_seconds"
done
