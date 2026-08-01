# Worktree Lifecycle & Linear History

## Purpose

Clean up herdr-managed git worktrees once their branches are merged to
main, and enforce a linear (fast-forward-only) history on the main branch
so the commit log remains a single straight line. Worktree removal is an
explicit, interactive action — nothing removes a worktree automatically.

## Non-Goals

- Server-side branch protection. Forgejo settings (enable push protection,
  restrict merge style to fast-forward-only) are required for full enforcement
  but are outside this repo's scope.
- Deleting local branches after worktree removal. Branch deletion is a
  separate operation (`git branch -d`).
- Cross-repo or monorepo worktree management. Only the dotfiles repo is
  covered.

## How It Works

Two layers work together:

1. **Git hooks (event-driven)** keep the history linear locally:
   - `pre-commit` — blocks direct commits on main.
   - `pre-merge-commit` — blocks non-fast-forward merges into main.
   - `pre-push` — ensures local main is an ancestor of origin/main.
   - There is deliberately **no `post-merge` hook**: cleanup is never
     automatic (see Rejected Alternatives).

2. **On-demand cleanup (agent-driven, interactive)** handles worktree
   removal:
   - `cleanup-worktree.sh` — classifies and removes **the current worktree**
     from inside its session. The sole entry point.
   - `/cleanup-worktrees` skill — wraps the script in an interactive flow:
     classify → report → confirm → remove. It is the only way a worktree
     is removed.
   - Merge skills (`/merge`, `/merge-to-main`) never remove worktrees;
     they finish by pointing the user at `/cleanup-worktrees`.

The all-branch scanning scripts (`cleanup-merged-worktrees.sh`,
`detect-stale-worktrees.sh`) from the earlier hook-driven design are kept as
supporting tools for inspecting all worktrees at once; removal itself always
happens per-worktree from inside the target session.

## Worktree Classification

"Never started" worktrees are excluded from removal; "started then
discarded" worktrees are removal candidates. Three classification rules,
checked in order:

- **Work in progress (uncommitted changes):** excluded from removal.
  `git status --porcelain` in the worktree is non-empty, so the working
  tree may hold work the user has not committed.
- **Never started:** the branch reflog contains only the initial
  `branch: Created from` entry. Git topology alone cannot distinguish
  this from a fast-forward-merged branch (both have an empty
  `rev-list main..branch` and no diff from main), so the branch reflog
  is the deciding signal.
- **Started then discarded:** the reflog shows commit/rebase/merge/reset
  entries but the branch now points at a plain main commit (e.g. the
  work was rebased away or abandoned). These are removal candidates.

The same `branch_was_started` check is duplicated in each script because
each is a self-contained POSIX script following the existing
standalone-script convention.

## Constraints

- Scripts must work with only POSIX sh, git, jq, and herdr — all already
  present on the development machine.
- `herdr worktree remove` requires a workspace ID (not a branch name), so
  scripts map the current directory to its branch/workspace via
  `herdr worktree list --json` and match on `path`.
- The main checkout is identified by `is_linked_worktree == false` and is
  never removable.
- The repo enforces linear history locally; server-side enforcement
  (Forgejo branch protection) is documented but not scripted.
- Reflog-based detection is local-only and reflog entries expire (default
  90 days); a branch with no reflog is treated as never started
  (excluded from removal) to avoid deleting work the user may resume.

## Rejected Alternatives

- **Automatic cleanup via `post-merge` hook.** Rejected. Instant cleanup
  sounded attractive, but a hook cannot confirm intent, so it can delete a
  worktree the user wants to keep (e.g. to inspect the merged diff or open
  the session again). Every removal is now an explicit, confirmed action.
- **Cleanup script run from cron/systemd timer.** Rejected for the same
  reason: no interactive confirmation, and it cannot know which worktree
  the user is working in.
- **Merge skills removing the worktree after merge.** Rejected in favor of
  separation of concerns: merging and deleting are different decisions.
  The merge skills now only suggest `/cleanup-worktrees`.
- **Detecting merged branch via ORIG_HEAD in post-merge.** Rejected in
  favor of checking the current branch against `git merge-base
  --is-ancestor` main. The ORIG_HEAD approach is fragile for squash merges;
  the ancestor check is idempotent and safe.
- **Detecting "never started" via git topology.** Rejected: a never-started
  branch and a fast-forward-merged branch are topologically identical
  (both are ancestors of main with zero unique commits). Only the branch
  reflog distinguishes them.
- **Deleting the local branch automatically after worktree removal.**
  Rejected to leave branch lifetime under user control.
