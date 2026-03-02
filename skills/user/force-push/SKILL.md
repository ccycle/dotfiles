---
name: force-push
description: Force push current branch to origin with --force-with-lease
---

# Force Push

## Overview

Force push the current branch to origin using `git push origin HEAD --force-with-lease`.
`--force-with-lease` ensures the push is rejected if the remote has been updated by someone else since your last fetch, preventing accidental overwrites.

## Workflow

1. **Pre-flight Check**
   - Run `git branch --show-current` to identify the current branch.
   - If on `main` or `master`, warn the user and ask for explicit confirmation before proceeding — force-pushing these branches is dangerous.
   - Run `git status` to confirm the working tree state.

2. **Execute Force Push**
   - Run `git push origin HEAD --force-with-lease`.
   - If the push is rejected because the remote has new commits (lease violation), inform the user and do NOT retry automatically. The user must fetch and review the remote changes before deciding how to proceed.

3. **Result Report**
   - Display the output from the push command.
   - Confirm the branch was force-pushed successfully and show the remote URL.
