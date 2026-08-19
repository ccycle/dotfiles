---
name: herdr-worktree-just-do-it
description: Survey every Herdr worktree for the current repo, surface the most promising one to resume, and delegate the actual motivation diagnosis to the agent that owns the context (the live agent already there, or a freshly started one). Invoke explicitly (`/herdr-worktree-just-do-it`) when the user has several stalled worktrees and doesn't know which one to pick up next. Requires HERDR_ENV=1.
disable-model-invocation: true
---

# Herdr Worktree Just Do It

## Prerequisite

```bash
test "${HERDR_ENV:-}" = 1
```

If this fails, say you are not running inside Herdr and stop.

## Step 1: Survey (cheap — no diagnosis yet)

1. `herdr worktree list` (no `--workspace`/`--cwd`) to enumerate every worktree
   of the current repo. Keep each entry's `branch`, `path`, and
   `open_workspace_id`.
2. `herdr agent list` to see which of those workspaces currently host a live
   agent, and its `agent_status`.
3. Classify each worktree:
   - Live agent with status `idle` or `done` → candidate, tag `live`.
   - No entry in `agent list` for that workspace → candidate, tag `dormant`.
     Run `git -C <path> log -1 --format='%ar | %s'` for a one-line summary.
   - Live agent with status `working` → skip entirely. It is actively
     progressing, not stalled — do not list it as a candidate.
4. Sort candidates most-recently-touched first: live agents by their last
   observed state change, dormant worktrees by the commit date from step 3.
   Recent, easy-looking items first builds momentum before older, heavier
   ones.
5. Present one line per candidate — branch, `live`/`dormant` tag, recency
   signal — and ask the user which one to pick up. Do not diagnose or guess
   at content yet; this step is a menu, not an analysis.

## Step 2: Delegate (only for the one worktree the user picked)

Do not perform the purpose/method diagnosis yourself from the outside. The
agent that owns (or will own) the context does it, using the `cheer-me-up`
skill.

- **Live candidate (idle/done)**: `herdr agent prompt <target> "/cheer-me-up" --wait`,
  then `herdr agent focus <target>` (or `herdr agent attach <target>`) to hand
  the user off directly to that session.
- **Dormant candidate**: work inside its `open_workspace_id` from Step 1, not
  the calling pane's workspace.
  1. `herdr pane list --workspace <open_workspace_id>` to find an available
     shell pane; if none, `herdr tab list --workspace <open_workspace_id>` to
     get a tab and `herdr pane split <pane_id> --direction down --no-focus`
     inside it.
  2. `herdr agent start <name> --kind claude --pane <pane_id>` — same kind as
     the current session.
  3. `herdr agent prompt <name> "..." --wait` with a prompt that includes the
     worktree's `git log`/`git diff --stat` summary and asks the agent to
     orient itself, then run `/cheer-me-up` on what it finds.
  4. `herdr agent focus <name>` (or `attach`) to hand the user off.

## Never

- Read `herdr agent read` transcripts or worktree diffs in Step 1 to guess at
  what's stalled and why. That's a full diagnosis, and it belongs to Step 2,
  delegated to the agent that owns the context — an outside read only sees
  recent scrollback, not that agent's full session history.
- List a `working` agent as a stalled candidate.
- Run any of this outside Herdr (`HERDR_ENV` unset).
