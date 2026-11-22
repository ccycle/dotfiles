---
name: interrogate
description: Adversarial multi-model review. Other agent CLIs (opencode, pi) and a Claude subagent each try to break a change or design in their own git worktree, and only findings a rerun reproduces survive. Reports findings; does not fix them. Use for "interrogate", "adversarial review", "multi-model review", "try to break this", "stress test this change", or "find blind spots".
---

# Interrogate

Adversaries try to break a change.
A finding survives only when its command, rerun by you, shows the failure.

## 1. Frame

- Scope: what the user names; otherwise the branch diff from its merge base with the default branch, working tree included.
- Intent: restate in a few sentences what the change is supposed to do, from the user's message, the commit messages, and the PR description.
  If the intent cannot be inferred, state the reading you chose in the report and proceed.

## 2. Pick the adversaries

One per available CLI, plus one Claude subagent:

| Adversary | Non-interactive form                                                               | Model listing      |
| --------- | ---------------------------------------------------------------------------------- | ------------------ |
| opencode  | `opencode run --dir <worktree> -m <provider/model> "<brief>"`                      | `opencode models`  |
| pi        | `cd <worktree> && pi -p --no-session --model <pattern> "<brief>"`                  | `pi --list-models` |
| Claude    | `Agent` with `subagent_type: "general-purpose"` and the worktree path in the brief | —                  |

Use the models the user named.
If none were named, pick a model from a different vendor than the session model for each CLI (from its listing), and name the choice in the report.
Skip a CLI that is not on `PATH`, and say so.

## 3. Isolate

Give each adversary its own worktree at `HEAD` with the uncommitted changes copied in:

```bash
git worktree add --detach "$scratch/interrogate-<name>" HEAD
git diff HEAD | git -C "$scratch/interrogate-<name>" apply
```

`$scratch` is the session scratchpad (or another directory outside the repo).
The CLIs may run with broad tool permissions, so after they finish, check `git status` in the main checkout and report any change they made outside their worktree.

## 4. Brief

Give every adversary the scope, the intent, the worktree path, and this brief verbatim:

> Read ~/.claude/CLAUDE.md and ~/.claude/rules/loop-engineering.md before anything else.
> Break this change.
> Work only inside the worktree path given.
> Prove each finding with a run against the real code: a failing test, a repro script, or command output that shows the wrong behavior.
> For a design or plan, build a minimal prototype or probe the current tree.
> Report each finding as: title, exact command, the output it printed, and the output the intent requires.
> Leave out anything you did not run, including style, naming, and risks that only matter after a future change.
> "No findings" is a valid result.

Run the CLIs in the background in parallel and wait for all of them.

## 5. Verify

Rerun each finding's command yourself in that adversary's worktree.
Keep it only if the output shows the failure and the failure breaks the intent.
Merge findings that share a root cause, and keep every verified finding regardless of which adversary found it.

## Report

- Intent: the restatement, and any assumption made.
- Findings: for each, the command, its output, how it breaks the intent, and which adversaries found it — or "no verified findings".
- Dropped: per adversary, how many findings were dropped and why.
- Adversaries: which CLIs and models ran, and which were skipped.
- Worktrees: the paths created. Removing them is a deletion, so list them and confirm before running `git worktree remove`.

## Sources

Adapted (rewritten, not copied) from the `interrogate` skill in [cursor/plugins pstack](https://github.com/cursor/plugins/tree/main/pstack) (MIT).
