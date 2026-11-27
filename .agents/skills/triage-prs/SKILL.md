---
name: triage-prs
description: Triage the open Forgejo PRs of this repo (forgejo.mac-mini-m4-pro.internal/ccycle/dotfiles) — rebase each PR in its herdr worktree, push, wait for CI, and fast-forward merge it, one PR at a time; only a rebase conflict or red CI goes to the herdr agent in that worktree. Use when asked to "merge what can be merged and fix the rest" for this repo's PRs. Requires HERDR_ENV=1.
---

# Triage PRs

A PR is mergeable only when its head is on top of `origin/main` and its CI is green, because main allows fast-forward merges only and requires signed commits (see [mac-mini-m4-pro/darwin.nix](../../../modules/mac-mini-m4-pro/darwin.nix)).
Forgejo's `mergeable: true` ignores both.
Never use Forgejo's server-side rebase or "Update branch": they produce unsigned commits.

You do the clean path yourself with [triage.sh](scripts/triage.sh).
Only its failures go to the agent in the PR's worktree, which holds the PR's context.

## Steps

1. Run `triage.sh --all` in the background and wait for its exit notification.
   It snapshots the open PRs with [prs.sh](scripts/prs.sh); that list is the scope of the run.
   A PR that opens later is reported at the end, not processed, unless the user asks.
   [order.sh](scripts/order.sh) puts PRs that share no files with the others first and overlapping ones last, so that only one side has to resolve the conflict; `triage.sh` prints that order.
   It prints one line per PR.
   Read only those lines; open the log it names only to explain a failure.

2. For each line that says `delegate to <pane>`, prompt that agent (below), wait for it, then run `triage.sh <pr>` again for that PR alone.
   The agent finishing its turn does not mean CI passed; `triage.sh` checks CI and signatures itself.
   For a CI failure, find the cause with the [investigate-forgejo-ci skill](../investigate-forgejo-ci/SKILL.md) first and put it in the prompt.
   After two failed rounds on one PR, leave it and report it.

3. Report: PRs merged (number and head SHA), PRs left open with the reason, and PRs that appeared during the run.

## Delegating a failure

Use the pane from the `triage.sh` line as the target of `herdr agent` (see the [herdr skill](../../../modules/agents/skills/herdr/SKILL.md)); agents are not always named after their branch.
`triage.sh` skips a PR whose agent is `working` or `blocked`; come back to it later, or report it if it stays blocked.
If the worktree has no agent (`none` in `prs.sh`), run `herdr tab create --cwd <worktree> --label <branch>`, then `herdr agent start <branch> --kind claude --pane <root_pane>`.

Send the prompt with `herdr agent prompt <pane> "<prompt>" --wait --timeout 3600000 >/dev/null`.
Do not read the agent's screen; the next `triage.sh` run is the verdict.
Fill in this template:

```text
PR #<n> (<branch>) needs a fix before it can merge. origin/main is now <origin/main sha>.
<Rebase conflict in <files>, from <PR or commit that landed>. Rebase onto origin/main and resolve by <keeping both changes | ...>.>
<CI failed on <head>: <failing context and the error line>. Fix it.>
Bar: verify-change passes for <affected profile>; every commit is signed (git verify-commit); push with git push --force-with-lease.
Do not merge the PR. Reply with one line: the new head SHA.
```

## Related skills

- [forgejo-create-pr](../../../modules/agents/skills/forgejo-create-pr/SKILL.md): how a PR agent pushes and monitors its own CI.
- [verify-change](../verify-change/SKILL.md): the check named in the agent's bar.
