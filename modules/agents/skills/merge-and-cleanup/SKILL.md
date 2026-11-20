---
name: merge-and-cleanup
description: Open a Forgejo PR for the current herdr worktree branch, write its Obsidian result page, and remove the worktree once the PR is merged. Runs only when the user types /merge-and-cleanup.
disable-model-invocation: true
allowed-tools: Bash
---

# Merge and Cleanup

Use only inside a herdr worktree whose task is committed.

Run [scripts/merge-and-cleanup.sh](scripts/merge-and-cleanup.sh) from this skill's directory with no arguments, and relay its output.
Its `--help` describes what each PR state does.

Pass `--remove` only after the script reported `SAFE` and the user confirmed removal in this conversation.
Never merge the PR yourself, and never retry a failed run with different flags; report the error instead.
