---
name: delegate-to-agent
description: Hand the current task to a fresh opencode agent in a sibling pane of the same herdr workspace and branch, after first writing the session state to a human-readable <slug>.md handoff file (following export-session-info-to-local-md) so the handoff stays durable and readable by humans. The current agent is a thin dispatcher: it writes the md, spawns the delegate, sends one prompt, and stops — it does not wait for results. Invoke explicitly (`/delegate-to-agent [optional task text]`) when you want another opencode agent to continue the current task in-place while you stop. Requires HERDR_ENV=1.
disable-model-invocation: true
allowed-tools: Bash, Write, Read
---

# Delegate to Agent

Hand the current task over to a fresh opencode agent that continues working in
the **same workspace and branch** as you. Unlike `/worktree` (new branch) or
`/coordinator` (multiple agents), this is a one-to-one in-place handoff.

The handoff is made durable and human-readable in two artifacts:

1. A `<slug>.md` handoff file at the repo root, written per the
   `export-session-info-to-local-md` skill.
2. The spawned agent's own chat, where it continues the work from that file.

You are a **dispatcher**: after sending the prompt you are done. You do not
implement, wait, or monitor.

## Prerequisite

```bash
test "${HERDR_ENV:-}" = "1"
```

If this fails, say you are not running inside Herdr and stop.

## Step 1 — Determine the task

- If `$ARGUMENTS` contains a task description, that is the task to hand off.
- Otherwise, use the current session's task (what you have been doing).

State the task in one or two sentences — you need it in Steps 2 and 4.

## Step 2 — Write the handoff md (keep the human in the loop)

Read the `export-session-info-to-local-md` skill and follow its steps to write
`<slug>.md` at the repo root. It is available at either location (read the
first that exists):

- `~/.claude/skills/export-session-info-to-local-md/SKILL.md`
- `<repo>/.claude/skills/export-session-info-to-local-md/SKILL.md`

The md is written in English, stays human-readable, and records the plan/TODO
state so both the human and the delegate can follow the work. Record the
resulting file path (e.g. `$repo_root/<slug>.md`) — Step 4 needs it.

Do NOT skip this step: the md is a first-class deliverable for the human, not
just context for the delegate.

## Step 3 — Spawn the delegate in a sibling pane

Work in the current workspace, same cwd, keep the user's focus in the caller
pane:

1. Inspect the caller pane geometry to pick the split direction:

   ```bash
   herdr pane layout --pane "$HERDR_PANE_ID"
   ```

   Split a wide pane to the right, a narrow or tall pane down:

   ```bash
   herdr pane split --current --direction right --cwd "$PWD" --no-focus
   ```

   Read the new pane ID from `.result.pane.pane_id`.

2. Pick a unique agent name (e.g. the task slug from Step 2 plus
   `-delegate`). Confirm it is unused: `herdr agent list`.

3. Start an opencode agent in that pane. Pass `--auto` explicitly — required
   because the delegate runs unattended. Default model mirrors this session;
   override with `--model <id>` from `$ARGUMENTS` if requested.

   ```bash
   herdr agent start <name> --kind opencode --pane <pane_id> -- --auto --model opencode/deepseek-v4-flash-free
   ```

## Step 4 — Send the delegate its context (no `--wait`)

Prompt the delegate with the task and the handoff file, asking it to continue
the work in-place:

```bash
herdr agent prompt <name> "$(cat <<'EOF'
You are continuing a task in this worktree (same branch, same repo root).

First read the handoff file and follow it:
  <handoff_path>

Task: <task text / session task>

Continue the work in this worktree. Do NOT create new worktrees, do NOT spawn
more agents, and do NOT write handoff files — just do the task. Keep your
conclusions and progress in this chat.
EOF
)"$'\n' --timeout 600000
```

Do not pass `--wait`. Your job ends once the prompt is sent.

## Step 5 — Report and stop

Tell the user:

- The path of the handoff md (`<slug>.md`) — the human-readable record.
- The delegate's agent name and that it runs in the same branch.
- That the work is visible in the herdr TUI and can be continued interactively
  with `herdr agent attach <name>` or `herdr agent prompt <name> ...`.

## Rules

1. Never implement the task yourself — you are a dispatcher.
2. Never skip Step 2: the handoff md is a deliverable for the human, not just
   context for the delegate.
3. The delegate runs in an opencode agent in a sibling pane of the current
   workspace. Never create a new worktree or branch.
4. Pass `--auto` (opencode) explicitly to the delegate — never rely on the
   session's default for an unattended agent.
5. Stop after sending the prompt — do not wait, poll, or monitor.
6. The prompt must reference the handoff file and forbid nested delegation (no
   new worktrees, no further agents, no extra handoff files).