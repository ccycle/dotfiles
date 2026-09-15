---
name: forgejo-create-pr
description: Create a pull request on Forgejo with fj (forgejo-cli) and report the PR number
---

# Forgejo Create PR

## Overview

Create a pull request on the Forgejo instance with `fj` (the binary name of the `forgejo-cli` package) and report the resulting PR number. Unlike the `open-pr` skill (GitHub via `gh`), this skill creates the PR directly instead of opening a browser.

## Workflow

1. **Check Auth**
   - Run `fj auth list` to confirm a login for the target instance.
   - If no login exists, run `fj auth login` and ask the user to complete it (GUI/browser step).

2. **Gather Context**
   - Get the base branch (usually `main`).
   - Get the diff: `git diff <base>...HEAD --stat`.
   - Get commit messages: `git log <base>...HEAD --format="%s"`.

3. **Commit Uncommitted Changes**
   - Run `git status` to check for uncommitted changes.
   - If changes exist, commit them before proceeding (see the `smart-commit` skill for branching and message conventions).

4. **Push the Branch**
   - Run `git push -u origin HEAD` (or the remote pointing at Forgejo).

5. **Create the PR**
   - The title is a positional argument; there is no `--title` flag:
     ```bash
     fj pr create --base <base> --head <branch> "<title>" --body "<body>"
     ```
   - Title rule: write what was done or what problem was solved, not what
     was changed. Prefer `Stop failing scrapes against the disabled GitLab`
     over `Remove GitLab scrape jobs from Prometheus`.
   - Write the body with this template:

     ```markdown
     ## Summary

     [1-2 sentences: what this PR does and why]

     ## Changes

     - [Key change 1]
     - [Key change 2]

     ## Testing

     [How you verified it works]
     ```

   - Guidelines: lead with a concise summary, explain the "why" before the "how", keep commit messages in English.

6. **Report the Result**
   - Confirm the PR number from the `created pull request #N` output.
   - Display the title, base, and head.

7. **Monitor CI and Repair Failures**
   - Watch both CI jobs for this PR's head commit (`Verify / Syntax + Structure + Build` and `Formatter`) via `fj actions -R origin tasks`, matching the row whose commit prefix is the PR's head commit.
   - CI takes several minutes: use `ScheduleWakeup` to check back rather than a `sleep`-polling loop.
   - If a job fails, follow the `investigate-forgejo-ci` skill to fetch the log and classify the cause.
   - Fix only routine causes: formatter diffs (`nix fmt`), stale vendored hashes (`vendorHash` / `npmDepsHash` / `cargoHash`), and Package by Feature structure violations. Verify with the `verify-change` skill (at minimum the build output owning the failure) before pushing.
   - Push the fix to the same PR branch with a normal push (force-push is rejected on protected branches) and return to monitoring.
   - Attempt at most 3 repair pushes for one PR. If the cause is unclassifiable or CI is still red after 3 attempts, stop and hand over to the user (or queue a herdr worker), reporting the classification and the failing log excerpt.
