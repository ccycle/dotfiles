---
name: push
description: Push current branch to origin
---

# Push

## Overview

Push the current branch to origin using `git push origin HEAD`.

## Workflow

1. **Pre-flight Check**
   - Run `git branch --show-current` to identify the current branch.
   - Run `git status` to confirm there are no unexpected uncommitted changes.

2. **Execute Push**
   - Run `git push origin HEAD`.
   - If the push fails because the remote branch does not exist yet, re-run with `--set-upstream` (`git push --set-upstream origin HEAD`) to create the tracking branch.

3. **Result Report**
   - Display the output from the push command.
   - Confirm the branch was pushed successfully and show the remote URL.
