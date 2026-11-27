#!/usr/bin/env sh
# Remove herdr worktrees for branches already merged to a base branch.
# Intended for out-of-band merges (GitHub/Forgejo PR, etc.)
# where the post-merge hook did not fire.

set -eu

show_usage() {
  cat <<'EOF'
Usage: cleanup-merged-worktrees.sh --base BRANCH [OPTIONS]

Remove herdr worktrees for branches already merged to BRANCH.

Worktrees that were never started (branch reflog shows only the
initial creation) are excluded from removal.

Options:
  --base BRANCH  Branch to treat as merged into (e.g. main, master)
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

# herdr worktree remove only accepts --workspace, so a worktree not open in
# any workspace (empty ID) goes through git. No --force: the caller has
# already checked merged/started/clean, and git still refuses a dirty tree.
remove_worktree() {
  if [ -n "$1" ]; then
    herdr worktree remove --workspace "$1" --json 2>/dev/null
  else
    git -C "$repo_root" worktree remove "$2"
  fi
}

base=""
dry_run=false
force=false

while [ "$#" -gt 0 ]; do
  case "$1" in
  --base)
    [ "$#" -ge 2 ] || {
      printf -- '--base needs a branch name\n' >&2
      exit 1
    }
    base=$2
    shift
    ;;
  --dry-run) dry_run=true ;;
  --force) force=true ;;
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

[ -n "$base" ] || {
  printf -- '--base BRANCH is required (e.g. --base main)\n' >&2
  exit 1
}

command -v herdr >/dev/null 2>&1 || {
  printf 'herdr not found\n' >&2
  exit 1
}
command -v jq >/dev/null 2>&1 || {
  printf 'jq not found\n' >&2
  exit 1
}

repo_root=$(git -C "$(dirname -- "$0")" rev-parse --show-toplevel)

tmpfile=$(mktemp)
trap 'rm -f "$tmpfile"' EXIT

herdr worktree list --json 2>/dev/null | jq -r '
  .result.worktrees[]
  | select(.branch != $base)
  | "\(.branch)\t\(.path)\t\(.open_workspace_id // "")"
' --arg base "$base" 2>/dev/null >"$tmpfile"

removed=0
skipped=0

# ws_id is last: an unopened worktree has an empty ID, and an empty middle
# field would collapse under IFS whitespace splitting and shift the path.
while IFS='	' read -r ws_branch ws_path ws_id || [ -n "$ws_branch" ]; do
  if ! git -C "$repo_root" merge-base --is-ancestor "$ws_branch" "$base" 2>/dev/null; then
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
    printf '[dry-run] Would remove worktree for %s (workspace: %s)\n' "$ws_branch" "${ws_id:-none, not open in herdr}"
  else
    if [ "$force" = "false" ]; then
      printf 'Remove worktree for %s? [y/N] ' "$ws_branch" >&2
      read -r confirm
      [ "$confirm" != "y" ] && [ "$confirm" != "Y" ] && continue
    fi
    if remove_worktree "$ws_id" "$ws_path"; then
      printf 'Removed worktree for %s\n' "$ws_branch"
    else
      printf 'Failed to remove worktree for %s\n' "$ws_branch" >&2
      continue
    fi
  fi
  removed=$((removed + 1))
done <"$tmpfile"

printf 'Done: %d removed, %d skipped\n' "$removed" "$skipped"
