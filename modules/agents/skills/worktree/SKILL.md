---
name: worktree
description: Launch one or more tasks in new git worktrees using herdr.
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

**`--merge`**: When passed, add instruction to use `/merge-to-main` skill at
the end to rebase and merge the branch into main.

```
...
Then use the /merge-to-main skill to rebase and merge the branch into main.
```

Only instruct worktree agent to `/merge-to-main` if explicitly requested by
user in task.


## Workflow

Write ALL temp files first, THEN spawn all worktree agents.

**IMPORTANT:** Run spawn commands from the CURRENT directory. Do NOT `cd` to the
main repo or any other directory. The new worktree branches from whatever branch
is checked out in the current directory.

Step 1 - Write all prompt files (in parallel):

```bash
tmpfile=$(mktemp).md
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

# Start claude agent in the new workspace's pane
herdr agent start <worktree-name> --kind claude --pane "$pane_id"

# Send prompt from file
herdr agent prompt <worktree-name> "$(cat /tmp/tmp.abc123.md)" --timeout 600000
```

Do NOT pass `--wait` to `herdr agent prompt` — the dispatcher does not wait for
agents to finish.
