---
name: merge-and-cleanup
description: Merge the current branch into main, create an Obsidian summary, and remove the worktree. A three-step end-of-task workflow.
allowed-tools: Bash, Read, Write
---

# Merge and Cleanup

End-of-task workflow that combines three steps into one: merge the
current feature branch into main (fast-forward only), write an Obsidian
result page, and remove the herdr worktree. Run from inside the worktree
whose task is complete.

## Prerequisites

```bash
test "${HERDR_ENV:-}" = "1"
```

If this fails, say you are not running inside Herdr and stop.

## Step 1 — Merge to Main

### 1.1 Pre-flight Check

Run `git branch --show-current` to identify the current branch. Record
it as `FEATURE_BRANCH`. If on `main` or `master`, warn the user and
abort — there is nothing to merge.

Run `git status` to check for uncommitted changes. If unstaged or staged
changes exist, run `git stash` to save them and record that a stash was
made.

### 1.2 Detect worktree layout

Run `git worktree list --porcelain` and look for an entry whose branch
is `refs/heads/main` (or `refs/heads/master`):

```bash
git worktree list --porcelain | awk '/^worktree/{p=$2} /^branch refs\/heads\/(main|master)$/{print p}'
```

If no such entry is found, use the **Plain flow** (step 1.3).
If found, record its path as `MAIN_WORKTREE` and use the **Worktree
flow** (step 1.4).

### 1.3 Plain flow

1. `git fetch origin`
2. `git checkout main` (fall back to `master`)
3. `git pull origin main`
4. `git checkout <FEATURE_BRANCH>`
5. `git rebase main` — if conflicts, follow Conflict resolution below
6. `git checkout main`
7. `git merge --ff-only <FEATURE_BRANCH>`
8. `git branch -d <FEATURE_BRANCH>`

### 1.4 Worktree flow

1. `git -C <MAIN_WORKTREE> status --porcelain` — abort if tracked files
   have local modifications
2. `git -C <MAIN_WORKTREE> pull origin main`
3. From current worktree: `git rebase main` — if conflicts, follow
   Conflict resolution below
4. `git -C <MAIN_WORKTREE> merge --ff-only <FEATURE_BRANCH>`
5. Skip `git branch -d` — cleanup removes the branch with the worktree

### Conflict resolution

If `git rebase main` reports conflicts:

1. Before resolving, understand main's changes: `git log -p -n 3 main -- <file>`
2. Preserve BOTH sides of the conflict
3. Read each conflicted file, resolve markers, `git add <file>`
4. `git rebase --continue`
5. If too complex, ask the user

### 1.5 Restore stash and report

If changes were stashed, run `git stash pop`. Show `git log --oneline -5`
on main and remind the user that main is ahead of origin.

---

## Step 2 — Summarize to Obsidian

### 2.1 Determine the task title

Confirm you are on `main` (you should be after the merge). Extract the
slug from the current directory:

```bash
pwd | sed 's|.*/\.herdr/worktrees/dotfiles/||'
```

Look up the title:

```bash
jq -r '.["'"$slug"'"].title' "$HOME/.local/state/obsidian-todo-dispatch/dispatched.json"
```

If the slug is not found, tell the user and skip this step — proceed to
Step 3.

### 2.2 Check AgentDrafts exists

```bash
test -d "$HOME/Obsidian/zettelkasten/AgentDrafts"
```

If it does not exist, skip the vault write — present the result as a
Markdown code block in chat instead.

### 2.3 Read conventions and extract changes

Read `.claude/skills/obsidian-manager/references/note-conventions.md`.
Then extract the change set:

```bash
git log --oneline origin/main..HEAD
git diff --stat origin/main..HEAD
git diff origin/main..HEAD
```

### 2.4 Write the result page

If `AgentDrafts/` exists, write
`$HOME/Obsidian/zettelkasten/AgentDrafts/<title>.md` following
note-conventions (bullet tree only, no headings, no frontmatter):

```markdown
- [[<title>]] への回答
  - 実装内容の要約
    - 変更ファイルと役割
  - 未解決・後続タスクがあればここに追記
```

Report the path and brief summary.

---

## Step 3 — Cleanup Worktree

### 3.1 Classify

Run the cleanup script from the repo root of the current worktree:

```bash
./scripts/cleanup-worktree.sh --dry-run
```

Interpret the output:

| Status                                         | Action        |
| ---------------------------------------------- | ------------- |
| `SAFE (started, merged to main, clean)`        | proceed       |
| `NOT MERGED` / `NEVER STARTED` / `IN PROGRESS` | stop, explain |
| `Refusing to remove` (main checkout)           | stop, explain |

### 3.2 Confirm and remove

If SAFE, ask the user:

```
This worktree (<branch>) is merged to main. Remove it? [y/N]
```

Only after an explicit yes:

```bash
./scripts/cleanup-worktree.sh --force
```

---

## Rules

- Only remove the worktree you are currently in — never another.
- Never use `--force` to override a non-SAFE classification.
- After removal the working directory no longer exists; make removal the
  last action.
- If any step fails, stop and report — do not skip to the next step.
