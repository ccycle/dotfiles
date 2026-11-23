---
name: from-herdr-memo
description: Read the herdr scratch memo (`~/Obsidian/zettelkasten/herdr-memo.md`, opened with prefix+m), match each line against the live Herdr workspaces and agents, and decide the next action per item — hand it to the agent already working on that topic, or start it in a new worktree via the `herdr-worktree` flow. Shows the plan, asks once, then dispatches. Invoke explicitly (`/from-herdr-memo`). Requires HERDR_ENV=1.
disable-model-invocation: true
allowed-tools: Bash, Read, Write
---

# From Herdr Memo

Turn the memo into work: every memo line ends up either with an existing agent or in a new worktree.

Optional focus (e.g. only some memo lines, `--kind`/`--model` for new worktrees): $ARGUMENTS

## You are a dispatcher, not an implementer

Do not read or search the codebase, and do not work on any memo item yourself.
Your inputs are the memo, `herdr workspace list`, `herdr agent list`, `herdr worktree list`, and short `herdr agent read` snapshots.

## Step 1 — Prerequisite

```bash
test "${HERDR_ENV:-}" = "1"
```

If this fails, say you are not running inside Herdr and stop.

## Step 2 — Read the memo and the Herdr state

```bash
cat "$HOME/Obsidian/zettelkasten/herdr-memo.md"
herdr workspace list
herdr agent list
herdr worktree list
```

Each non-empty memo line is one item.
Restrict workspaces and agents to the current repo: match `worktree.repo_root` against `git rev-parse --show-toplevel` of the main checkout.

For each repo workspace, build a one-line picture: label, branch, `agent_status`, and each agent's `terminal_title_stripped` and `pane_id`.
When the label and title do not tell you what an agent is doing, read a short snapshot:

```bash
herdr agent read <pane_id> --source recent-unwrapped --lines 40
```

Exclude your own pane (`$HERDR_PANE_ID`).

## Step 3 — Classify each memo item

Pick exactly one action per item:

| Action    | When                                                                                                           |
| --------- | -------------------------------------------------------------------------------------------------------------- |
| `prompt`  | An existing workspace/agent already works on this topic, and its agent is `idle` or `done`.                    |
| `new`     | No workspace covers the topic.                                                                                 |
| `busy`    | The matching agent is `working` — do not interrupt it; report only.                                            |
| `blocked` | The matching agent is `blocked` — it is waiting on the user; report only.                                      |
| `done`    | The matching worktree's branch is merged to main (`git branch --merged main`); suggest deleting the memo line. |
| `unclear` | The line is too vague to write a self-contained prompt for.                                                    |

Match by meaning, not by string: memo lines are terse Japanese, labels and branches are English slugs.
When an item could fit two workspaces, pick the one whose agent's recent output is closest, and say why in the plan.

## Step 4 — Show the plan and ask once

Print a table: memo line, action, target (workspace label + `pane_id`, or the proposed new branch slug), and one line of reasoning.
Then ask with the interactive question tool: dispatch everything / dispatch only `prompt` items / dispatch only `new` items / cancel.
For `unclear` items, ask what they mean in the same question round instead of guessing.

## Step 5 — Dispatch

Every prompt you send starts with these lines (non-Claude agents may not load the rule files on their own):

```
Read ~/.claude/CLAUDE.md and ~/.claude/rules/loop-engineering.md before anything else.
Bar: <the checks this work must pass, e.g. "verify-change for the affected profile">
```

For `prompt` items, send the memo item as a follow-up to the existing agent, without `--wait`:

```bash
herdr agent prompt <pane_id> "$(cat <<'EOF'
Read ~/.claude/CLAUDE.md and ~/.claude/rules/loop-engineering.md before anything else.
Bar: <bar>

New request from the user's herdr memo, related to what you are working on:
<memo line, plus any context the user gave in Step 4>
EOF
)"
```

For `new` items, read `~/.claude/skills/herdr-worktree/SKILL.md` and follow its Workflow and "herdr backend" sections directly (it is user-invoked only, so do not call it through the Skill tool).
Write all prompt files first, then create all worktrees and start all agents.
Pass `--kind`/`--model` from `$ARGUMENTS` through as that skill describes.

Do not wait for any agent to finish.

## Step 6 — Report and stop

List what was sent where (pane ID or new branch), the `busy`/`blocked` items the user should look at, and the `done` items whose memo lines can be deleted.
Do not edit the memo: it is the user's scratchpad, and an item that now has a workspace maps to `prompt`/`busy` on the next run anyway.
