#!/usr/bin/env bash
# Move a card between sections of the `Kanban (dotfiles)` board. Matches a card
# by title whether it is a `[[wiki-link]]` or a plain-text card. Called by
# obsidian-to-herdr-worktree's Step 1/7 and by kanban-sync's reconcile.sh —
# directly for deterministic moves, or after explicit per-card user
# confirmation for ambiguous ones; it touches only the source and target
# sections.
#
# The exact line is captured and re-inserted verbatim, so trailing kanban
# metadata (dates, tags) survives the move. The script aborts rather than
# corrupting the board: if the card is not in the source section (e.g. the
# human moved it by hand) or the target section does not exist.
#
# Usage: move-card.sh <board-path> <source-heading> <target-heading> "<card title>"
set -euo pipefail

board="${1:?board path required}"
source_heading="${2:?source heading required}"
target_heading="${3:?target heading required}"
title="${4:?card title required}"

[ -f "$board" ] || {
  echo "board not found: $board" >&2
  exit 1
}

card="- [ ] [[${title}]]"
plain="- [ ] ${title}"

in_section() {
  # Exit 0 if the board already contains the card in the given section.
  awk -v card="$card" -v plain="$plain" -v heading="## $1" '
    $0 == heading { found = 1; next }
    found && /^## / { found = 0 }
    found && (index($0, card) || index($0, plain)) { hit = 1 }
    END { exit !hit }
  ' "$board"
}

# 1) Remove the card from the source section, capturing the exact line so any
#    trailing kanban metadata survives. Abort if the card is not there — a
#    blind re-insert would duplicate the card in two columns.
captured=$(mktemp)
tmp=$(mktemp)
if ! awk -v card="$card" -v plain="$plain" -v heading="## $source_heading" \
  -v out="$captured" '
    $0 == heading { in_source = 1 }
    /^## / && in_source && $0 != heading { in_source = 0 }
    in_source && (index($0, card) || index($0, plain)) {
      if (!removed) { print > out; removed = 1 }
      next
    }
    { print }
    END { if (!removed) exit 1 }
  ' "$board" >"$tmp"; then
  rm -f "$tmp" "$captured"
  echo "move-card: card not in '$source_heading' section (moved by hand?): $title" >&2
  exit 1
fi
mv "$tmp" "$board"

# 2) If the card is already in the target section (the human may have moved it
#    by hand), there is nothing to do.
if in_section "$target_heading"; then
  rm -f "$captured"
  exit 0
fi

# 3) Insert the card as the last item of the target section. Abort if the
#    target section does not exist, instead of dropping the card.
if ! awk -v heading="## $target_heading" '$0 == heading { found = 1 } END { exit !found }' "$board"; then
  rm -f "$captured"
  echo "move-card: target section '$target_heading' not found on board" >&2
  exit 1
fi
insert_line=$(cat "$captured")
rm -f "$captured"
tmp=$(mktemp)
awk -v card="$insert_line" -v heading="## $target_heading" '
  $0 == heading { in_target = 1 }
  /^## / && in_target && $0 != heading {
    if (!inserted) { print card; print "" }
    inserted = 1
    in_target = 0
  }
  { print }
  END { if (in_target && !inserted) print card }
' "$board" >"$tmp" && mv "$tmp" "$board"
