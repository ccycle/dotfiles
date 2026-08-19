---
name: push
description: Push current branch to origin
---

# Push

## Overview

Push the current branch to origin using `git-safe-push`, the scoped wrapper that
authenticates with the agent's fine-grained PAT instead of the human's credentials.
It always pushes the current branch to `origin` with `--set-upstream`; no other
arguments are accepted (see `modules/git/github/safe-push/drv.nix`).

## Workflow

1. **Pre-flight Check**
   - Run `git branch --show-current` to identify the current branch.
   - Run `git status` to confirm there are no unexpected uncommitted changes.

2. **Execute Push**
   - Run `git-safe-push`.
   - If it exits with an error, do not retry with raw `git push` — read the error
     message and act on it:
     - Refusing on `main`/`master`: this branch requires a human push via the
       device-flow credential helper. Stop and ask the user to push it themselves.
     - Non-HTTPS or non-`github.com` remote: this repo's remote is misconfigured
       for the wrapper. Stop and report it rather than working around it.
     - Token file not readable: the agent PAT is missing or expired. Point the
       user at the `safe-push-credentials` skill to rotate it.

3. **Result Report**
   - Display the output from the push command.
   - Confirm the branch was pushed successfully and show the remote URL.
