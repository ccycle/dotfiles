---
name: git-rebase
description: Git Rebase
---

# Git Rebase

## Overview

Rebase the current branch onto an upstream base, resolving any conflicts intelligently by integrating both sides of changes.

## Workflow

1. **Pre-flight Check**
   - Run `git branch --show-current` to identify the current branch.
   - If on `main` or `master`, warn the user and abort — rebasing these branches is unsafe.
   - Run `git status` to check for uncommitted changes.
   - If unstaged or staged changes exist, run `git stash` to save them before proceeding.

2. **Fetch Upstream**
   - Run `git fetch origin` to ensure the remote refs are up to date.

3. **Execute Rebase**
   - Determine the base to rebase onto:
     - Default: `origin/main`
     - If the user provided an argument (e.g., `/git-rebase origin/develop`), use that instead.
   - Run `git rebase <base>`.

4. **Conflict Resolution Loop**
   - After each rebase step, run `git status` to check for conflicts.
   - For each conflicted file:
     - Read the file using the Read tool to inspect conflict markers (`<<<<<<<`, `=======`, `>>>>>>>`).
     - Understand both sides:
       - `HEAD` (upstream / base branch): what the target branch has
       - Incoming (your branch): what your commits introduce
     - Resolution principles:
       - **Integrate both sides** — preserve the intent of each change.
       - If upstream deleted a line your branch modifies, **keep the modification** (prefer change over deletion).
       - If both sides touched the same logic differently, merge them logically rather than picking one blindly.
     - Write the resolved content back and stage the file with `git add <file>`.
   - Run `git rebase --continue` to proceed to the next commit.
   - Repeat until `git status` shows no more conflicts and the rebase completes.

5. **Restore Stash**
   - If changes were stashed in step 1, run `git stash pop` to restore them.

6. **Result Report**
   - Run `git log --oneline <base>..HEAD` to show the rebased commits.
   - List any files where conflicts were resolved.
   - Confirm the rebase completed successfully.
