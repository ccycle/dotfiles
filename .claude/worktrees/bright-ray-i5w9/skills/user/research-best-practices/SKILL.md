---
name: research-best-practices
description: Research Claude Code best practices and audit current configuration for improvements
---

# Research Best Practices

## Overview

Research the latest Claude Code best practices from official documentation and community resources, audit the current dotfiles configuration against them, and propose targeted improvements.

## Workflow

### Phase 1: Research — Gather Best Practices

Use `WebSearch` to query multiple sources:

- `"Claude Code best practices site:docs.anthropic.com"`
- `"Claude Code AGENTS.md best practices"`
- `"Claude Code skills slash commands best practices"`
- `"Claude Code settings.json hooks configuration"`
- `"Claude Code changelog new features 2025 2026"`

Use `WebFetch` to retrieve key pages directly:

- `https://docs.anthropic.com/en/docs/claude-code`
- Any additional URLs discovered during search

Organize findings into categories:

- **Skill design** — structure, naming, description, triggers
- **AGENTS.md / CLAUDE.md** — content guidelines, layering
- **Settings** — permissions, environment variables, model config
- **Hooks** — pre/post command hooks, automation patterns
- **Workflow patterns** — agent orchestration, tool usage, memory

### Phase 2: Audit — Assess Current State

Read the current configuration:

1. `Glob` for all `SKILL.md` files under `skills/` and `Read` each one.
2. Read `AGENTS.md` in the repo root.
3. Read `.claude/settings.local.json` (project settings).
4. Read `~/.claude/settings.json` (user settings).
5. Read `~/.claude/CLAUDE.md` (user-level instructions).
6. Read any hook scripts referenced in settings.

Compare each item against the best practices gathered in Phase 1. Identify:

- **Gaps** — best practices not yet adopted
- **Strengths** — areas already aligned with best practices
- **Anti-patterns** — configurations that contradict recommendations

### Phase 3: Report — Present Findings

Output a structured Markdown report with the following format:

```
## Strengths (Already Aligned)
- [item]: [why it's good] ([source URL])

## Recommended Improvements

### High Impact
| # | Category | Current State | Recommendation | Source |
|---|----------|---------------|----------------|--------|
| 1 | ...      | ...           | ...            | [link] |

### Medium Impact
| # | Category | Current State | Recommendation | Source |
|---|----------|---------------|----------------|--------|

### Low Impact
| # | Category | Current State | Recommendation | Source |
|---|----------|---------------|----------------|--------|
```

Each recommendation must include:

- The specific file(s) to modify
- A concrete description of the change
- A source URL as evidence

### Phase 4: Apply — Implement Selected Changes (User-Driven)

After presenting the report:

1. Ask the user which improvements to apply (by number or category).
2. Apply changes **one at a time**, showing the diff before proceeding.
3. After each change, ask for confirmation before moving to the next.
4. For Nix file changes, recommend running `/verify-change` after applying.

## Guardrails

- **Never modify files without explicit user approval.**
- **Every recommendation must cite a source URL.** If web search fails, state the limitation clearly rather than guessing.
- **Prioritize official Anthropic documentation** over community blog posts or third-party guides.
- **Never recommend removing `deny` rules** from `settings.json`.
- **Do not recommend changes that conflict with existing hook logic** without calling out the conflict.
