---
name: correct
description: Find mistakes agents keep repeating in this dotfiles repo and make each one impossible instead of documenting it — module structure first, then Nix option types and assertions, then a verify-change check whose error names the fix, then a test, and prose rules last. Proves each new check fails on a real past mistake. Use for /correct, "stop making this mistake", or when the same correction has been given twice.
---

# Correct

Assume every contributor is an agent that sees only the files it opened, copies the nearest example, and takes the shortest path that evaluates.
Change the repo so a change that looks right from one file is right for the whole repo.
A prose rule is the symptom; nothing fails when an agent skips it.

## 1. Find the mistake classes

Read, in this order:

- The project's auto-memory `feedback_*.md` files (each one is a correction the user already gave).
- Recent reverts and fix-up commits: `git log --oneline -200 | grep -Ei 'revert|fix|again|forgot'`.
- Review comments on recent Forgejo PRs (`fj` — see the forgejo-create-pr skill for the CLI).
- Rules in [CLAUDE.md](../../../CLAUDE.md) and [modules/agents/rules/](../../../modules/agents/rules/) that nothing enforces.

Group the mistakes into classes.
A class counts once it has happened twice; cite both occurrences.

## 2. Pick the highest level that works

1. Structure.
   Give each piece of state one owner and each task one supported way; delete the old way an agent would copy.
   In this repo that usually means the module tree itself (a child directory is a dependency) or a single option that replaces hand-synced values.
2. Nix types and assertions.
   A `lib.types.enum` / `strMatching` / submodule type, an option without a default, or an `assertions = [ { assertion = …; message = …; } ]` entry makes the bad value fail evaluation, and therefore every profile build.
3. A verify-change check.
   Extend an existing checker ([rules.nix](../verify-change/scripts/package-by-feature/rules.nix), [check-md-links.sh](../verify-change/scripts/check-md-links.sh)) before adding a new script, and wire any new script into [check.sh](../verify-change/scripts/check.sh).
   The error message must name the file, option, or command to use instead.
   If the bad pattern is already common, fail only on additions.
4. A test under `modules/<feature>/tests/`, when the mistake is behavioral and only a running service shows it.
5. Prose in CLAUDE.md or a skill, only for judgment calls no check can decide.

For each class, say why each higher level did not work.

## 3. Fix and prove

Proceed without asking; the user reviews the commits afterwards.
One commit per class:

- Implement the check.
- Prove it fails on a real past mistake: re-apply the offending change (or check out its commit) in a scratch worktree and show the check's failing output.
- Prove it passes on the current tree.
- Carry the reason in the check's error message, not in a comment and not in a parallel "rule → enforcer" table, so the fact lives in exactly one place.
- Once a check enforces a prose rule, delete the prose rule and the memory entry it came from in the same commit.

## Report

Each class with its evidence, the level picked and why higher levels did not work, the failing-then-passing output of each new check, and the prose rules and memory entries deleted.

## Sources

Adapted (rewritten, not copied) from the `correct` skill and the `encode-lessons-in-structure` principle in [cursor/plugins pstack](https://github.com/cursor/plugins/tree/main/pstack) (MIT).
