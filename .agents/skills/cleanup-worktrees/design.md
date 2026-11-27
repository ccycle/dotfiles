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

1. **Git hooks (event-driven)** keep the history linear locally (`hooks/` at
   the repo root, installed with `just install-git-hooks`):
   - `reference-transaction` — rejects any update of local `main` that would
     leave it different from `refs/remotes/origin/main`, covering direct
     commits, merges, rebases, cherry-picks, and `branch -f`. main is
     integrated only through Forgejo PRs.
   - `pre-push` — rejects every push to `main` on any remote, so a direct
     push to GitHub cannot bypass Forgejo and its push mirror.
   - There is deliberately **no `post-merge` hook**: cleanup is never
     automatic (see Rejected Alternatives).

2. **On-demand cleanup (human-invoked, script-decided)** handles worktree
   removal:
   - [scripts/cleanup-worktree.sh](scripts/cleanup-worktree.sh) — classifies and removes **the current
     worktree** from inside its session. The sole entry point. Every
     decision (sync, classify, refuse, remove) is an ordinary branch in the
     script, so the outcome is the same whoever runs it.
   - `/cleanup-worktrees` skill — user-invoked only
     (`disable-model-invocation`) and nothing but the script call. The
     human decides *when* to clean up; the script decides *whether* it is
     safe. The agent makes neither decision, so it has no judgment to get
     wrong and no procedure to re-derive.
   - The user-invoked `/merge-and-cleanup` skill calls the same script once
     the PR is merged, and removes only on an explicit, user-confirmed
     `--remove` re-run.
     The script is the only code path that removes a worktree.

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

## Base Branch

The branch a worktree must be merged into is a required `--base` argument
on every script, never an assumed `main`: repositories differ (`main`,
`master`, ...), and a wrong guess would classify an unmerged branch as
merged or the reverse. Callers in this repo pass `--base main` explicitly.

## Scope

The skill is repo-scoped (`.agents/skills/`), not global: removal also tears
down this repo's vm-verify VM, e2e stacks, static-reports output, and
checks the home-manager live-config links, none of which exist elsewhere.

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
- **Agent-interpreted skill (agent reads the status and decides what to
  do next).** Rejected: the same status could lead to different actions
  per session, and the agent could talk itself into removing a worktree
  another way. The script's exit code is the decision.
- **Merge skill removing the worktree implicitly after merge.** Rejected:
  merging and deleting are different decisions.
  `/merge-and-cleanup` classifies after the merge but deletes only when
  re-run with `--remove` after the user confirms.
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
