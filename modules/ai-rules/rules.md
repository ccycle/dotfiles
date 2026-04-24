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
