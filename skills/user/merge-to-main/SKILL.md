---
name: merge-to-main
description: Merge the current branch into main, push, and delete the branch
---

# Merge to Main

## Overview

Merge the current feature branch into main using `--no-ff`, push main to origin, and delete the feature branch.

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

4. **Execute Merge**
   - Run `git merge --no-ff <FEATURE_BRANCH>` to merge the feature branch with a merge commit.

5. **Conflict Resolution Loop**
   - After the merge, run `git status` to check for conflicts.
   - For each conflicted file:
     - Read the file using the Read tool to inspect conflict markers (`<<<<<<<`, `=======`, `>>>>>>>`).
     - Understand both sides:
       - `HEAD` (main): what the target branch has
       - Incoming (feature branch): what the feature commits introduce
     - Resolution principles:
       - **Integrate both sides** — preserve the intent of each change.
       - If main deleted a line the feature branch modifies, **keep the modification** (prefer change over deletion).
       - If both sides touched the same logic differently, merge them logically rather than picking one blindly.
     - Write the resolved content back and stage the file with `git add <file>`.
   - Run `git merge --continue` to complete the merge.
   - Repeat until `git status` shows no more conflicts and the merge completes.

6. **Push to origin**
   - Run `git push origin main` to push the merged main to the remote.

7. **Cleanup: Delete Feature Branch**
   - Run `git branch -d <FEATURE_BRANCH>` to delete the local feature branch.
   - If changes were stashed in step 1, run `git stash pop` to restore them.

8. **Result Report**
   - Display the name of the merged branch.
   - Run `git log --oneline -5` to show the latest commits on main.
   - Confirm the feature branch was deleted.
   - Confirm the push to origin main completed successfully.
