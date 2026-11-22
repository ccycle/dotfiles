---
name: why
description: Explain why code, config, or a decision is the way it is, from the record rather than the code — the commits and PR discussions that introduced it and each later change, plus design.md files. Cites commits and PRs, marks inferences as inferences, and says what the record does not answer. Use for "why is X like this", "why did we pick Y", regressions, and design rationale. For what the code does at runtime, read the code instead.
---

# Why

The code shows what; the record shows why.
Answer from what the authors wrote at the time.

## Steps

1. Pin the target to concrete lines, options, or files.
2. Find every change that introduced or altered it:
   - `git log -L <start>,<end>:<file>` for a line range, or `git log -L :<symbol>:<file>` for a function.
   - `git log -S '<string>' --all` (or `-G '<regex>'`) when it moved between files.
   - `git log --follow -- <file>` for the whole file, and `git blame -w -C -C` to see through moves and reformatting.
3. Read each commit's full message, not only the subject.
4. Find the PR for each commit and read its description and review discussion with the forge CLI that matches `git remote -v`: `gh` for GitHub, `fj` for Forgejo, `glab` for GitLab.
5. Read any `design.md` next to the target and any issue the commits or PRs link.
6. If the trail is thin, widen to neighbouring commits from the same PR or day, then to external sources the commits cite.

## Report

- Answer first, in a few sentences.
- Then the trail: each change in order with its commit SHA or PR number and a short quote of what its author said.
- Mark every statement not directly quoted from the record as an inference.
- End with what the record does not answer.

## Sources

Adapted (rewritten, not copied) from the `why` skill in [cursor/plugins pstack](https://github.com/cursor/plugins/tree/main/pstack) (MIT).
