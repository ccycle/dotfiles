---
name: merge-to-main
description: Merge the current branch into main, push, and delete the branch
---

# Merge to Main

## Overview

Merge the current feature branch into main using fast-forward only (`--ff-only`), push main to origin, and delete the feature branch. Do NOT create merge commits.

## Workflow

1. **Pre-flight Check**
   - Run `git branch --show-current` to identify the current branch. Record it as `FEATURE_BRANCH`.
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

6. **Push to origin (main and rebased feature branch)**
   - Run `git push origin main` to push the merged main to the remote.

7. **Cleanup: Delete Feature Branch (local and remote)**
   - Run `git branch -d <FEATURE_BRANCH>` to delete the local feature branch.
   - If changes were stashed in step 1, run `git stash pop` to restore them.

8. **Result Report**
   - Display the name of the merged branch.
   - Run `git log --oneline -5` to show the latest commits on main.
   - Confirm the feature branch was deleted.
   - Confirm the push to origin main completed successfully.
