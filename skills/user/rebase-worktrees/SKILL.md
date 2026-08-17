---
name: rebase-worktrees
description: Pull main, then rebase every other git worktree onto the updated main branch.
---

# Rebase Worktrees

## Overview

Update the local `main` (or `master`) branch from its remote, then rebase
every other worktree in the repository onto that fresh `main`. Conflicts are
resolved by integrating both sides, the same principle as the `git-rebase`
skill. A worktree that cannot be rebased cleanly is left untouched (rebase
aborted) and reported, so one problem worktree never blocks the rest.

## Workflow

1. **Enumerate worktrees**
   - Run `git worktree list --porcelain` from the current directory.
   - Parse it into `<path> <branch>` pairs. Entries marked `bare` or
     `detached` have no branch to rebase — skip them and record `N/A`.

2. **Identify and update main**
   - Find the worktree whose branch is `main` (fall back to `master` if there
     is no `main`); call its path `MAIN_PATH` and its branch `MAIN_BRANCH`.
   - If no worktree has `main`/`master` checked out, stop and ask the user
     which branch to treat as the rebase target and where it's checked out.
   - Run `git -C "$MAIN_PATH" status --porcelain`. If it reports changes, stop
     and report — never touch a dirty main worktree.
   - Run `git -C "$MAIN_PATH" fetch origin`.
   - Run `git -C "$MAIN_PATH" pull --ff-only origin "$MAIN_BRANCH"`.
     - If this fails (diverged history, no upstream, etc.), stop the entire
       operation and report it. Rebasing other worktrees onto a stale or
       broken main is worse than doing nothing.

3. **Rebase every other worktree**
   For each worktree path/branch pair other than `MAIN_PATH` (skipping the
   `bare`/`detached` entries noted in step 1):
   - Run `git -C "$path" status --porcelain`. If it reports changes, skip this
     worktree and record `SKIPPED (uncommitted changes)`. Do not stash on the
     user's behalf across multiple worktrees — a stash left behind in a
     worktree you're not currently looking at is easy to forget.
   - Run `git -C "$path" rebase "$MAIN_BRANCH"`.
   - If it succeeds with commits replayed, record `REBASED`.
   - If it reports the branch was already up to date, record `UP TO DATE`.
   - If conflicts occur:
     - For each conflicted file, read it to inspect the conflict markers
       (`<<<<<<<`, `=======`, `>>>>>>>`).
     - Resolve by integrating both sides: prefer a modification over a
       deletion, and merge logic that both sides touched differently rather
       than picking one side blindly.
     - Stage each resolved file and run `git -C "$path" rebase --continue`.
       Repeat until the rebase completes.
     - If a conflict is too ambiguous to resolve confidently, run
       `git -C "$path" rebase --abort` to restore the worktree to its
       pre-rebase state, and record `ABORTED (conflict: <short reason>)`.
       Continue to the next worktree — never let one worktree's conflicts
       block the batch.

4. **Result report**
   - Print a table: `<branch>  <path>  <status>`.
   - Call out any `ABORTED` or `SKIPPED` worktrees explicitly, and tell the
     user what manual step brings each one up to date (resolve the conflict
     themselves, or commit/stash their changes and re-run this skill).

## Rules

- Never force-push or touch remote state — this only updates local refs
  (`pull --ff-only` on main, `rebase` on everything else).
- Never rebase a dirty worktree, and never rebase `main` itself onto anything.
- If `pull --ff-only` on main fails, abort the entire run before touching any
  other worktree.
- One worktree's conflict must never block the others: on an ambiguous
  conflict, abort that worktree's rebase and move on to the next.
