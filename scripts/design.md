# Worktree Lifecycle & Linear History

## Purpose

Automatically remove herdr-managed git worktrees after their branches are
merged to main, and enforce a linear (fast-forward-only) history on the
main branch so the commit log remains a single straight line.

## Non-Goals

- Server-side branch protection. Forgejo settings (enable push protection,
  restrict merge style to fast-forward-only) are required for full enforcement
  but are outside this repo's scope.
- Deleting local branches after worktree removal. Branch deletion is a
  separate operation (`git branch -d`).
- Cross-repo or monorepo worktree management. Only the dotfiles repo is
  covered.

## How It Works

Four layers work together:

1. **Git hooks (event-driven)** catch merge events locally and clean up
   immediately:
   - `pre-commit` — blocks direct commits on main.
   - `pre-merge-commit` — blocks non-fast-forward merges into main.
   - `pre-push` — ensures local main is an ancestor of origin/main.
   - `post-merge` — removes herdr worktrees whose branches are now merged.

2. **Merge skills (agent-driven)** clean up when an agent performs the merge:
   - `/merge` skill runs `herdr worktree remove` after merge.
   - `/merge-to-main` skill does the same.

3. **On-demand scripts** handle cases hooks cannot reach:
   - `cleanup-merged-worktrees.sh` — for GitHub/Forgejo PR merges and other
     out-of-band merges.
   - `detect-stale-worktrees.sh` — for worktrees that were never merged
     (abandoned, plan-only discussions, etc.).

4. **Just recipes** provide uniform entry points for all on-demand
   operations.

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

The same `branch_was_started` check is duplicated in the post-merge hook
and both scripts because each is a self-contained POSIX script following
the existing standalone-script convention.

## Constraints

- Scripts must work with only POSIX sh, git, jq, and herdr — all already
  present on the development machine.
- `herdr worktree remove` requires a workspace ID (not a branch name), so
  scripts map branch to workspace via `herdr worktree list --json`.
- The repo enforces linear history locally; server-side enforcement
  (Forgejo branch protection) is documented but not scripted.
- Reflog-based detection is local-only and reflog entries expire (default
  90 days); a branch with no reflog is treated as never started
  (excluded from removal) to avoid deleting work the user may resume.

## Rejected Alternatives

- **Single cleanup script run from cron/systemd timer.** Rejected because
  event-driven (post-merge hook) gives instant cleanup with zero overhead.
  On-demand scripts exist as complement, not replacement.
- **Detecting merged branch via ORIG_HEAD in post-merge.** Rejected in
  favor of checking all herdr branches against `git merge-base
  --is-ancestor`. The ORIG_HEAD approach is fragile for squash merges and
  the all-branches scan is idempotent and safe.
- **Detecting "never started" via git topology.** Rejected: a never-started
  branch and a fast-forward-merged branch are topologically identical
  (both are ancestors of main with zero unique commits). Only the branch
  reflog distinguishes them.
- **Deleting the local branch automatically after worktree removal.**
  Rejected to leave branch lifetime under user control.
- **post-rewrite hook for rebase-based merges.** Rejected because the
  repo workflow always uses fast-forward merge (not rebase-merge), so
  post-merge covers the only entry point.
