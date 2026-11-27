---
name: cleanup-worktrees
description: Remove the current herdr worktree of this repository when its branch is merged to main. Runs only when the user types /cleanup-worktrees.
disable-model-invocation: true
allowed-tools: Bash
---

# Cleanup Worktrees

Run this from the worktree root and relay its output verbatim; do nothing else:

```bash
.agents/skills/cleanup-worktrees/scripts/cleanup-worktree.sh --base main --force $ARGUMENTS
```
