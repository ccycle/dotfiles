#!/usr/bin/env bash
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
api=https://forgejo.mac-mini-m4-pro.internal/api/v1/repos/ccycle/dotfiles
worktrees="$HOME/.herdr/worktrees/dotfiles"

git fetch -q origin
agents="$(herdr agent list)" || {
  echo "error: herdr agent list failed; this skill must run inside Herdr" >&2
  exit 2
}

printf 'pr\tbranch\thead\ton_main\tci\tagent_pane\tagent_status\n'
curl -fsS "$api/pulls?state=open&limit=50" | jq -r '.[] | "\(.number)\t\(.head.ref)\t\(.head.sha)"' |
  while IFS=$'\t' read -r n branch sha; do
    on_main=no
    git merge-base --is-ancestor origin/main "$sha" && on_main=yes
    ci="$("$here/ci-state.sh" "$sha" 2>/dev/null)" || true
    pane=none status=none
    if [ ! -d "$worktrees/$branch" ]; then
      pane=no-worktree
    else
      read -r pane status < <(jq -r --arg cwd "$worktrees/$branch" \
        '[.result.agents[] | select(.cwd == $cwd)][0] // {pane_id: "none", agent_status: "none"} | "\(.pane_id) \(.agent_status)"' <<<"$agents")
    fi
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$n" "$branch" "${sha:0:10}" "$on_main" "$ci" "$pane" "$status"
  done
