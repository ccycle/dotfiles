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

## Measure-First for Investigation Tasks

Investigation tasks (debugging, root-cause analysis, verifying system state)
must start from measurement, not memory. Decompose the question into checkable
claims, assign each claim a measurement command, and run it — creating the
measurement if none exists. Report claims in claim / evidence / confidence
schema.

Before finalizing an investigation answer, invoke the `measure-reviewer`
subagent (see the `measure-first` skill) and end with the exact line
`MEASURE-REVIEW: approved`. A Stop hook enforces the marker. Never present an
unmeasured assertion as fact.

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

## Japanese Output Style

When responding in Japanese, apply the following to avoid the stilted, translated-sounding Japanese that LLMs tend to produce. This does not fully eliminate the translated feel, but it improves consistency and readability.

**What this means in practice:**

- Match the sentence-ending register to the output channel, and keep it consistent within that output — do not mix registers:
  - Chat replies addressed directly to the user (conversational turns): 丁寧語 (です/ます).
  - Written documents saved to a file or persisted artifact (design.md, reports, memory notes, artifacts, commit/PR descriptions): 論文体 — である/する調 only (never だ止め), objective and formal, avoiding colloquial expressions and first-person casual phrasing.
- Keep sentences short. Avoid nesting multiple clauses into one long sentence.
- Prefer the simpler verb form over a verbose construction (e.g. 「〜することができます」より「〜できます」、「〜を行う」より対応する動詞そのもの).
- Avoid the over-explicit subject repetition typical of literal English-to-Japanese translation; omit the subject when it's clear from context, as natural Japanese does.
- Avoid empty preambles such as 「〜については、」「〜に関して、」 when they add no information.
- Don't overuse bullet lists for content that reads better as plain prose; reserve bullets for genuinely parallel items.
- Avoid unnecessary katakana loanwords when a natural Japanese term already exists.
- Noun-ending sentences (体言止め): do not use them in running prose or explanatory text — end those sentences with a conjugated verb or adjective. Noun-ending is acceptable in headings and bullet-list item labels.

**Examples (before → after, shown in document register — である/する調; for chat replies, apply the same simplification but end in です/ます):**

- Before: 「このエラーはネットワーク接続の問題によって発生している可能性があります。」
  After: 「このエラーはおそらくネットワーク接続の問題で起きている。」
- Before: 「設定ファイルを変更することで、この動作を変更することができます。」
  After: 「設定ファイルを変更すれば、この動作を変更できる。」
- Before (体言止めの多用): 「原因は設定ミス。対応は再起動。」
  After: 「原因は設定ミスである。再起動すれば直る。」

**After drafting a Japanese response:** Before finalizing, re-scan the draft against the checklist above — register-vs-channel mismatch, sentence-ending consistency, and 体言止め are the easiest violations to miss — and rewrite any sentence that breaks it.
