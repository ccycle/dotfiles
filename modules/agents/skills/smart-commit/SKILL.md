---
name: smart-commit
description: Smart Commit & Branching
---

# Smart Commit & Branching

## Overview

Analyze the current work, create an appropriate branch, and commit only the relevant changes.

## Workflow

1. **Analyze Changes**
   - Gather everything in ONE command (each extra tool call re-reads the whole conversation context, which dominates token cost):
     `git status --short; git branch --show-current; git diff --stat; git diff --stat --cached`
   - Then read diffs with one more command. If the `--stat` total is small, run `git diff; git diff --cached`. If it is large, diff only the files whose purpose is unclear from their names (`git diff -- <paths>`).
   - Do not run further investigation commands unless the diff is genuinely ambiguous.
   - Categorize changes by purpose (feature, bugfix, refactor, etc.).
   - **Identify which files are related to the current task** and which are unrelated.

2. **Determine Branch Strategy**
   - Check the current branch.
   - **If on `main` or `master`**:
     - Create a new branch based on the change type.
     - Naming convention: `category/description-kebab-case`
       - `feature/`: New functionality
       - `fix/`: Bug fixes
       - `refactor/`: Code refactoring
       - `chore/`: Maintenance tasks
       - `docs/`: Documentation updates
     - Examples: `feature/user-auth-api`, `fix/memory-leak-in-crawler`
   - **If already on a feature branch**:
     - Continue using the current branch if changes align with its purpose.
     - Consider a new branch only if changes are unrelated to the branch's scope.

3. **Select Files to Stage**
   - **Keep commit granularity minimal (Atomic Commits).**
     - Each commit must represent a single, indivisible logical change.
     - **Apply the "AND" Rule**: If a potential commit message would need "and" to describe different actions (e.g., "simplify script AND add shell hook"), **YOU MUST SPLIT IT**.
     - **Separate Concerns**:
       - **Refactor vs Feature**: NEVER mix code cleanup/refactoring with new features or behavior changes.
       - **Config vs Logic**: Separate environment/build config changes (e.g., nix, envrc) from application logic changes unless strictly coupled.
     - **Revert Test**: Ask "If I revert this commit later, will I lose unrelated useful changes?" If yes, split it.
     - If the workspace contains multiple logical changes, **split them into separate commits**.
   - **Only stage files directly related to the current task.**
   - Exclude unrelated changes (e.g., unintended formatting, unrelated fixes).
   - If unrelated changes exist, handle them in a separate commit (do not ignore them, but commit them separately).

4. **Compose Commit Message**
   - Follow **Conventional Commits** format: `type(scope): subject`
   - Keep the subject concise and descriptive.
   - Use English for commit messages.
   - **Do NOT add a `Co-Authored-By` trailer** or any AI attribution to the commit message.

5. **Execute Immediately**
   - Run everything in ONE command chained with `&&`, without waiting for approval:
     `git switch -c <branch> && git add <files A> && git commit -m "<msg A>" && git add <files B> && git commit -m "<msg B>" && git log --oneline -<N>`
     - Omit `git switch -c` when staying on the current branch.
     - The trailing `git log` replaces a separate verification call.
   - **Report the result**:
     - Confirm the branch used/created.
     - List the files that were committed in each step.
     - Display the final commit messages.
