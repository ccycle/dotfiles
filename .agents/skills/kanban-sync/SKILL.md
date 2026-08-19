---
name: kanban-sync
description: Standalone sync of the `Kanban (dotfiles)` board against herdr worktree state. Auto-applies deterministic status transitions without confirmation (Todo -> In progress for a live worktree; Todo/In progress -> Done for a worktree that was removed after its branch merged to main) and asks per-card confirmation only for the ambiguous cases (a removed worktree whose branch was never started or never merged). Shares its reconcile logic with `obsidian-to-herdr-worktree`'s Step 1, which calls the same script on every dispatch run — this skill is the entry point for running that sync on its own, without dispatching anything. Use when the user wants the Kanban board brought up to date with the current worktrees right now, rather than waiting for the next dispatch.
disable-model-invocation: true
allowed-tools: Bash
---

# Kanban Sync

Bring the `Kanban (dotfiles)` board's card columns in line with what the
herdr worktrees actually say happened, without dispatching any new workers.
This is the standalone counterpart to `obsidian-to-herdr-worktree`'s Step 1 —
both call the same shared script, so the reconcile behavior is identical
whether it runs here or as part of a dispatch.

## Prerequisite

```bash
test "${HERDR_ENV:-}" = "1"
```

If this fails, say you are not running inside Herdr and stop. This skill
only supports the herdr backend.

## Step 1 — Run the shared reconcile script

```bash
board="$HOME/Obsidian/zettelkasten/Kanban (dotfiles).md"
state_file="$HOME/.local/state/obsidian-todo-dispatch/dispatched.json"
.agents/skills/kanban-sync/scripts/reconcile.sh "$board" "$state_file"
```

Must be run with `cwd` inside this repository (any worktree) — the script
classifies branches via `git`, and worktrees of the same repo share refs and
reflogs regardless of which one you run it from.

The script itself applies every deterministic move (it calls `move-card.sh`
directly) and prints one tab-separated line per event to stdout:

- `AUTO <from> <to> <title> <branch>` — already applied to the board, no
  action needed from you beyond reporting it.
- `CONFIRM <from> <reason> <title> <branch>` — the worktree for this card
  was removed but the classification isn't deterministic (`reason` is
  `NEVER_STARTED` or `NOT_MERGED`). Needs a decision from the user; see
  Step 2.
- `BACKFILL <title> <branch>` — an In progress card that wasn't in the state
  file was matched (exact normalized title == branch name) to a live
  worktree and registered, so a future run can detect its eventual removal.
  No board change; nothing to report beyond noting it happened.

## Step 2 — Ask about each CONFIRM line

For every `CONFIRM` line, ask the user individually via the interactive
question tool — never assume, never batch-apply. Give the `reason` as
context:

- `NEVER_STARTED`: the worktree was removed but no work was ever done on the
  branch (reflog shows only its creation).
- `NOT_MERGED`: the worktree was removed and the branch has unmerged work
  that never made it into `main`.

Offer the same three choices Step 1 of `obsidian-to-herdr-worktree` always
offered for a removed worktree: move to `Done`, move to `Canceled`, or leave
in `<from>`. Apply a confirmed move with:

```bash
.agents/skills/obsidian-to-herdr-worktree/scripts/move-card.sh \
  "$board" "<from>" "<target-column>" "<title>"
```

## Step 3 — Report and stop

Summarize what happened: how many `AUTO` moves were applied (and to which
columns), how many `BACKFILL` registrations occurred, and the outcome of
each `CONFIRM` decision. Do not touch the Obsidian vault beyond the Kanban
column moves already covered above, and do not dispatch any workers — that
is `obsidian-to-herdr-worktree`'s job, not this skill's.

## Rules

1. This skill never creates worktrees, never starts agents, and never reads
   or selects Todo notes for dispatch — it only reconciles existing board
   state against existing worktree state.
2. Never apply a `CONFIRM` move without an explicit answer from the user,
   per card.
3. The reconcile logic lives in `scripts/reconcile.sh`, shared with
   `obsidian-to-herdr-worktree`'s Step 1 — do not duplicate its logic
   inline in either `SKILL.md`; both call the one script.
