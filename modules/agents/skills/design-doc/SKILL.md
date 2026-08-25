---
name: design-doc
description: Create or update a per-module design.md capturing design intent that code cannot express (rationale for structure, non-goals, rejected alternatives, trade-offs). Use when designing a new module or feature, or when a design decision is made that code alone cannot convey.
---

# Design Doc

## Overview

Maintain one `design.md` per module or feature, placed in the same directory as the code it describes. It is a living document describing the _current_ design intent — not an append-only decision log (ADR). When a decision changes, rewrite the affected section in the same commit as the code change.

`design.md` complements the Documentation Placement Principle: code comments carry the "why" at code level; `design.md` carries only intent that no single code location can express.

## When to Create or Update

Create or update a `design.md` when:

- Creating a new module whose structure is not self-evident.
- Choosing between alternatives where the rejected option should be recorded to prevent re-litigating it later.
- A constraint spans multiple files (cross-cutting), so no single comment can carry it.
- A decided change contradicts an existing `design.md` — update it in the same commit.

Do NOT create one when:

- The module is trivial and its structure is self-evident.
- The content is about one specific code location — write a comment there instead.

## Template

```markdown
# <Module> Design

## Purpose

What problem this module solves. One short paragraph.

## Non-Goals

What this module deliberately does not do. Explicit bullet list —
this is the basis for detecting out-of-scope changes in review.

## Why This Structure

Rationale for the shape of the code: why the files/boundaries are
divided this way.

## Rejected Alternatives

What was considered and why it was not chosen. Code can never
express this; it is the highest-value section.

## Constraints

Cross-cutting or external constraints (platform, ordering,
compatibility) that shape multiple files.
```

Omit sections that would be empty. Keep the whole file short — a `design.md` that is not read is worse than none.

## Rules

- Keep it code-agnostic: no line numbers, no `file:line` references.
- Do not restate function signatures, option names or values, or file inventories — the code already says these.
- Every statement must survive a mechanical refactor (rename, reorder, restructure) unchanged. If it would not, move it into a code comment at the relevant location.
- Write in English (LLM-facing document).
