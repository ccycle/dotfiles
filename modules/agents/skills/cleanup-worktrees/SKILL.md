---
name: cleanup-worktrees
description: Remove the current herdr worktree when it is merged to main. Run from inside the worktree you want to delete.
allowed-tools: Bash
---

# Cleanup Worktrees

Run [the cleanup script](scripts/cleanup-worktree.sh) from inside the worktree to delete (deployed at `~/.claude/skills/cleanup-worktrees/scripts/cleanup-worktree.sh`):

```bash
scripts/cleanup-worktree.sh --force
```

It fast-forwards local main to origin/main, classifies the current worktree, and removes it only when the status is `SAFE`.
Any other status exits non-zero and removes nothing; `--dry-run` classifies without removing.

Report the printed status to the user.
When the script refuses, explain why and stop; never try to remove the worktree another way.
The one status that needs the user is `LIVE CONFIG`: ask them to run darwin-rebuild from a main checkout, then re-run.

Removal deletes the working directory, so make it the last action in the session.

[cleanup-merged-worktrees.sh](scripts/cleanup-merged-worktrees.sh) and [detect-stale-worktrees.sh](scripts/detect-stale-worktrees.sh) scan all worktrees at once; see [design.md](design.md).
