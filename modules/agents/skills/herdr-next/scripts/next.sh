#!/usr/bin/env bash
set -euo pipefail

state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/herdr-next"
deps="$state_dir/deps.json"
mkdir -p "$state_dir"
[ -f "$deps" ] || echo '{}' >"$deps"

worktrees=$(herdr worktree list --cwd "$PWD")

save() {
  local filter="$1" tmp
  shift
  tmp=$(mktemp)
  jq "$@" "$filter" "$deps" >"$tmp" && mv "$tmp" "$deps"
}

require_live() {
  if ! jq -e --arg b "$1" '.result.worktrees | any(.branch == $b)' <<<"$worktrees" >/dev/null; then
    echo "error: no live herdr worktree has branch '$1'" >&2
    exit 1
  fi
}

case "${1:-}" in
block)
  [ $# -eq 3 ] || {
    echo "usage: next.sh block <branch> <blocker>" >&2
    exit 2
  }
  [ "$2" != "$3" ] || {
    echo "error: a branch cannot block itself" >&2
    exit 1
  }
  require_live "$2"
  require_live "$3"
  save '.[$b].blocked_by = ((.[$b].blocked_by // []) + [$x] | unique)' --arg b "$2" --arg x "$3"
  exit 0
  ;;
unblock)
  [ $# -eq 3 ] || {
    echo "usage: next.sh unblock <branch> <blocker>" >&2
    exit 2
  }
  save 'if .[$b] then .[$b].blocked_by -= [$x] else . end' --arg b "$2" --arg x "$3"
  exit 0
  ;;
"") ;;
*)
  echo "usage: next.sh [block|unblock <branch> <blocker>]" >&2
  exit 2
  ;;
esac

workspaces=$(herdr workspace list)

jq -c --slurpfile deps "$deps" --argjson ws "$workspaces" '
  ($ws.result.workspaces | map({key: .workspace_id, value: .agent_status}) | from_entries) as $status
  | [.result.worktrees[] | select(.is_linked_worktree) | .branch] as $live
  | .result.worktrees[]
  | select(.is_linked_worktree)
  | (($status[.open_workspace_id // ""]) // "closed") as $s
  | [($deps[0][.branch].blocked_by // [])[] | select(. as $x | $live | index($x))] as $open
  | (if $s == "blocked" then "NEEDS YOU"
     elif ($open | length) > 0 then "WAITING"
     elif $s == "working" then "RUNNING"
     else "READY" end) as $group
  | {group: $group, branch, s: $s, open: $open}
' <<<"$worktrees" | jq -rs '
  ["NEEDS YOU", "READY", "RUNNING", "WAITING"] as $order
  | group_by(.group) | sort_by(.[0].group as $g | $order | index($g)) | .[]
  | "== \(.[0].group)", (.[] | "  \(.branch)  [\(.s)]" + (if (.open | length) > 0 then "  <- \(.open | join(", "))" else "" end))
'
