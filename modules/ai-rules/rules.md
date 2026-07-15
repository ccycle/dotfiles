---
description: Global behavioral rules for AI coding assistants
alwaysApply: true
---

# Global Behavioral Rules

## Verification-First Principle

Do not mix speculation into your claims or assertions. Every factual statement about code, configuration, file contents, or system state MUST be backed by verification through actual tool use (reading files, running commands, searching code) before being stated.

**What this means in practice:**

- Before claiming a file contains something, read it first.
- Before claiming a command will produce a result, run it first.
- Before claiming a feature exists or does not exist, search for it first.
- If you cannot verify a claim, explicitly state it is unverified speculation and mark it as such.
- Never present an assumption as a fact.

**After completing work:**

- Review your response and verify every factual claim was backed by tool use.
- If any claim remains unverified, verify it now or explicitly mark it as unverified.

## English-Only for LLM-Facing Instructions

All instructions intended for AI consumption MUST be written in English. This includes:

- CLAUDE.md and AGENTS.md content
- SKILL.md files and skill descriptions
- Hook prompts and hook script user-facing messages
- Rule files (`~/.claude/rules/`)
- Code comments that serve as agent directives

User-facing documentation (README, commit messages) may use any language.

## Documentation Placement Principle

Never maintain the same fact in two places. Implementation details belong in code comments; documentation carries only design intent that code cannot express.

**What this means in practice:**

- Code comments explain the "why" at code level: non-obvious constraints, invariants, gotchas, and reasons a simpler approach was not used.
- Design intent that code cannot express — rationale for structure, non-goals, rejected alternatives, trade-offs, cross-cutting constraints — goes in a `design.md` next to the code it describes.
- Never restate in documentation what the code or its comments already say (signatures, option values, file lists, step-by-step behavior).
- If a documented statement would become wrong after a mechanical code change (rename, reorder, restructure), it belongs in or next to the code, not in a doc.
- Docs MUST NOT duplicate comments, and comments MUST NOT duplicate docs.

Use the `design-doc` skill to create or update a `design.md`, and the `doc-audit` skill to find code/doc duplication and drift.
