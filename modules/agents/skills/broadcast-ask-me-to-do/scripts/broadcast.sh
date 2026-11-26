#!/usr/bin/env bash
set -euo pipefail

usage="usage: broadcast.sh [--dry-run]"
dry_run=false
case "${1:-}" in
  "") ;;
  --dry-run) dry_run=true ;;
  *) echo "$usage" >&2; exit 2 ;;
esac

if [[ "${HERDR_ENV:-}" != 1 ]]; then
  echo "broadcast.sh: not inside a Herdr pane (HERDR_ENV != 1)" >&2
  exit 1
fi
: "${HERDR_PANE_ID:?broadcast.sh: HERDR_PANE_ID is not set}"

herdr agent list | jq -r --arg self "$HERDR_PANE_ID" '
  .result.agents[]
  | select(.pane_id != $self)
  | [.pane_id, .agent, .agent_status] | @tsv' |
while IFS=$'\t' read -r pane kind status; do
  if [[ "$status" != "idle" && "$status" != "done" ]]; then
    echo "skip $pane ($kind, $status)"
    continue
  fi
  if [[ "$kind" == claude ]]; then
    message="/ask-me-to-do"
  else
    message="Load the ask-me-to-do skill and follow it whenever you need a decision or an action from me for the rest of this session."
  fi
  if $dry_run; then
    echo "would send $pane ($kind): $message"
  elif herdr agent prompt "$pane" "$message" >/dev/null; then
    echo "sent $pane ($kind)"
  else
    echo "FAILED $pane ($kind)" >&2
  fi
done
