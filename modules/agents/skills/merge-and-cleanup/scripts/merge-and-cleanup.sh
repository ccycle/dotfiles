#!/usr/bin/env bash
# End-of-task workflow for the current herdr worktree, driven by the state of its branch's Forgejo PR.
# Re-run the same command after each state change; every run does only the step the current state allows.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: merge-and-cleanup.sh [--remove]

Run from inside a herdr worktree whose task is committed.
What happens depends on the branch's Forgejo PR:

  no PR    Rebase onto origin/main, push, open the PR (title/body autofilled
           from the commits), and write the Obsidian AgentDrafts result page.
  open     Print the PR URL and stop. The user merges it on Forgejo.
  merged   Fast-forward local main, then classify this worktree with
           cleanup-worktree.sh --dry-run.
           With --remove, delete the worktree if it classifies SAFE.
  closed   (not merged) Fail.

Options:
  --remove    Remove this worktree (merged state only).
  -h, --help  Show this help.
EOF
}

die() {
  printf 'merge-and-cleanup: %s\n' "$*" >&2
  exit 1
}

remove=false
[ $# -le 1 ] || die "too many arguments"
case "${1:-}" in
"") ;;
--remove) remove=true ;;
-h | --help)
  usage
  exit 0
  ;;
*)
  usage >&2
  die "unknown argument: $1"
  ;;
esac

[ "${HERDR_ENV:-}" = 1 ] || die "not running inside Herdr (HERDR_ENV is not 1)"
for c in git jq curl fj herdr; do
  command -v "$c" >/dev/null || die "$c not found in PATH"
done

top=$(git rev-parse --show-toplevel 2>/dev/null) || die "not inside a git worktree"
cd "$top"
branch=$(git branch --show-current)
[ -n "$branch" ] || die "HEAD is detached"
case "$branch" in main | master) die "on $branch; run from the task's feature worktree" ;; esac
[ -z "$(git status --porcelain)" ] || die "uncommitted changes; commit them first"

# Forgejo API base from origin: https://<host>/<owner>/<repo>[.git] -> https://<host>/api/v1/repos/<owner>/<repo>
origin_url=$(git remote get-url origin) || die "no 'origin' remote"
origin_url=${origin_url%.git}
host=${origin_url%/*/*}
case "$host" in https://*) ;; *) die "origin is not an https Forgejo URL: $origin_url" ;; esac
api="$host/api/v1/repos/${origin_url#"$host"/}"

# The pulls list has no head-branch filter, so match head.label (the branch name, kept after the branch is deleted).
# ponytail: only the 50 most recently updated PRs are searched; paginate if older branches must be found.
find_pr() {
  curl -fsS "$api/pulls?state=all&sort=recentupdate&limit=50" |
    jq -c --arg b "$branch" 'first(.[] | select(.head.label == $b)) // empty'
}

# Write AgentDrafts/<title>.md for a task dispatched via obsidian-to-herdr-worktree; the title is keyed by the worktree slug.
# A task that was never dispatched has no source note to link back to, so the page is skipped, not invented.
write_note() {
  local pr_url=$1 dispatched slug title drafts note
  dispatched="$HOME/.local/state/obsidian-todo-dispatch/dispatched.json"
  # shellcheck disable=SC2295 # the * must glob: strip ~/.herdr/worktrees/<repo>/
  slug=${top#$HOME/.herdr/worktrees/*/}
  title=
  [ ! -f "$dispatched" ] || title=$(jq -r --arg s "$slug" '.[$s].title // empty' "$dispatched")
  if [ -z "$title" ]; then
    printf 'No dispatched task for slug %s; skipped the Obsidian result page.\n' "$slug"
    return
  fi
  # Bullet tree only, no headings or frontmatter (obsidian-manager note conventions).
  note=$(
    printf -- '- [[%s]] への回答\n  - PR: %s\n  - コミット\n' "$title" "$pr_url"
    git log --reverse --format='    - %s' origin/main..HEAD
    printf -- '  - 変更ファイル\n'
    git diff --numstat origin/main..HEAD | awk -F'\t' '{printf "    - `%s` (+%s -%s)\n", $3, $1, $2}'
  )
  drafts="$HOME/Obsidian/zettelkasten/AgentDrafts"
  # Never create AgentDrafts/ (vault trust boundary); print the page for a manual copy instead.
  if [ ! -d "$drafts" ]; then
    printf '%s does not exist; result page follows:\n%s\n' "$drafts" "$note"
    return
  fi
  [ ! -e "$drafts/$title.md" ] || die "$drafts/$title.md already exists; not overwriting"
  printf '%s\n' "$note" >"$drafts/$title.md"
  printf 'Wrote %s\n' "$drafts/$title.md"
}

pr=$(find_pr)
state=$(jq -r 'if . == null then "none" elif .merged then "merged" else .state end' <<<"${pr:-null}")
[ "$remove" = false ] || [ "$state" = merged ] || die "--remove applies only once the PR is merged (PR state: $state)"

case "$state" in
none)
  git fetch origin main
  git rebase origin/main || {
    git rebase --abort
    die "rebase onto origin/main has conflicts; resolve them manually, then re-run"
  }
  # A branch pushed before this rebase needs a lease-protected force push; a fresh branch pushes normally either way.
  git push --force-with-lease -u origin HEAD
  fj pr -R origin create --autofill --base main --head "$branch"
  pr=$(find_pr)
  [ -n "$pr" ] || die "PR was created but not found via $api/pulls"
  pr_url=$(jq -r .html_url <<<"$pr")
  printf 'Opened PR #%s: %s\n' "$(jq -r .number <<<"$pr")" "$pr_url"
  write_note "$pr_url"
  ;;
open)
  printf 'PR #%s is open: %s\nMerge it on Forgejo, then re-run this script.\n' \
    "$(jq -r .number <<<"$pr")" "$(jq -r .html_url <<<"$pr")"
  ;;
merged)
  cleanup="$top/.agents/skills/cleanup-worktrees/scripts/cleanup-worktree.sh"
  [ -x "$cleanup" ] || die "this repository has no cleanup-worktrees skill at $cleanup"
  if [ "$remove" = true ]; then
    exec "$cleanup" --base main --force
  fi
  "$cleanup" --base main --dry-run
  printf 'Re-run with --remove to delete this worktree.\n'
  ;;
*) die "PR #$(jq -r .number <<<"$pr") was closed without merging" ;;
esac
