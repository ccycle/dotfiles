---
name: cleanup-worktrees
description: Remove the current herdr worktree when it is merged to main. Run from inside the worktree you want to delete.
allowed-tools: Bash
---

# Cleanup Worktrees

Remove the herdr worktree you are currently in, but only when it is safe
to do so: the branch has been started (reflog shows work) and is already
merged to main.

## When to use

Call this after the branch has been merged to main, while sitting inside
that worktree's session. It deletes the worktree you are in — nothing else.

This replaces automatic deletion: no git hook removes worktrees, and
`/merge-to-main` does not remove them on your behalf. Cleanup is always
explicit and interactive.

## Backend detection

Check `HERDR_ENV`:

```bash
test "${HERDR_ENV:-}" = "1"
```

- Use **herdr** commands throughout

## Workflow

### 1. Classify the current worktree

Run the cleanup script from the repo root of the current worktree:

```bash
./scripts/cleanup-worktree.sh --dry-run
```

The script prints `<branch>\t<status>\t<path>` and exits non-zero when the
worktree must not be removed.

Interpret the status:

| Status | Meaning | Action |
|--------|---------|--------|
| `SAFE (started, merged to main, clean)` | ready for removal | proceed |
| `NOT MERGED (branch is not an ancestor of main)` | work not in main yet | do NOT remove |
| `NEVER STARTED (reflog shows only creation)` | no work ever done | do NOT remove |
| `IN PROGRESS (uncommitted changes)` | has uncommitted work | do NOT remove |
| `Refusing to remove` (main checkout) | not a linked worktree | do NOT remove |

### 2. Report to the user

Tell the user the classification. If the status is not SAFE, explain why
and stop. Do not attempt removal.

### 3. Remove

If the classification is SAFE, remove it without confirmation:

```bash
./scripts/cleanup-worktree.sh --force
```


## Rules

- Only remove the worktree you are currently in — never another worktree,
  and never the main checkout.
- Never use `--force` to override a non-SAFE classification.
- After removal the working directory no longer exists; make removal the
  last action in the session.
