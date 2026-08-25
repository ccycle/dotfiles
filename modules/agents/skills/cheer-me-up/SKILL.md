---
name: cheer-me-up
description: Present the concrete next step for an in-progress task and encourage taking it. Invoke explicitly (`/cheer-me-up`) when the user wants to know what to do next and a push to keep going.
disable-model-invocation: true
---

# Cheer Me Up

## The Two-Factor Model

Motivation for a task depends on two independent things being present:

- **Purpose**: the person believes in why the task matters (what it connects
  to, what improves once it's done).
- **Method**: the path to doing it is visible.

Losing either one kills motivation, even if the other is fully present. "Too
hard" and "don't know how to proceed" are both missing-method symptoms. "I
know how but it feels tedious" is a missing-purpose symptom. Treat the
underlying axis, not the surface phrasing — do not invent a third category.

## Step 1: Identify the Stalled Task

Use the current conversation and `TaskList`/`TaskGet` state to find the task
in question. If it isn't obvious, ask the user directly rather than guessing.

## Step 2: Diagnose the Missing Axis

Ask, or infer from how the user describes the stall:

- Is the _method_ unclear (don't know how, or it looks too hard to pull off)?
- Is the _purpose_ unclear (the method is known, but it feels pointless or
  not worth the effort)?

## Step 3a: Method Is Unclear

- Apply the `reasoning` skill's decomposition principle (Decompose by
  Verifiability) to find the smallest next step that is concretely
  achievable.
- If it still feels too hard after decomposing, do not force further
  breakdown through sheer effort. Look for a shortcut instead: a different,
  easier way to reach the same outcome, or a way to solve this together with
  another pending problem.
- If no shortcut surfaces, it is legitimate to let the task rest and revisit
  it later rather than grinding on it now. Say so explicitly as a valid
  option, not a failure.

## Step 3b: Purpose Is Unclear

- If the task already exists as a note in `~/Obsidian/zettelkasten`, check
  its backlinks read-only, e.g. `grep -rl '\[\[<task title>\]\]'
~/Obsidian/zettelkasten`. Many connections to other notes indicate real
  significance; near-isolation is a sign the task's importance was never
  established. Skip this check entirely when no corresponding note exists —
  do not create one.
- Ask what concretely improves once the task is done, and what happens if
  it's skipped. Have the user state the answer themselves; do not write the
  self-persuasion for them.
- Do not anchor persuasion in morale, pride, guilt, or money ("others are
  watching", "it'll pay off eventually") — these frames erode judgment over
  time. Anchor it in the genuine, specific consequence or payoff.
- If, after this, the task still doesn't feel worth doing, that is a valid
  outcome. Name it as something to defer or drop rather than forcing it
  through.

## Never

- Invent a third diagnostic category beyond purpose/method.
- Write vault files. Backlink checks in Step 3b are read-only.
- Supply the user's self-persuasion for them — the point is that they
  articulate it, not that the answer exists.
