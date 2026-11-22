---
name: no-comments
description: Strip code comments from a diff and encode what each one claimed — as a name, type, assertion, check, or test — so the constraint is enforced instead of written down. Keeps only comments about things the code cannot change, with a link to the external source. Use before committing or opening a PR, for /no-comments, or when asked to remove or audit comments.
---

# No Comments

A comment is a claim nothing enforces.
It drifts silently when the code changes, and an agent copies it as if it were still true.
Delete it, and move whatever it claimed into something that fails.

## Scope

The files or diff the caller names.
Otherwise every comment added or changed in the current branch diff against its merge base with the default branch, working tree included.
Pre-existing comments outside the diff are out of scope unless the caller asks for the whole file or repo.

## Classify each comment

- Restates the code ("increment the counter", a section banner, a commented-out block): delete.
- Explains a name the code could carry itself: rename the symbol, then delete.
- Claims a constraint inside our control ("must be called before X", "keep in sync with Y", "do not remove", "only enabled on host Z"): encode it, then delete.
  Pick the cheapest encoding that fails loudly when the constraint breaks:
  1. Structure: one source of truth instead of two values kept in sync; a parameter instead of a hidden ordering.
  2. Type: a narrower type, an enum, an option with no default.
  3. Assertion: a runtime or evaluation-time check whose message names the fix (`assertions` in Nix, `set -u` / explicit guards in shell).
  4. Lint or repo check whose error names the fix.
  5. A test that fails when the behavior breaks.
- Explains design intent no single location can carry: move it to the nearest `design.md` (see the `design-doc` skill), then delete.
- Documents something this code cannot change (an upstream bug, a vendor requirement, an external format quirk, a tool directive such as `# shellcheck disable=` or a license header): keep it, and make sure it links to the external source.
  A keep with no external source is a constraint in disguise; encode or delete it.

When the right encoding is out of the task's scope, delete the comment anyway and list the unencoded constraint as open work in the report.
Never restore a deleted comment as a fallback.

## Steps

1. Collect the comments in scope (`git diff -U0 <base>` and filter added comment lines by the file's comment syntax).
2. Classify each one as above.
3. Apply the deletions, renames, and encodings.
4. Prove each encoding: break the constraint on purpose once and show the check failing, then show it passing on the real change.
5. Run the project's normal verification.

## Report

Counts of deleted, renamed, encoded, moved-to-design.md, and kept comments; for each encoding, the failing-then-passing output; for each keep, its external link; and every constraint left unencoded.

## Sources

Adapted (rewritten, not copied) from the `no-comments` skill and Comment Sicko agent in [cursor/plugins pstack](https://github.com/cursor/plugins/tree/main/pstack) (MIT).
