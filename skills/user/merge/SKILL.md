---
name: merge
description: Commit, rebase, and merge the current branch.
disable-model-invocation: true
allowed-tools: Read, Bash, Glob, Grep
---

<!-- Customize the commit style and rebase behavior to match your workflow. -->

**Arguments:** `$ARGUMENTS`

Check the arguments for flags:

- `--keep`, `-k` → keep the worktree after merging (herdr: skip worktree remove; workmux: pass `--keep`)
- `--no-verify`, `-n` → workmux only: pass `--no-verify` to `workmux merge`

Strip all flags from arguments.

## Backend detection

Check `HERDR_ENV`:

```bash
test "${HERDR_ENV:-}" = "1"
```

- If `HERDR_ENV=1`: use **herdr** merge flow (step 3a)
- Otherwise: use **workmux** merge flow (step 3b)

## Step 1: Commit

If there are staged changes, commit them. Use lowercase, imperative mood, no conventional commit prefixes. Skip if nothing is staged.

## Step 2: Rebase

Get the base branch. Try these sources in order:

1. `git config --local --get "branch.$(git branch --show-current).workmux-base"`
2. Fall back to `main`

Rebase onto the local base branch (do NOT fetch from origin first):

```
git rebase <base-branch>
```

IMPORTANT: Do NOT run `git fetch`. Do NOT rebase onto `origin/<branch>`. Only rebase onto the local branch name (e.g., `git rebase main`, not `git rebase origin/main`).

If conflicts occur:

- BEFORE resolving any conflict, understand what changes were made to each
  conflicting file in the base branch
- For each conflicting file, run `git log -p -n 3 <base-branch> -- <file>` to
  see recent changes to that file in the base branch
- The goal is to preserve BOTH the changes from the base branch AND our branch's
  changes
- After resolving each conflict, stage the file and continue with
  `git rebase --continue`
- If a conflict is too complex or unclear, ask for guidance before proceeding

## Step 3a: herdr merge flow

After a successful rebase, the branch is fast-forward mergeable. Update the base
branch ref from within the worktree:

```bash
git push . HEAD:<base-branch>
```

Then, unless `--keep` was passed, remove the worktree and its herdr workspace:

```bash
herdr worktree remove --json
```

## Step 3b: workmux merge flow

Run: `workmux merge --rebase --notification [--keep] [--no-verify]`

Include `--keep` only if the `--keep` flag was passed in arguments.
Include `--no-verify` only if the `--no-verify` flag was passed in arguments.

This will merge the branch into the base branch and clean up the worktree and
tmux window (unless `--keep` is used).
