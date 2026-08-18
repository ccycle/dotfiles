#!/usr/bin/env bash
# Reconcile the `Kanban (dotfiles)` board against herdr worktree state.
# Shared by kanban-sync (standalone entry point) and obsidian-to-herdr-worktree
# (Step 1, run on every dispatch). Auto-applies deterministic transitions via
# move-card.sh (merged-and-removed -> Done, live worktree -> In progress) and
# prints one line per case that still needs a human decision, plus one line
# per state entry backfilled from an unregistered In progress card.
#
# Must be run with cwd inside a dotfiles git worktree — branches, refs and
# reflogs are shared across all worktrees of the same repo, so classifying a
# branch whose own worktree was already removed still works from here.
#
# Usage: reconcile.sh <board-path> <state-file>
#
# Output (tab-separated, one line per event, to stdout):
#   AUTO      <from-heading>     <to-heading>  <title>  <branch>
#   CONFIRM   <from-heading>     <reason>      <title>  <branch>
#   BACKFILL  <title>            <branch>
#
# <reason> for CONFIRM is NEVER_STARTED or NOT_MERGED — the same
# classification skills/user/cleanup-worktrees uses. The caller must ask the
# user (per-card, via the interactive question tool) whether a CONFIRM line
# becomes Done, Canceled, or stays in its current column, then apply the
# choice itself with move-card.sh.
set -euo pipefail

board="${1:?board path required}"
state_file="${2:?state file required}"

script_dir="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"
move_card="$script_dir/../../obsidian-to-herdr-worktree/scripts/move-card.sh"

mkdir -p "$(dirname "$state_file")"
test -f "$state_file" || echo '{}' > "$state_file"

current_branches=$(herdr worktree list | jq -r '.result.worktrees[].branch')
keep=$(printf '%s\n' "$current_branches" | jq -R -s -c 'split("\n") | map(select(length > 0))')

# Which heading (Todo / In progress) currently holds a title, or empty if the
# card isn't in either — cards elsewhere (Done, Canceled, ...) are never
# touched by this script.
card_section() {
  local title="$1"
  awk -v t="- [ ] [[${title}]]" -v p="- [ ] ${title}" '
    /^## / { section = $0; sub(/^## /, "", section); next }
    (index($0, t) || index($0, p)) && (section == "Todo" || section == "In progress") { print section; exit }
  ' "$board"
}

# Classification for a branch whose worktree is gone: MERGED, NEVER_STARTED,
# or NOT_MERGED. merge-to-main only ever deletes a branch via `git branch -d`,
# which refuses on unmerged branches, so a missing branch means it was merged.
classify_branch() {
  local branch="$1"
  if ! git show-ref --verify --quiet "refs/heads/$branch"; then
    echo MERGED
    return
  fi
  local entries active
  entries=$(git reflog show --format="%gs" "$branch" 2>/dev/null || true)
  active=$(printf '%s\n' "$entries" | grep -vE '^(branch: Created from|checkout:|rebase \(start\))' | grep -c . || true)
  if [ "${active:-0}" -eq 0 ]; then
    echo NEVER_STARTED
    return
  fi
  if git merge-base --is-ancestor "$branch" main 2>/dev/null; then
    echo MERGED
  else
    echo NOT_MERGED
  fi
}

# 1) Prune state entries whose worktree is gone, capturing title+branch first.
removed=$(jq -r --argjson keep "$keep" \
  '[to_entries[] | select(.value.branch as $b | ($keep | index($b)) | not) | "\(.value.title)\t\(.value.branch)"] | join("\n")' \
  "$state_file")
tmp=$(mktemp)
jq --argjson keep "$keep" \
  'with_entries(select(.value.branch as $b | $keep | index($b)))' \
  "$state_file" > "$tmp" && mv "$tmp" "$state_file"

if [ -n "$removed" ]; then
  while IFS=$'\t' read -r title branch; do
    [ -z "$title" ] && continue
    section=$(card_section "$title")
    [ -z "$section" ] && continue
    case "$(classify_branch "$branch")" in
      MERGED)
        "$move_card" "$board" "$section" "Done" "$title"
        printf 'AUTO\t%s\tDone\t%s\t%s\n' "$section" "$title" "$branch"
        ;;
      NEVER_STARTED)
        printf 'CONFIRM\t%s\tNEVER_STARTED\t%s\t%s\n' "$section" "$title" "$branch"
        ;;
      NOT_MERGED)
        printf 'CONFIRM\t%s\tNOT_MERGED\t%s\t%s\n' "$section" "$title" "$branch"
        ;;
    esac
  done <<< "$removed"
fi

# 2) Live worktrees: Todo -> In progress is deterministic (a live worktree is
# unambiguous evidence work is in progress), so auto-apply without asking.
live_titles=$(jq -r '.[] | "\(.title)\t\(.branch)"' "$state_file")
if [ -n "$live_titles" ]; then
  while IFS=$'\t' read -r title branch; do
    [ -z "$title" ] && continue
    section=$(card_section "$title")
    if [ "$section" = "Todo" ]; then
      "$move_card" "$board" "Todo" "In progress" "$title"
      printf 'AUTO\tTodo\tIn progress\t%s\t%s\n' "$title" "$branch"
    fi
  done <<< "$live_titles"
fi

# 3) Unregistered In progress cards: strict match only — a card's title,
# normalized, must equal a live worktree's branch name exactly. No
# similarity scoring, so this only ever fires for hand-authored English-ish
# card titles that happen to equal their branch (Japanese dispatcher titles
# never do, since Step 3's title->slug translation is a judgment call, not
# mechanical). A match backfills the mapping into the state file so a future
# run can detect this worktree's eventual removal and classify it.
normalize() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed -e 's/^-//' -e 's/-$//'
}

in_progress_titles=$(awk '
  /^## In progress/ { f = 1; next }
  /^## / && f { f = 0 }
  f && /^- \[ \] / { line = $0; sub(/^- \[ \] /, "", line); gsub(/^\[\[|\]\]$/, "", line); print line }
' "$board")

if [ -n "$in_progress_titles" ]; then
  while IFS= read -r title; do
    [ -z "$title" ] && continue
    already_tracked=$(jq -r --arg t "$title" 'any(.[]; .title == $t)' "$state_file")
    [ "$already_tracked" = "true" ] && continue
    norm_title=$(normalize "$title")
    [ -z "$norm_title" ] && continue
    while IFS= read -r branch; do
      [ -z "$branch" ] && continue
      already_branch=$(jq -r --arg b "$branch" 'any(.[]; .branch == $b)' "$state_file")
      [ "$already_branch" = "true" ] && continue
      if [ "$(normalize "$branch")" = "$norm_title" ]; then
        tmp=$(mktemp)
        jq --arg slug "$branch" --arg title "$title" --arg branch "$branch" \
           --arg backend "" --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
           '. + {($slug): {title: $title, branch: $branch, backend: $backend, dispatched_at: $ts}}' \
           "$state_file" > "$tmp" && mv "$tmp" "$state_file"
        printf 'BACKFILL\t%s\t%s\n' "$title" "$branch"
        break
      fi
    done <<< "$current_branches"
  done <<< "$in_progress_titles"
fi
