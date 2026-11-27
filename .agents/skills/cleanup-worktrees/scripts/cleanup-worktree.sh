#!/usr/bin/env sh
# Classify and optionally remove the CURRENT herdr worktree.
# Safe only when invoked from inside a linked herdr worktree, never
# from the main checkout.

set -eu

show_usage() {
  cat <<'EOF'
Usage: cleanup-worktree.sh --base BRANCH [OPTIONS]

Classify the current herdr worktree and remove it if it is merged to
BRANCH and work was started on its branch.

When invoked from the main checkout this script refuses to run.

Options:
  --base BRANCH  Branch the worktree must be merged into (e.g. main, master)
  --dry-run   Only classify, do not remove
  --force     Remove without confirmation (SAFE classification only)
  -h, --help  Show this help
EOF
}

base=""
dry_run=false
force=false

while [ "$#" -gt 0 ]; do
  arg=$1
  shift
  case "$arg" in
  --base)
    [ "$#" -gt 0 ] || {
      printf -- '--base needs a branch name\n' >&2
      exit 1
    }
    base=$1
    shift
    ;;
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

# Use the worktree root, not $PWD, so running from a subdirectory still
# matches herdr's worktree path.
cwd=$(git rev-parse --show-toplevel 2>/dev/null) || {
  printf 'Not inside a git worktree.\n' >&2
  exit 1
}

# Locate the herdr worktree that contains the current directory
worktree_info=$(herdr worktree list --json 2>/dev/null | jq -r --arg path "$cwd" '
  .result.worktrees[]
  | select(.path == $path)
  | "\(.branch)\t\(.open_workspace_id // "")\t\(.is_linked_worktree)"
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

worktree_repo_root=$cwd

# A Forgejo merge does not move the local base branch, and classification checks against it.
git -C "$cwd" fetch -q origin || {
  printf 'git fetch origin failed; cannot classify against an up-to-date %s.\n' "$base" >&2
  exit 1
}
base_wt=$(git -C "$cwd" worktree list --porcelain | awk -v ref="branch refs/heads/$base" '/^worktree /{p=substr($0, 10)} $0 == ref {print p}')
if [ -n "$base_wt" ]; then
  git -C "$base_wt" merge -q --ff-only "origin/$base"
else
  git -C "$cwd" fetch -q origin "$base:$base"
fi || {
  printf 'Could not fast-forward local %s to origin/%s.\n' "$base" "$base" >&2
  exit 1
}

# Return 0 if the branch has ever been worked on (reflog contains
# commit/rebase/merge/reset entries), 1 if never started (only the
# initial creation entry) or if no reflog is available.
branch_was_started() {
  branch="$1"
  entries=$(git -C "$worktree_repo_root" reflog show --format="%gs" "$branch" 2>/dev/null) || return 1
  [ -z "$entries" ] && return 1
  printf '%s\n' "$entries" | grep -qvE '^(branch: Created from|checkout:|rebase \(start\))'
}

# Return 0 if the active home-manager generation links into this worktree.
# Out-of-store symlinks resolve to the checkout that ran darwin-rebuild, so removing that checkout would break the live ~/.claude and ~/.config files.
is_live_config_source() {
  home_files="$(readlink -f "$HOME/.local/state/home-manager/gcroots/current-home")/home-files"
  [ -d "$home_files" ] || return 1
  find "$home_files/" -type l | while read -r link; do
    case "$(readlink -f "$link")" in "$worktree_repo_root"/*) echo hit && break ;; esac
  done | grep -q hit
}

# Classification: IN PROGRESS / NEVER STARTED / NOT MERGED / LIVE CONFIG / SAFE
status=""

if [ -n "$(git -C "$cwd" status --porcelain 2>/dev/null)" ]; then
  status="IN PROGRESS (uncommitted changes)"
elif ! branch_was_started "$ws_branch"; then
  status="NEVER STARTED (reflog shows only creation)"
elif ! git -C "$worktree_repo_root" merge-base --is-ancestor "$ws_branch" "$base" 2>/dev/null; then
  status="NOT MERGED (branch is not an ancestor of $base)"
elif is_live_config_source; then
  status="LIVE CONFIG (home-manager links point here; darwin-rebuild from $base first)"
else
  status="SAFE (started, merged to $base, clean)"
fi

printf '%s\t%s\t%s\n' "$ws_branch" "$status" "$cwd"

case "$status" in SAFE*) ;; *)
  printf 'Not removing this worktree.\n' >&2
  exit 1
  ;;
esac

if [ "$dry_run" = "true" ]; then
  printf '[dry-run] Would remove worktree (workspace: %s)\n' "${ws_id:-none, not open in herdr}"
  exit 0
fi

if [ "$force" = "false" ]; then
  printf 'Remove this worktree? [y/N] ' >&2
  read -r confirm
  [ "$confirm" != "y" ] && [ "$confirm" != "Y" ] && {
    printf 'Cancelled.\n' >&2
    exit 1
  }
fi

vm_name="dotfiles-verify-$(basename "$worktree_repo_root")"
if command -v tart >/dev/null 2>&1; then
  tart list --quiet 2>/dev/null | grep -xE "${vm_name}(--run[0-9]+)?" | while IFS= read -r vm; do
    tart stop "$vm" >/dev/null 2>&1 || true
    tart delete "$vm" >/dev/null 2>&1 || true
  done
fi

# Tear down every co-located e2e test stack (modules/*/tests/*/scripts/
# stack.sh), so containers, networks and named volumes don't linger after
# the worktree directory disappears. Suites that keep a one-time passkey
# bootstrap (OpenCloud, reports) only `down` after each run, so their
# volumes survive until this point. Bind-mounted data lives under each
# suite's .state/ inside the checkout and is removed along with it.
for stack in "$worktree_repo_root"/modules/*/tests/*/scripts/stack.sh; do
  [ -x "$stack" ] || continue
  "$stack" teardown >/dev/null 2>&1 || true
done

# Remove this branch's published e2e reports (modules/static-reports),
# keyed the same way the e2e run.sh scripts publish them: branch name with
# '/' replaced by '-'. Whole branch dir, not per-service, since a branch may
# have reports from multiple e2e suites (opencloud/forgejo/immich/monitoring).
# Best-effort: reports_base_dir may not exist on hosts without static-reports
# enabled, and each run.sh's own retention prune (14d) remains as a backstop
# for branches whose cleanup script was never run (e.g. orphaned worktrees).
reports_base_dir="/var/lib/static-reports"
branch_slug=$(printf '%s' "$ws_branch" | tr '/' '-')
rm -rf "${reports_base_dir:?}/${branch_slug}" 2>/dev/null || true

# herdr worktree remove only accepts --workspace, so a worktree not open in
# any workspace goes through git. No --force: classification already required
# a clean tree, and git still refuses if it turned dirty meanwhile.
if [ -n "$ws_id" ]; then
  herdr worktree remove --workspace "$ws_id" --json 2>/dev/null
else
  git -C "$worktree_repo_root" worktree remove "$cwd"
fi || {
  printf 'Failed to remove worktree for %s\n' "$ws_branch" >&2
  exit 1
}
printf 'Removed worktree for %s\n' "$ws_branch"
