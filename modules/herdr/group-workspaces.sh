#!/usr/bin/env bash
# Reorder Herdr workspaces so labels sharing a prefix (text before the first
# "-", "/" or space) sit next to each other. Groups keep the order in which
# their first member appears; members keep their relative order.
#
# Linked-worktree workspaces are sorted only among the children of their
# parent (the open primary checkout with the same repo_key) and placed right
# after it, so Herdr's parent/child packing is preserved.
#
# The CLI has no workspace move command, so this talks to the socket API.
# The socket path comes from `herdr status` because keybinding shells are not
# guaranteed to inherit HERDR_SOCKET_PATH.
set -euo pipefail

socket=$(herdr status server | awk '$1 == "socket:" { print $2 }')
if [ -z "$socket" ]; then
  echo "could not read the server socket path from 'herdr status server'" >&2
  exit 1
fi

call() {
  printf '%s\n' "$1" | nc -U -w 2 "$socket"
}

order=$(
  call '{"id":"list","method":"workspace.list","params":{}}' |
    jq -c '
      def prefix: .label | split("[-/ ]"; null)[0];
      def grouped: . as $ws
        | ($ws | map(prefix) | reduce .[] as $p ([]; if index([$p]) then . else . + [$p] end))
        | [.[] as $g | $ws[] | select(prefix == $g)];
      .result.workspaces as $all
      | [$all[] | select(.worktree.is_linked_worktree != true) | .worktree.repo_key // empty] as $parents
      | def is_child: .worktree.is_linked_worktree == true and (.worktree.repo_key as $k | $parents | index([$k]));
      [$all[] | select(is_child | not)] | grouped
      | [.[] as $top
          | $top.workspace_id,
            ([$all[] | select(is_child and $top.worktree.repo_key != null
                and .worktree.repo_key == $top.worktree.repo_key)]
             | grouped | .[].workspace_id)]'
)

response=$(call "$(jq -cn --argjson ids "$order" \
  '{id: "move", method: "workspace.move_block", params: {workspace_ids: $ids, before_workspace_id: null}}')")

if jq -e '.error' <<<"$response" >/dev/null; then
  echo "workspace.move_block failed: $response" >&2
  exit 1
fi
