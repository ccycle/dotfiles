---
name: herdr-next
description: Show which herdr worktree session to work on next, and record dependencies between sessions ("branch A waits on branch B"). Use when the user asks what to work on now, which session is waiting on them, or wants to mark one herdr session as blocked by another. Requires HERDR_ENV=1.
allowed-tools: Bash
---

# Herdr Next

Run from inside the repository whose herdr worktrees you want to rank.

## Show what to do next

```bash
scripts/next.sh
```

Relay the output to the user as-is. Groups, in priority order:

- `NEEDS YOU` — the session's agent is blocked on the user's input. Answer these first.
- `READY` — no unfinished blocker; idle or closed, so the user can push it forward.
- `RUNNING` — the agent is working; leave it.
- `WAITING` — still waiting on the listed sessions (`<- branch`).

## Record or drop a dependency

```bash
scripts/next.sh block <branch> <blocker>    # <branch> waits on <blocker>
scripts/next.sh unblock <branch> <blocker>
```

Both branches must be live herdr worktrees for `block`.
A blocker counts as finished once its worktree is removed, so no manual `unblock` is needed after a merge and cleanup.

Run `scripts/next.test.sh` after changing `next.sh`.
