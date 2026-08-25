#!/usr/bin/env sh
# Detect stale herdr worktrees that can be safely cleaned up.
# Heuristics: no agent running, no changes from main, age threshold.

set -eu

show_usage() {
  cat <<'EOF'
Usage: detect-stale-worktrees.sh [OPTIONS]

Detect stale herdr worktrees (abandoned, never merged, no activity).

Options:
  --list              Show candidates only (default)
  --auto-clean        Remove safe candidates (no diff from main + no agent)
  --force-confirm     Prompt for each candidate before removal
  --days DAYS         Age threshold in days (default: 30)
  -h, --help          Show this help
EOF
}

mode="list"
threshold_days=30

while [ "$#" -gt 0 ]; do
  case "$1" in
  --list) mode="list" ;;
  --auto-clean) mode="auto-clean" ;;
  --force-confirm) mode="force-confirm" ;;
  --days)
    shift
    if [ -z "${1:-}" ] || [ "$1" -le 0 ] 2>/dev/null; then
      printf 'Usage: --days DAYS (positive integer, e.g. --days 30)\n' >&2
      exit 1
    fi
    threshold_days="$1"
    ;;
  --days=*)
    threshold_days="${1#*=}"
    if [ "$threshold_days" -le 0 ] 2>/dev/null; then
      printf 'Usage: --days DAYS (positive integer, e.g. --days 30)\n' >&2
      exit 1
    fi
    ;;
  -h | --help)
    show_usage
    exit 0
    ;;
  *)
    printf 'Unknown option: %s\n' "$1" >&2
    show_usage
    exit 1
    ;;
  esac
  shift
done

command -v herdr >/dev/null 2>&1 || {
  printf 'herdr not found\n' >&2
  exit 1
}
command -v jq >/dev/null 2>&1 || {
  printf 'jq not found\n' >&2
  exit 1
}

# Return 0 if the branch has ever been worked on (reflog contains
# commit/rebase/merge/reset entries), 1 if never started (only the
# initial creation entry) or if no reflog is available.
# NOTE: relies on repo_root being set before the first call.
branch_was_started() {
  branch="$1"
  entries=$(git -C "$repo_root" reflog show --format="%gs" "$branch" 2>/dev/null) || return 1
  [ -z "$entries" ] && return 1
  active=$(printf '%s\n' "$entries" |
    grep -vE '^(branch: Created from|checkout:|rebase \(start\))' |
    wc -l | tr -d ' ')
  [ "$active" -gt 0 ]
}

repo_root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
now_ts=$(date +%s)
threshold_ts=$((now_ts - threshold_days * 86400))

# Gather running agent names
agent_names=$(herdr agent list --json 2>/dev/null | jq -r '
  .result.agents[]? | .name
' 2>/dev/null || true)

# Collect worktree list
tmpfile=$(mktemp)
trap 'rm -f "$tmpfile"' EXIT

herdr worktree list --json 2>/dev/null | jq -r '
  .result.worktrees[]
  | select(.branch != "main")
  | "\(.branch)\t\(.open_workspace_id)\t\(.path)"
' 2>/dev/null >"$tmpfile"

safe_count=0
stale_count=0

while IFS='	' read -r ws_branch ws_id ws_path || [ -n "$ws_branch" ]; do
  has_agent=false
  for name in $agent_names; do
    if [ "$name" = "$ws_branch" ]; then
      has_agent=true
      break
    fi
  done
  [ "$has_agent" = "true" ] && continue

  safe=false
  stale=false
  started=false
  dirty=false
  status=""

  # Uncommitted changes mean work is in progress, never a candidate
  if [ -n "$(git -C "$ws_path" status --porcelain 2>/dev/null)" ]; then
    dirty=true
  fi

  # A branch that was never started (reflog shows only the initial
  # creation) is excluded from deletion candidates.
  if branch_was_started "$ws_branch"; then
    started=true
  fi

  # Work in progress: report as skipped, never a deletion candidate
  if [ "$dirty" = "true" ]; then
    printf '%s\t%s\t%s\n' "$ws_branch" "IN PROGRESS (uncommitted changes)" "$ws_path"
    continue
  fi

  # Never started: report as excluded, never a deletion candidate
  if [ "$started" = "false" ]; then
    printf '%s\t%s\t%s\n' "$ws_branch" "EXCLUDED (never started)" "$ws_path"
    continue
  fi

  # Category 1: safe to delete (no diff from main + work was started + clean)
  if git -C "$repo_root" diff --quiet "main...$ws_branch" 2>/dev/null; then
    safe=true
    status="SAFE (started, no diff from main)"
    safe_count=$((safe_count + 1))
  fi

  # Category 2: possibly stale (old commits, no activity)
  if [ "$safe" = "false" ]; then
    last_commit_ts=$(git -C "$repo_root" log -1 --format=%ct "$ws_branch" 2>/dev/null || echo "0")
    if [ "$last_commit_ts" -lt "$threshold_ts" ] 2>/dev/null; then
      unpushed=$(git -C "$ws_path" log --oneline origin/main..HEAD 2>/dev/null | wc -l | tr -d ' ')
      if [ "$unpushed" -eq 0 ] && [ "$dirty" = "false" ]; then
        stale=true
        status="STALE (last commit >${threshold_days}d ago, no agent, no activity)"
        stale_count=$((stale_count + 1))
      fi
    fi
  fi

  [ "$safe" = "false" ] && [ "$stale" = "false" ] && continue

  printf '%s\t%s\t%s\n' "$ws_branch" "$status" "$ws_path"

  if [ "$mode" = "auto-clean" ] && [ "$safe" = "true" ]; then
    herdr worktree remove --workspace "$ws_id" --json 2>/dev/null &&
      printf '  => Removed\n'
  elif [ "$mode" = "force-confirm" ]; then
    printf '  Remove this worktree? [y/N] ' >&2
    read -r confirm
    if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
      herdr worktree remove --workspace "$ws_id" --json 2>/dev/null &&
        printf '  => Removed\n' ||
        printf '  => Failed\n' >&2
    fi
  fi
done <"$tmpfile"

printf '\nSummary: %d safe (no diff), %d stale (old + no activity)\n' "$safe_count" "$stale_count"
