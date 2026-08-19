---
name: summarize-to-obsidian
description: Create a result page in the Obsidian vault's AgentDrafts/ summarizing what was implemented for a task, derived from the git diff, with a link back to the source task. Call after merge-to-main and before cleanup-worktrees, from inside the worktree of the merged branch.
allowed-tools: Bash, Read, Write
---

# Summarize to Obsidian

Create a durable result page for a task whose implementation was just merged.
Called inside a herdr worktree after `merge-to-main` and before
`cleanup-worktrees` — the worktree still exists and main contains the merged
work, but the feature branch has already been deleted.

The source TODO note title is determined automatically from the worktree's
branch slug via `dispatched.json`. No input is required.

## Prerequisites

```bash
test "${HERDR_ENV:-}" = "1"
```

If this fails, say you are not running inside Herdr and stop.

## Step 1 — Determine the task title

1. Confirm you are on `main`:

   ```bash
   git branch --show-current
   ```

   If not on `main`, stop — this skill assumes the merge has already completed.

2. Extract the slug from the current directory:

   ```bash
   pwd | sed 's|.*/\.herdr/worktrees/dotfiles/||'
   ```

   This yields the branch slug (e.g. `per-machine-age-key`).

3. Look up the title in the dispatch state:

   ```bash
   jq -r '.["'"$slug"'"].title' "$HOME/.local/state/obsidian-todo-dispatch/dispatched.json"
   ```

   If the slug is not found, tell the user and stop — the task was not
   dispatched via `obsidian-to-herdr-worktree`.

## Step 2 — Verify context and conventions

1. Read note conventions (must follow them for the result page):

   ```bash
   .claude/skills/obsidian-manager/references/note-conventions.md
   ```

2. Check `AgentDrafts/` exists:

   ```bash
   test -d "$HOME/Obsidian/zettelkasten/AgentDrafts"
   ```

   If it does not exist, do not create it — present the result page as a
   Markdown code block in chat instead (trust boundary per obsidian-manager).

## Step 3 — Read the source note

```bash
cat "$HOME/Obsidian/zettelkasten/<title>.md"
```

If the file does not exist, proceed anyway — the result page will contain a
dangling `[[<title>]]` link, which is intentional by vault convention.

## Step 4 — Extract the change set

Since `merge-to-main` has not pushed yet (push is left to the user), the
commits unique to this task live on `origin/main..HEAD`.

```bash
git log --oneline origin/main..HEAD
git diff --stat origin/main..HEAD
git diff origin/main..HEAD
```

Read the diff to understand:
- What was implemented (functionality, not just file edits)
- Key decisions visible in the code
- Files that carry the bulk of the logic

If `origin/main..HEAD` returns empty (already pushed), fall back to the
recent history and tell the user to confirm which commits to include:

```bash
git log --oneline -10
git diff --stat HEAD~5..HEAD
```

## Step 5 — Draft the result page

Write `$HOME/Obsidian/zettelkasten/AgentDrafts/<title>.md` following
note-conventions exactly (bullet tree only, no headings, no frontmatter):

```markdown
- [[<title>]] への回答
	- 実装内容の要約（何をしたか、なぜその設計か）
		- 変更ファイルと役割
	- 未解決・後続タスクがあればここに追記
```

- Line 1 is always the wikilink to the source task.
- Nested bullets carry evidence: which files changed, what the diff reveals.
- Open questions or known limitations go as trailing bullets.
- Language: Japanese prose, English code/commands inline.

## Step 6 — Write and report

If `AgentDrafts/` exists:

```bash
# write the file (path: $HOME/Obsidian/zettelkasten/AgentDrafts/<title>.md)
```

Then tell the user:
- The path to the result page (`AgentDrafts/<title>.md`)
- A brief summary of what it contains
- Remind them to push main and then run `/cleanup-worktrees`

If `AgentDrafts/` does not exist, output the result page as a code block in
chat instead, and tell the user to create `AgentDrafts/` manually if they
want vault writes going forward.

## Rules

1. Never edit any vault note other than `AgentDrafts/<title>.md` — never touch
   source code or other vault files.
2. Only write when `AgentDrafts/` already exists — never create it yourself.
3. The result page is a durable artifact; the chat copy exists only for the
   immediate handoff. Do not read back or merge the file after writing.
4. The link direction is one-way: `AgentDrafts` → source task only. Do not
   modify the source task note.
