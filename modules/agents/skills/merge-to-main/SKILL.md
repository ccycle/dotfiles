---
name: merge-to-main
description: Merge the current branch into main and delete the branch
---

# Merge to Main

## Overview

Merge the current feature branch into main using fast-forward only (`--ff-only`). Do NOT create merge commits. Pushing main to origin is left to the user — it requires an interactive OTP step this skill cannot perform.

Worktree removal is NOT part of this skill. After the merge, suggest the user run `/cleanup-worktrees` from the worktree to remove it interactively.

## Workflow

1. **Pre-flight Check**
   - Run `git branch --show-current` to identify the current branch. Record it as `FEATURE_BRANCH`.
   - If on `main` or `master`, warn the user and abort — there is nothing to merge.
   - Run `git status` to check for uncommitted changes.
   - If unstaged or staged changes exist, run `git stash` to save them and record that a stash was made.

2. **Detect worktree layout**
   - Run `git worktree list --porcelain` and look for an entry whose branch is `refs/heads/main` (or `refs/heads/master`), e.g.:
     ```
     git worktree list --porcelain | awk '/^worktree/{p=$2} /^branch refs\/heads\/(main|master)$/{print p}'
     ```
   - If no such entry is found, `main` is not checked out anywhere else in this repository — use the **Plain flow** (step 3).
   - If found, record its path as `MAIN_WORKTREE` and use the **Worktree flow** (step 4). `MAIN_WORKTREE` is never the current directory, since step 1 already confirmed the current branch is not `main`/`master`.

3. **Plain flow** (main is not checked out elsewhere)
   - Run `git fetch origin` to ensure the remote refs are up to date.
   - Run `git checkout main`. If that fails, fall back to `git checkout master`.
   - Run `git pull origin main` (or `git pull origin master`) to bring local main up to date.
   - Run `git checkout <FEATURE_BRANCH>` to switch back to the feature branch.
   - Run `git rebase main`. If conflicts occur, follow **Conflict resolution** below.
   - Run `git checkout main` to switch back to main.
   - Run `git merge --ff-only <FEATURE_BRANCH>`. This should always succeed after the rebase; if it fails, abort and notify the user.
   - Run `git branch -d <FEATURE_BRANCH>` to delete the local feature branch.
   - Continue to step 5.

4. **Worktree flow** (main is checked out in a different worktree, `MAIN_WORKTREE`)
   - Run `git -C <MAIN_WORKTREE> status --porcelain`. If any line does not start with `??` (i.e. a tracked file has local modifications), abort and tell the user to commit or clean up `<MAIN_WORKTREE>` first — a fast-forward merge there would otherwise be rejected or overwrite those edits. Untracked files do not block the merge.
   - Run `git -C <MAIN_WORKTREE> pull origin main` (or `master`) to bring main up to date. Worktrees share the same refs, so this update is immediately visible from the current worktree.
   - From the current (feature) worktree, run `git rebase main`. If conflicts occur, follow **Conflict resolution** below.
   - Run `git -C <MAIN_WORKTREE> merge --ff-only <FEATURE_BRANCH>`. This should always succeed after the rebase; if it fails, abort and notify the user.
   - Do NOT run `git branch -d <FEATURE_BRANCH>` — the branch is still checked out in this worktree, so git refuses to delete it (`error: cannot delete branch ... used by worktree`). Skip deletion; removing this worktree via `/cleanup-worktrees` deletes the branch along with it.
   - Continue to step 5.

5. **Cleanup and Result Report**
   - If changes were stashed in step 1, run `git stash pop` to restore them.
   - Display the name of the merged branch.
   - Run `git log --oneline -5` on main (`git log --oneline -5` in the plain flow, `git -C <MAIN_WORKTREE> log --oneline -5` in the worktree flow) to show the latest commits.
   - Report whether the feature branch was deleted (plain flow) or left checked out pending worktree removal (worktree flow).
   - Remind the user that `main` is ahead of `origin/main` and needs to be pushed manually.
   - Tell the user they can now run `/cleanup-worktrees` from this worktree — in the worktree flow this is how the feature branch itself gets deleted.

## Conflict resolution

If `git rebase main` reports conflicts:

- BEFORE resolving any conflict, understand what changes were made to each conflicting file on `main`. Run `git log -p -n 3 main -- <file>` to see its recent history.
- The goal is to preserve BOTH main's changes AND the feature branch's changes.
- For each conflicted file, read it with the Read tool to inspect the conflict markers, resolve by integrating both sides, then stage with `git add <file>`.
- Run `git rebase --continue` to proceed. Repeat until the rebase completes.
- If a conflict is too complex or unclear, ask the user for guidance before proceeding.
