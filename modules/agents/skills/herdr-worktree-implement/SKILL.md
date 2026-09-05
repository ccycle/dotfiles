---
name: herdr-worktree-implement
description: Turn *this* pane's own concluded design discussion (typically the plan-only `grilling` session a worker started after `obsidian-to-herdr-worktree` dispatched it) into an implementation. Invoke from inside the pane that held the discussion, once shared understanding has been reached — the invoking agent already holds the whole discussion in its own context, so nothing is read from outside. It first judges its own conversation for readiness (refuses and keeps discussing if grilling is still open), then writes the concluded design as a self-contained handoff prompt and starts a brand-new `claude` agent in a new tab of the same Herdr workspace — the current git worktree, never a new one, and never this session. Requires HERDR_ENV=1.
disable-model-invocation: true
allowed-tools: Bash
---

# Herdr Worktree Implement

Turn this pane's own concluded design discussion into an implementation,
carried out by a fresh agent in a new tab of the same worktree.

This is the natural next step after a plan-only discussion (e.g. one
dispatched by `obsidian-to-herdr-worktree`) reaches shared understanding: run
it from inside that same pane. It never creates a new worktree — the current
pane's git worktree is the target — and it never reuses the current session
to write code: a new agent always does the implementing, so the back-and-forth
of the discussion never ends up in the diff-producing session's context.

Optional focus/emphasis for the handoff: $ARGUMENTS

## Prerequisite

```bash
test "${HERDR_ENV:-}" = "1"
```

If this fails, say you are not running inside Herdr and stop.

## You must be the agent that had the discussion

This skill only makes sense invoked from inside the pane whose own
conversation holds the design discussion to hand off. It does not read
another pane's transcript and does not take a worktree name or note title as
a target — the target is always "here," this pane's own worktree.

## Step 1 — Judge readiness yourself

Before doing anything else, look back over this conversation's own history:

- Has the discussion reached a concluded design — a plan with no open
  questions, or a `grilling` session whose frontier is empty?
- If not: say so plainly (name what's still open) and stop here. Do not
  create a tab or start an agent. Keep discussing instead.
- If yes: continue to Step 2.

Do not ask the user to confirm this judgment. You hold the full context an
outside check would only be able to guess at from a transcript excerpt.

## Step 2 — Write the handoff prompt

The new agent (Step 3) starts with none of this conversation's context, so
write the concluded design out as a self-contained prompt: what to implement,
the decisions made and why, any rejected alternatives worth remembering, and
the specific files/modules involved if known. If `$ARGUMENTS` narrows the
scope, fold that in too.

```bash
tmpfile=$(mktemp).md
cat > "$tmpfile" << 'EOF'
<concluded design: what to build, decisions and why, rejected alternatives,
target files/modules>
EOF
```

Use relative paths only inside the prompt — the new tab happens to run in the
same worktree, but write it so it would still be correct if that changed.

## Step 3 — Start the implementation agent in a new tab

Same workspace, same worktree — a new tab, not a new worktree:

```bash
result=$(herdr tab create --workspace "$HERDR_WORKSPACE_ID" --cwd "$PWD" --no-focus)
pane_id=$(echo "$result" | jq -r '.result.root_pane.pane_id')

herdr agent start implement --kind claude --pane "$pane_id"
herdr agent prompt implement "$(cat "$tmpfile")" --timeout 600000
```

Do not pass `--wait` — this skill's job ends once the prompt is sent. If
`herdr agent start` reports the name is already taken (a prior implementation
attempt in this worktree), pick a fresh unique name (e.g. `implement2`).

## Step 4 — Report and stop

Tell the user, in this pane, that implementation has started in a new tab and
that this pane's job is done — nothing further is needed here. Do not attach
to the new tab, do not wait for it, and do not touch source files yourself in
this session.

## Rules

1. Never implement code in this pane's own session — Step 3 always spawns a
   separate agent for that, regardless of what backend ran the discussion
   (opencode, pi, or claude).
2. Never treat "the skill was invoked" as proof of readiness by itself —
   Step 1's judgment call is still required and can still say no.
3. Never target another pane's discussion or another worktree. This skill
   only acts on its own conversation and its own worktree.
4. Never create a new worktree — implementation happens in the same git
   worktree the discussion already lives in.
