---
name: export-session-info-to-local-md
description: Export the current agent session's task status (task summary, done/in-progress/pending TODO, key decisions, next steps, blockers) to a `<slug>.md` file at the git repo root, where the slug is derived from the task name, so unfinished work can be handed off to another agent session or resumed later. Invoke explicitly (`/export-session-info-to-local-md`) when pausing or ending a session whose task is not finished and needs to be picked up elsewhere. Content is the agent's own session context — plan and TODO state only, no git diff/status and no herdr state. Written in English for token efficiency.
disable-model-invocation: true
allowed-tools: Bash, Read, Write
---

# Export Session Info to Local Markdown

Write a durable handoff snapshot of the current session's task state to
`<slug>.md` at the git repo root. The file records the *plan and TODO state*
the successor needs to continue the work: what the task is, what is done, what
is in progress, what comes next, and what is blocking.

This skill is for handoff of **unfinished** work. If the task is complete,
merged, or the worktree is about to be cleaned up, a handoff file is
unnecessary — do not run it.

## Step 1 — Identify the task name

The task name is what this session is working on. State it from your own
conversation context — the task is always something the human asked you to do
in this session. Do not invent one.

Optionally cross-reference: if you are inside a herdr worktree and the machine
local dispatch state exists, the observed note title under the current branch
is the canonical task name:

```bash
test -f "$HOME/.local/state/obsidian-todo-dispatch/dispatched.json" \
  && jq -r '.["'"$(git branch --show-current)"'"].title // empty' \
       "$HOME/.local/state/obsidian-todo-dispatch/dispatched.json"
```

Treat this only as a hint. The authoritative task name is what the
conversation says this session is about — the observed title is a fine
substitute when the conversation is thin.

## Step 2 — Derive the slug from the task name

Convert the task name to a short English kebab-case slug (2-4 words, ASCII,
no `.md`). Translating a Japanese or natural-language task name into a good
slug is a judgment call — use your own understanding of what the task is
actually about, mirroring the rule herdr worktree branches follow.

- If the dispatch state from Step 1 returned a title for the current branch,
  that branch slug is the canonical task slug — prefer it over inventing a new
  one, so the handoff file stays aligned with the worktree branch.
- Otherwise, invent the slug from the task name as described above.
- If the task is too broad or vague to yield a meaningful slug, tell the user
  and stop rather than writing a misleading filename.

The output file is `$repo_root/$slug.md`.

## Step 3 — Locate the repo root and read the existing file

```bash
repo_root=$(git rev-parse --show-toplevel)
```

If this fails, you are not inside a git repository — say so and stop.

```bash
handoff="$repo_root/$slug.md"
test -f "$handoff" && echo "exists"
```

If the file exists, read it before overwriting: an earlier session may have
recorded decisions or next steps that are still relevant. Fold anything still
true into the new snapshot.

## Step 4 — Gather the session state from your own context

Compose the content yourself from what you actually know about this session —
do not invent facts and do not go hunting through git history or herdr state.
The successor needs enough to continue without re-reading the conversation:

- **Task summary**: what this session is about, in one or two sentences.
- **Progress**: done / in progress / not started. Base this on your actual
  session state (todo list, tools called, files changed).
- **Key decisions**: judgment calls already made and why — the successor must
  not silently reverse them.
- **Next steps**: the concrete first actions for the successor.
- **Blockers / open questions**: anything unresolved the successor will hit.

If your session context is thin (e.g., no todo list and little history), say
so in the file rather than padding it — an honest short file is more useful
than a fabricated long one.

Write the entire file in English for token efficiency — the successor agent
reads this, not a human.

## Step 5 — Write the file

Overwrite `<slug>.md` with the current snapshot, following this skeleton.
Adapt it to the task; the sections are a guide, not a straitjacket.

```markdown
# Handoff: <task summary>

- Timestamp: <YYYY-MM-DD HH:MM>
- Branch: <branch>
- Repo: <repo root>

## Task summary
<1–2 sentences on what this session is about>

## Progress
- Done
  - <item>
- In progress
  - <item>
- Not started
  - <item>

## Key decisions
- <decision and rationale>

## Next steps
- <first concrete action for the successor>

## Blockers / open questions
- <item> (or "none")
```

```bash
# write the file (path: $repo_root/$slug.md)
```

## Step 6 — Report

Tell the user:
- The path of the written file (`<slug>.md`)
- A one-line summary of the snapshot
- That the successor agent (or the human) can read the file to continue;
  suggest committing it if it should travel with the branch

## Rules

1. Write only `<slug>.md` at the git repo root — never create any other file,
   and never write outside the repository.
2. The slug is derived from the **task name** (Step 1–2), not from the branch
   name. Never fall back to the branch name or a generic label.
3. Overwrite an existing file — it is a snapshot of current state, not an
   append log. Read the old file first (Step 3) and carry forward anything
   still relevant.
4. Write in English throughout — token efficiency matters; the successor agent
   is the primary reader.
5. Include plan/TODO state only — no git diff/stat, no herdr/agent status, no
   command logs. Git and herdr state are discoverable by the successor
   directly; the handoff file adds what they cannot see.
6. Never fabricate session state. If you lack context, record that honestly.
7. Explicit invocation only — do not write a handoff file on your own
   initiative unless the user asks for it.