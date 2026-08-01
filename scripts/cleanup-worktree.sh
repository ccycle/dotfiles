#!/usr/bin/env sh
# Classify and optionally remove the CURRENT herdr worktree.
# Safe only when invoked from inside a linked herdr worktree, never
# from the main checkout.

set -eu

show_usage() {
    cat <<'EOF'
Usage: cleanup-worktree.sh [OPTIONS]

Classify the current herdr worktree and remove it if it is merged to
main and work was started on its branch.

When invoked from the main checkout this script refuses to run.

Options:
  --dry-run   Only classify, do not remove
  --force     Remove without confirmation (SAFE classification only)
  -h, --help  Show this help
EOF
}

dry_run=false
force=false

for arg in "$@"; do
    case "$arg" in
        --dry-run) dry_run=true ;;
        --force) force=true ;;
        -h|--help) show_usage; exit 0 ;;
        *) printf 'Unknown option: %s\n' "$arg" >&2; show_usage; exit 1 ;;
    esac
done

command -v herdr >/dev/null 2>&1 || { printf 'herdr not found\n' >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { printf 'jq not found\n' >&2; exit 1; }

cwd=$(pwd)

# Locate the herdr worktree that contains the current directory
worktree_info=$(herdr worktree list --json 2>/dev/null | jq -r --arg path "$cwd" '
  .result.worktrees[]
  | select(.path == $path)
  | "\(.branch)\t\(.open_workspace_id)\t\(.is_linked_worktree)"
' 2>/dev/null)

if [ -z "$worktree_info" ]; then
    printf 'Not inside a herdr worktree.\n' >&2
    printf 'Open one first with: herdr worktree open <branch>\n' >&2
    exit 1
fi

ws_branch=$(printf '%s\n' "$worktree_info" | cut -f1)
ws_id=$(printf '%s\n' "$worktree_info" | cut -f2)
is_linked=$(printf '%s\n' "$worktree_info" | cut -f3)

# Never remove the main checkout (is_linked_worktree = false)
if [ "$is_linked" != "true" ]; then
    printf 'This is the main checkout (branch: %s). Refusing to remove.\n' "$ws_branch" >&2
    printf 'Run this inside a linked worktree instead.\n' >&2
    exit 1
fi

# Locate the repository root from the worktree itself
repo_root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
# Prefer the actual repo root of the current worktree
worktree_repo_root=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null || echo "$repo_root")

# Return 0 if the branch has ever been worked on (reflog contains
# commit/rebase/merge/reset entries), 1 if never started (only the
# initial creation entry) or if no reflog is available.
branch_was_started() {
    branch="$1"
    entries=$(git -C "$worktree_repo_root" reflog show --format="%gs" "$branch" 2>/dev/null) || return 1
    [ -z "$entries" ] && return 1
    active=$(printf '%s\n' "$entries" \
        | grep -vE '^(branch: Created from|checkout:|rebase \(start\))' \
        | wc -l | tr -d ' ')
    [ "$active" -gt 0 ]
}

# Classification: IN PROGRESS / NEVER STARTED / NOT MERGED / SAFE
status=""

if [ -n "$(git -C "$cwd" status --porcelain 2>/dev/null)" ]; then
    status="IN PROGRESS (uncommitted changes)"
elif ! branch_was_started "$ws_branch"; then
    status="NEVER STARTED (reflog shows only creation)"
elif ! git -C "$worktree_repo_root" merge-base --is-ancestor "$ws_branch" main 2>/dev/null; then
    status="NOT MERGED (branch is not an ancestor of main)"
else
    status="SAFE (started, merged to main, clean)"
fi

printf '%s\t%s\t%s\n' "$ws_branch" "$status" "$cwd"

if [ "$status" != "SAFE (started, merged to main, clean)" ]; then
    printf 'Not removing this worktree.\n' >&2
    exit 1
fi

if [ "$dry_run" = "true" ]; then
    printf '[dry-run] Would remove worktree (workspace: %s)\n' "$ws_id"
    exit 0
fi

if [ "$force" = "false" ]; then
    printf 'Remove this worktree? [y/N] ' >&2
    read -r confirm
    [ "$confirm" != "y" ] && [ "$confirm" != "Y" ] && { printf 'Cancelled.\n' >&2; exit 1; }
fi

herdr worktree remove --workspace "$ws_id" --json 2>/dev/null && \
    printf 'Removed worktree for %s\n' "$ws_branch" || \
    { printf 'Failed to remove worktree for %s\n' "$ws_branch" >&2; exit 1; }
