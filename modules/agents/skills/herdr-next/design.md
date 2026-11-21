# herdr-next Design

## Purpose

Tell the user which herdr worktree session to attend to next, from live herdr state plus a small record of which session waits on which.

## Non-Goals

- No priorities, due dates, or effort estimates; ordering comes only from agent state and dependencies.
- No graph rendering; a grouped list is the whole output.
- No link to the Obsidian Kanban board: most sessions have no card, so dependencies live beside herdr state instead.

## Rejected Alternatives

- Treating a blocker as finished once its branch is an ancestor of main.
  A freshly created branch with no commits is already an ancestor of main, so it would count as finished before any work happens.
  Worktree removal is used instead, because worktrees are removed only after their branch merges.

## Constraints

- Dependencies are keyed by branch name alone, in one state file shared by every repository.
  Two repositories with the same branch name would share dependency entries; key by repository if that ever happens.
- The test stubs the herdr CLI because the real one needs a running herdr server; only herdr is stubbed, and jq runs for real.
