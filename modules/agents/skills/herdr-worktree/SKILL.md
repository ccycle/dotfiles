---
name: herdr-worktree
description: Launch one or more tasks in new git worktrees using herdr, each handed to a fresh agent of a selectable kind (`--kind`) and model (`--model`).
disable-model-invocation: true
allowed-tools: Bash, Write
---

Launch one or more tasks in new git worktrees.

Tasks: $ARGUMENTS

## Backend detection

Check `HERDR_ENV`:

```bash
test "${HERDR_ENV:-}" = "1"
```

- Use **herdr** commands throughout (see "herdr backend" below)

## You are a dispatcher, not an implementer

**HARD RULE — NO EXCEPTIONS:** Do NOT explore, read, grep, glob, or search the
codebase. Do NOT use the Task/Explore agent. Do NOT investigate the problem. You
are a thin dispatcher — your ONLY job is to write prompt files and spawn
worktree agents. The worktree agent will do all the exploration and
implementation.

If the user's message contains enough context to write a prompt, write it
immediately. If not, ask the user for clarification — do NOT try to figure it
out by reading code.

If tasks reference earlier conversation (e.g., "do option 2"), include all
relevant context in each prompt you write.

If tasks reference a markdown file (e.g., a plan or spec), re-read the file to
ensure you have the latest version before writing prompts.

For each task:

1. Generate a short, descriptive worktree name (2-4 words, kebab-case)
2. Write a detailed implementation prompt to a temp file
3. Spawn the worktree agent using the appropriate backend

The prompt file should:

- Include the full task description
- Use RELATIVE paths only (never absolute paths, since each worktree has its own
  root directory)
- Be specific about what the agent should accomplish

## Skill delegation

If the user passes a skill reference (e.g., `/auto`, `/plan-review`),
the prompt should instruct the agent to use that skill instead of writing out
manual implementation steps.

**Skills can have flags.** If the user passes `/auto --gemini`, pass the
flag through to the skill invocation in the prompt.

Example prompt:

```
[Task description here]

Use the skill: /skill-name [flags if any] [task description]
```

Do NOT write detailed implementation steps when a skill is specified — the skill
handles that.

## Flags

**`--pr`**: When passed, add an instruction to run the `merge-and-cleanup`
script at the end to open a Forgejo PR for the branch.
The skill itself is user-invoked only, so the worktree agent runs its script
directly.

```
...
Then run ~/.claude/skills/merge-and-cleanup/scripts/merge-and-cleanup.sh to open a Forgejo PR for the branch.
```

Only add this instruction if the user explicitly requested it in the task.

**`--kind <kind>`**: Agent kind passed to `herdr agent start --kind` (any value
`herdr agent start --help` lists, e.g. `claude`, `opencode`, `pi`, `codex`).
Omitted → `claude`. Applies to every task in the invocation.

**`--model <id>`**: Model for the spawned agent, forwarded after `--` as
`--model <id>` (claude, opencode, and pi all accept that flag; for other kinds,
check `<kind> --help` and use its equivalent). Omitted → pass nothing and let
the agent CLI use its own default. Never invent a model ID.

Strip these flags from `$ARGUMENTS` before treating the rest as tasks.

## Workflow

Write ALL temp files first, THEN spawn all worktree agents.

**IMPORTANT:** Run spawn commands from the CURRENT directory. Do NOT `cd` to the
main repo or any other directory. The new worktree branches from whatever branch
is checked out in the current directory.

Step 1 - Write all prompt files (in parallel):

```bash
tmpfile=$(mktemp -t prompt.XXXXXX.md)
cat > "$tmpfile" << 'EOF'
Implement feature X...
EOF
echo "$tmpfile"  # Note the path for step 2
```

Step 2 - After ALL files are written, spawn all agents (in parallel).

After creating the worktrees, inform the user which branches were created.

**Remember:** Your task is COMPLETE once worktrees are created. Do NOT implement
anything yourself.

---

## herdr backend

For each task, after writing the prompt file:

```bash
# Create worktree + workspace (--no-focus keeps current pane focused)
result=$(herdr worktree create --branch <worktree-name> --no-focus --json)
pane_id=$(echo "$result" | jq -r '.result.root_pane.pane_id')

# Start the agent in the new workspace's pane.
# <kind> from --kind (default claude). Append `-- --model <id>` only when
# --model was given. opencode runs unattended, so it also needs `--auto`:
#   herdr agent start <name> --kind opencode --pane "$pane_id" -- --auto [--model <id>]
herdr agent start <worktree-name> --kind <kind> --pane "$pane_id" [-- --model <id>]

# Send prompt from file
herdr agent prompt <worktree-name> "$(cat /tmp/tmp.abc123.md)"
```

Do NOT pass `--wait` to `herdr agent prompt` — the dispatcher does not wait for
agents to finish.
