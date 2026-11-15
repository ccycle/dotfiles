---
name: merge-and-cleanup
description: Open a Forgejo PR for the current branch, create an Obsidian summary, and remove the worktree after the PR is merged. An end-of-task workflow.
allowed-tools: Bash, Read, Write
---

# Merge and Cleanup

End-of-task workflow that opens a Forgejo PR for the current feature
branch, writes an Obsidian result page, and removes the herdr worktree
once the PR has been merged. Run from inside the worktree whose task is
complete.

Integration happens through Forgejo PRs, not a local fast-forward merge.
Never merge the branch into local `main` yourself.

## Prerequisites

```bash
test "${HERDR_ENV:-}" = "1"
```

If this fails, say you are not running inside Herdr and stop.

## Step 1 — Open a Forgejo PR

### 1.1 Pre-flight Check

Run `git branch --show-current` to identify the current branch. Record
it as `FEATURE_BRANCH`. If on `main` or `master`, warn the user and
abort — there is nothing to open a PR for.

Do not touch local `main` and do not run `git merge`. The PR is merged on
Forgejo, not in this checkout.

### 1.2 Create the PR

Follow the `forgejo-create-pr` skill (push the branch, then
`fj pr create`). Record the resulting PR number as `PR_NUMBER`.

---

## Step 2 — Summarize to Obsidian

### 2.1 Determine the task title

Confirm you are on `FEATURE_BRANCH`, not `main`. Extract the slug from
the current directory:

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

## Step 3 — Cleanup Worktree (after the PR is merged)

Check whether the PR is merged:

```bash
fj pr -R origin status <PR_NUMBER>
```

If it is still open, stop here and tell the user: merge the PR on
Forgejo, then run `/cleanup-worktrees` from this worktree. If it is
merged, continue.

### 3.0 Update local main

The cleanup script compares the branch against local `main`, which a
Forgejo merge does not update. Update it before classifying:

```bash
git fetch origin
git worktree list --porcelain | awk '/^worktree/{p=$2} /^branch refs\/heads\/(main|master)$/{print p}'
```

- If that prints a path (`MAIN_WORKTREE`): `git -C <MAIN_WORKTREE> pull --ff-only origin main`
- If it prints nothing: `git fetch origin main:main`

### 3.1 Classify

Run the cleanup script that ships with the `cleanup-worktrees` skill
(`modules/agents/skills/cleanup-worktrees/scripts/cleanup-worktree.sh` in the
dotfiles repo, `~/.claude/skills/cleanup-worktrees/scripts/cleanup-worktree.sh`
when deployed):

```bash
scripts/cleanup-worktree.sh --dry-run
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
scripts/cleanup-worktree.sh --force
```

---

## Rules

- Never merge the PR yourself — the user merges it on Forgejo.
- Only remove the worktree you are currently in — never another.
- Never use `--force` to override a non-SAFE classification.
- After removal the working directory no longer exists; make removal the
  last action.
- If any step fails, stop and report — do not skip to the next step.
