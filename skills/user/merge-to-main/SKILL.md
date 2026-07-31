---
name: merge-to-main
description: Merge the current branch into main, delete the branch, and clean up
---

# Merge to Main

## Overview

Merge the current feature branch into main using fast-forward only (`--ff-only`), then delete the feature branch and remove the herdr worktree. Do NOT create merge commits. Pushing main to origin is left to the user — it requires an interactive OTP step this skill cannot perform.

Pass `--keep` / `-k` to skip worktree removal.

## Workflow

1. **Pre-flight Check**
   - Run `git branch --show-current` to identify the current branch. Record it as `FEATURE_BRANCH`.
   - Check if `$ARGUMENTS` contains `--keep` or `-k`. If so, set `KEEP_WORKTREE=true`.
   - If on `main` or `master`, warn the user and abort — there is nothing to merge.
   - Run `git status` to check for uncommitted changes.
   - If unstaged or staged changes exist, run `git stash` to save them and record that a stash was made.

2. **Fetch Upstream**
   - Run `git fetch origin` to ensure the remote refs are up to date.

3. **Switch to main**
   - Run `git checkout main`. If that fails, fall back to `git checkout master`.
   - Run `git pull origin main` (or `git pull origin master`) to bring the local main up to date.

4. **Rebase Feature Branch onto main**
   - Run `git checkout <FEATURE_BRANCH>` to switch back to the feature branch.
   - Run `git rebase main` to rebase the feature branch onto the latest main.
   - If conflicts occur during rebase:
     - For each conflicted file, read it using the Read tool to inspect conflict markers.
     - Resolve conflicts by integrating both sides, then stage with `git add <file>`.
     - Run `git rebase --continue` to proceed.
     - Repeat until the rebase completes.
   - Run `git checkout main` to switch back to main.

5. **Execute Merge (fast-forward only)**
   - Run `git merge --ff-only <FEATURE_BRANCH>`.
   - This should always succeed after the rebase. If it fails, abort and notify the user.

6. **Cleanup: Delete Feature Branch (local)**
   - Run `git branch -d <FEATURE_BRANCH>` to delete the local feature branch.
   - If changes were stashed in step 1, run `git stash pop` to restore them.

7. **Remove herdr worktree (unless --keep)**
   - If `KEEP_WORKTREE` is `true`, skip this step.
   - If `herdr` is available, run:
     ```bash
     herdr worktree remove --json 2>/dev/null || true
     ```
   - This removes the current git worktree and its herdr workspace.
   - Note: after this step the working directory no longer exists, so any remaining work must be directory-independent.

8. **Result Report**
   - Display the name of the merged branch.
   - Run `git log --oneline -5` to show the latest commits on main.
   - Confirm the feature branch was deleted.
   - Remind the user that `main` is ahead of `origin/main` and needs to be pushed manually.
