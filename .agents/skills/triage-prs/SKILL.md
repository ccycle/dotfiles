---
name: triage-prs
description: Triage the open Forgejo PRs of this repo (forgejo.mac-mini-m4-pro.internal/ccycle/dotfiles) — fast-forward merge every PR that is on top of main with green CI, and delegate the rebase or CI fix of each other PR to the herdr agent in that PR's worktree, one PR at a time. Use when asked to "merge what can be merged and fix the rest" for this repo's PRs. Requires HERDR_ENV=1.
---

# Triage PRs

You are the dispatcher.
You merge, and you verify what agents claim; you never run git (rebase, push, conflict resolution) inside a PR's worktree.
That work belongs to the agent already running in the worktree, which holds the PR's context.

A PR is mergeable only when its head is on top of `origin/main` and its CI is green, because main allows fast-forward merges only and requires signed commits (see [mac-mini-m4-pro/darwin.nix](../../../modules/mac-mini-m4-pro/darwin.nix)).
Forgejo's `mergeable: true` ignores both.
Never use Forgejo's server-side rebase or "Update branch": they produce unsigned commits.

## Steps

1. Snapshot the open PRs with [prs.sh](scripts/prs.sh).
   This list is the scope of the run.
   A PR that opens later is reported at the end, not processed, unless the user asks.

2. Order the list.
   PRs with `on_main=yes` and `ci=success` go first.
   Then small PRs that share no files with the others.
   PRs that touch the same files as another PR go last, so that only one side has to resolve the conflict.
   Compare with `git diff --name-only origin/main...<head>`.

3. Take the PRs strictly one at a time, because every merge moves main and invalidates the rest:
   1. Run [prs.sh](scripts/prs.sh) again for the current state.
   2. If `on_main=yes` and `ci=success`, merge with [merge.sh](scripts/merge.sh) and go to the next PR.
      It refuses an already merged PR, so a merge the user did by hand mid-run is safe.
   3. Otherwise delegate (below), then verify the agent's claims yourself: `prs.sh` shows `on_main=yes`, `git verify-commit <head>` passes, and [ci-state.sh](scripts/ci-state.sh) `<head> --wait 1800` prints `success`.
      The agent finishing its turn does not mean CI passed.
   4. Merge with `merge.sh`.
      If CI is red, look at the failure with the [investigate-forgejo-ci skill](../investigate-forgejo-ci/SKILL.md) and send the agent one more prompt with the cause.
      After two red rounds on one PR, leave it and report it.

4. Report: PRs merged (number and head SHA), PRs left open with the reason, and PRs that appeared during the run.

## Delegating to the worktree agent

Use the `agent_pane` column of `prs.sh` as the target of `herdr agent` (see the [herdr skill](../../../modules/agents/skills/herdr/SKILL.md)); agents are not always named after their branch.

- `idle` or `done`: send the prompt.
- `working`: the agent is busy with something else; do not interrupt it.
  Move on to the next PR and come back.
- `blocked`: it is waiting for the user; skip the PR and report it.
- `none` (worktree without an agent): `herdr tab create --cwd <worktree> --label <branch>`, then `herdr agent start <branch> --kind claude --pane <root_pane>` and send the prompt.
- `no-worktree`: the PR was not made from a herdr worktree; skip it and report it.
  Do not create a worktree for it.

Send the prompt with `herdr agent prompt <pane> "<prompt>" --wait --timeout 3600000`.
Fill in this template:

```text
Rebase this PR branch (<branch>, PR #<n>) onto origin/main, which is now <origin/main sha>.
<For a CI failure: CI failed on <head>: <failing context and the error line>. Fix it.>
<Expected conflicts: <files>, from <PR or commit that landed>. Resolve by <keeping both changes | ...>.>
Bar: verify-change passes for <affected profile>; every commit is signed (git verify-commit); push with git push --force-with-lease; wait for CI on the new head.
Report the new head SHA and the CI result for each context.
Do not merge the PR.
```

## Related skills

- [forgejo-create-pr](../../../modules/agents/skills/forgejo-create-pr/SKILL.md): how a PR agent pushes and monitors its own CI.
- [verify-change](../verify-change/SKILL.md): the check named in the agent's bar.
