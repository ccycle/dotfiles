---
name: coordinator
description: Orchestrate multiple worktree agents. Spawn, monitor, communicate, and merge.
allowed-tools: Bash, Write, Read, Task
disable-model-invocation: true
---

# Worktree Agent Coordinator

You are a coordinator agent. You orchestrate multiple worktree agents. You do
NOT implement tasks yourself. You spawn agents, monitor them, send instructions,
and trigger merges.

## Backend detection

Check `HERDR_ENV`:

```bash
test "${HERDR_ENV:-}" = "1"
```

- Use **herdr** commands throughout

## Core Concepts

- **Worktree agent**: a Claude Code session running in its own git
  worktree/branch
- **Handle / Name**: the identifier used to address agents in all commands
- **Statuses**: `working` (processing), `waiting`/`blocked` (needs user input),
  `done`/`idle` (finished)
- Agents run in background; you interact via CLI only

## Spawn Agents

For each task, write a prompt file then spawn the agent. You are a dispatcher.
Do NOT read source files, edit code, or implement tasks yourself.

**Prompt file rules:**

- Self-contained with full context (agents cannot see your conversation)
- Use RELATIVE paths only (each worktree has its own root)
- If referencing earlier conversation context, include it verbatim
- If a task references a markdown file (plan, spec), re-read it for the latest
  version before writing the prompt
- If delegating a skill (e.g., `/auto`), instruct the agent to use it. Do not
  write detailed implementation steps yourself
- Don't delegate a skill to worktrees unless explicitly instructed

**Spawning workflow: write ALL files first, THEN spawn ALL agents.**

```bash
# Step 1: Write all prompt files (in parallel)
tmpfile_a=$(mktemp).md
cat > "$tmpfile_a" << 'EOF'
Implement auth module...
EOF

tmpfile_b=$(mktemp).md
cat > "$tmpfile_b" << 'EOF'
Write API tests...
EOF

# Step 2: Spawn all agents (in parallel, after ALL files exist)
# See backend-specific sections below
```

## Command Reference

### herdr backend

**Spawn:**

```bash
result=$(herdr worktree create --branch auth-module --no-focus --json)
pane_id=$(echo "$result" | jq -r '.result.root_pane.pane_id')
herdr agent start auth-module --kind claude --pane "$pane_id"
herdr agent prompt auth-module "$(cat "$tmpfile_a")" --timeout 600000
```

**Monitor:**

```bash
herdr agent list
```

**Wait:**

```bash
# Wait for agent to finish (idle, done, or blocked)
herdr agent wait auth-module --timeout 3600000

# Wait for agent to start working (confirm launch)
herdr agent wait auth-module --until working --timeout 120000
```

**Read output:**

```bash
herdr agent read auth-module --source recent-unwrapped --lines 200
```

**Send instructions:**

```bash
herdr agent prompt auth-module "fix the failing tests" --wait --timeout 600000
```

**Merge & cleanup:**

```bash
# Tell agent to merge its own branch
herdr agent prompt auth-module "/merge-to-main" --wait --timeout 120000
```

## Workflow Patterns

### Fan-out / Fan-in

Spawn multiple agents, wait for all, review, merge:

```bash
# 1. Write ALL prompt files first (see "Spawn Agents" above)
# 2. Spawn agents in background (use appropriate backend)
# 3. Confirm they started
#    herdr: herdr agent wait <name> --until working --timeout 120000
# 4. Wait for completion
#    herdr: herdr agent wait <name> --timeout 7200000
# 5. Review results
#    herdr: herdr agent read <name> --source recent-unwrapped --lines 50
# 6. Merge successful agents (one at a time, wait between each)
#    herdr: herdr agent prompt <name> "/merge-to-main" --wait --timeout 120000
# 7. Send follow-up if needed
```

## Rules

1. **Write ALL prompt files before spawning any agents.** Prompts should be
   self-contained with full context. Agents cannot see your conversation.
2. **Spawn agents in background** so you stay in your own session.
3. **Always confirm agents started** before waiting for completion.
4. **Capture and review output** before merging. Do not blindly merge.
5. **Merge one at a time** by sending `/merge-to-main` to each agent sequentially. Wait
   for each merge to complete before starting the next to avoid conflicts.
6. **Use timeouts** to avoid waiting forever. Handle timeout exits gracefully.
7. **Prompt files should use relative paths** (each worktree has its own root).
8. You are a coordinator, not an implementer. Never edit source files directly.
