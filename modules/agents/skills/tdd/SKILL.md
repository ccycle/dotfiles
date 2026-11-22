---
name: tdd
description: Fix a bug test-first when there is a cheap local test path — a regression test that fails before the fix and passes after — and judge every test written, changed, or kept by whether it asserts observable behavior rather than implementation. Use for /tdd, "write a failing test first", "add a regression test", or when writing or reviewing tests.
---

# TDD

## When to use test-first

Use it when the bug has a clear, cheap local test path.
Skip it when the only test would need broad harness setup, brittle stubs, production-only state, or large fixture churn; use the closest real verification instead and say so.
Prefer an integration test against a real service with dummy fixtures over a stub.

## Steps

1. State the intended behavior, the current behavior, and the smallest reproduction.
2. Pick the narrowest existing test layer for that code path; do not build a new harness just to satisfy this workflow.
3. Write the smallest test that would have caught the bug, with the expected value derived from the requirement, not from the code under test.
4. Run it and confirm it fails for the intended reason.
   If it passes, or fails for another reason, fix the test before touching the code.
5. Make the smallest fix.
6. Rerun the test and the surrounding suite.

## Judging a test

A test is a claim about what users of the code can observe through its interface: return values, errors, readable state, and effects on outside systems.
Judge it against two imagined edits:

- Break the behavior (wrong value, skipped or doubled effect).
  If the test still passes, it proves nothing.
  Usual causes: a loose assertion, an expected value computed by the code under test, or an assertion on data the test built itself.
- Change only the internals and keep every observable result.
  If the test fails, it is pinned to the implementation.

Keep a test that catches the first edit and survives the second; rewrite or delete the rest.

## Report

The failing output before the fix, the passing output after, and any case where a test was skipped and what verified the fix instead.

## Sources

Adapted (rewritten, not copied) from the `tdd` skill and the `test-behavior-not-implementation` principle in [cursor/plugins pstack](https://github.com/cursor/plugins/tree/main/pstack) (MIT).
