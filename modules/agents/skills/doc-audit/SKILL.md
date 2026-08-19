---
name: doc-audit
description: Audit a repository or module for documentation that duplicates or contradicts code. Reports misplaced content across docs, comments, and design.md, and proposes moves. Read-only by default; applies changes only when explicitly approved.
---

# Doc Audit

## Overview

Find violations of the Documentation Placement Principle: duplication (docs restating what code says), drift (docs contradicting code), and misplaced detail (content living at the wrong layer). The audit itself is strictly read-only; it produces a report of findings and proposed actions.

## Scope Selection

- Default to the module or path the user names. Audit the whole repository only when explicitly requested.
- Inventory the candidate docs in scope: `README*`, `docs/`, `design.md`, and any `*.md` adjacent to code.
- Map each doc to the code it describes before judging it.

## Audit Workflow (read-only)

1. **Inventory**: list docs in scope and the code each one describes.
2. **Detect duplication**: doc statements that restate what code or comments already say — signatures, option values, file lists, step-by-step behavior.
3. **Detect drift**: doc statements that contradict the current code. Per the Verification-First Principle, read the code to confirm every suspected contradiction before reporting it — never report unverified drift.
4. **Detect misplaced detail**:
   - Implementation detail living in a doc that should be a code comment at the relevant location.
   - Cross-cutting design intent living only in a code comment that belongs in `design.md`.
   - Code whose rationale exists only in a distant doc, with no comment at the site.

## Report Format

One entry per finding:

- **Location**: doc file and the related code file(s).
- **Category**: `duplicate` / `stale` / `misplaced`.
- **Evidence**: the doc sentence in question and the code that verifies the judgment.
- **Proposed action**: one of `doc → comment`, `delete duplication`, `comment → design.md`, `update stale doc`.

## Applying Fixes

- MUST NOT modify any file during the audit.
- Apply only the findings the user explicitly approves.
- When moving text into a code comment, rewrite it as a "why" comment (constraint, invariant, rationale) — do not paste descriptive "what" prose.
- When moving a comment into `design.md`, follow the `design-doc` skill's rules (code-agnostic, no restated signatures).
