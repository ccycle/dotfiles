#!/usr/bin/env bash
# Move a card in the Todo section of the `Kanban (dotfiles)` board to the Done
# section. Only the skill's Step 1 prune should call this; the board's Todo and
# Done sections are the only sections it touches.
#
# Usage: move-card-to-done.sh <board-path> "<card title>"
set -euo pipefail

board="${1:?board path required}"
title="${2:?card title required}"
card="- [ ] [[${title}]]"

[ -f "$board" ] || { echo "board not found: $board" >&2; exit 1; }

# 1) Remove the card from the Todo section (only there).
tmp=$(mktemp)
awk -v card="$card" '
  /^## Todo/ { in_todo = 1 }
  /^## / && $0 != "## Todo" && in_todo { in_todo = 0 }
  in_todo && index($0, card) { next }
  { print }
' "$board" > "$tmp"

# 2) Insert the card as the last item of the Done section — but only if it is
#    not already there (the human may have moved it by hand).
mv "$tmp" "$board"
if awk '/^## Done/{in_done=1} /^## / && $0 != "## Done" && in_done{in_done=0} in_done && index($0, card){found=1} END{exit !found}' card="$card" "$board"; then
  rm -f "$tmp"
  exit 0
fi
awk -v card="$card" '
  /^## Done/ { in_done = 1 }
  /^## / && $0 != "## Done" && in_done {
    if (!inserted) { print card; print "" }
    inserted = 1
    in_done = 0
  }
  { print }
  END { if (in_done && !inserted) print card }
' "$board" > "$tmp" && mv "$tmp" "$board"
