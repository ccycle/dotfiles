#!/usr/bin/env sh
# Remove herdr worktrees for branches already merged to main.
# Intended for out-of-band merges (GitHub/Forgejo PR, etc.)
# where the post-merge hook did not fire.

set -eu

show_usage() {
  cat <<'EOF'
Usage: cleanup-merged-worktrees.sh [OPTIONS]

Remove herdr worktrees for branches already merged to main.

Worktrees that were never started (branch reflog shows only the
initial creation) are excluded from removal.

Options:
  --dry-run   List candidates without removing
  --force     Skip confirmation
  -h, --help  Show this help
EOF
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

dry_run=false
force=false

for arg in "$@"; do
  case "$arg" in
  --dry-run) dry_run=true ;;
  --force) force=true ;;
  -h | --help)
    show_usage
    exit 0
    ;;
  *)
    printf 'Unknown option: %s\n' "$arg" >&2
    show_usage
    exit 1
    ;;
  esac
done

command -v herdr >/dev/null 2>&1 || {
  printf 'herdr not found\n' >&2
  exit 1
}
command -v jq >/dev/null 2>&1 || {
  printf 'jq not found\n' >&2
  exit 1
}

repo_root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)

tmpfile=$(mktemp)
trap 'rm -f "$tmpfile"' EXIT

herdr worktree list --json 2>/dev/null | jq -r '
  .result.worktrees[]
  | select(.branch != "main")
  | "\(.branch)\t\(.open_workspace_id)\t\(.path)"
' 2>/dev/null >"$tmpfile"

removed=0
skipped=0

while IFS='	' read -r ws_branch ws_id ws_path || [ -n "$ws_branch" ]; do
  if ! git -C "$repo_root" merge-base --is-ancestor "$ws_branch" main 2>/dev/null; then
    skipped=$((skipped + 1))
    continue
  fi

  if ! branch_was_started "$ws_branch"; then
    printf 'Skip %s: never started (reflog shows only creation)\n' "$ws_branch"
    skipped=$((skipped + 1))
    continue
  fi

  if [ -n "$(git -C "$ws_path" status --porcelain 2>/dev/null)" ]; then
    printf 'Skip %s: uncommitted changes (work in progress)\n' "$ws_branch"
    skipped=$((skipped + 1))
    continue
  fi

  if [ "$dry_run" = "true" ]; then
    printf '[dry-run] Would remove worktree for %s (workspace: %s)\n' "$ws_branch" "$ws_id"
  else
    if [ "$force" = "false" ]; then
      printf 'Remove worktree for %s? [y/N] ' "$ws_branch" >&2
      read -r confirm
      [ "$confirm" != "y" ] && [ "$confirm" != "Y" ] && continue
    fi
    if herdr worktree remove --workspace "$ws_id" --json 2>/dev/null; then
      printf 'Removed worktree for %s\n' "$ws_branch"
    else
      printf 'Failed to remove worktree for %s\n' "$ws_branch" >&2
      continue
    fi
  fi
  removed=$((removed + 1))
done <"$tmpfile"

printf 'Done: %d removed, %d skipped\n' "$removed" "$skipped"
