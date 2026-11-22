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

Before finalizing an investigation answer, re-run every measurement it cites
and fix any claim whose output no longer matches (see the `measure-first`
skill). Never present an unmeasured assertion as fact.

## Cited Research for External Information

When the answer lives on the web (documentation, specs, versions, product
behavior, papers, news), follow the `research` skill. Every claim carries a
Text Fragment link to the verbatim supporting passage, and the report is shown
only after `check-citations check` passes.

## Keep Secret Values Out of Output

Command output lands in the transcript, which persists on disk and is sent to the model provider.
A secret printed there must be treated as leaked and rotated.

- When verifying a secret, check only that it exists and is non-empty (`grep -c`, `test -n`, or mask it with `sed 's/=.*/=<hidden>/'`).
- Never pass verbose or debug flags to commands that decrypt or authenticate (`sops -d --verbose`, `GIT_CURL_VERBOSE`, `curl -v` with credentials); they can print plaintext.
- When a test can fail by printing a secret, hide the actual value in its failure output.
- If a value does leak, tell the user immediately which secret it was.

## English-Only for LLM-Facing Instructions

All instructions intended for AI consumption MUST be written in English. This includes:

- CLAUDE.md and AGENTS.md content
- SKILL.md files and skill descriptions
- Hook prompts and hook script user-facing messages
- Rule files (`~/.claude/rules/`)
- Code comments that serve as agent directives

User-facing documentation (README, commit messages) may use any language.

## Documentation Placement Principle

Never maintain the same fact in two places. Code carries its own constraints; documentation carries only design intent that code cannot express.

**What this means in practice:**

- Do not write code comments. A comment is an unenforced claim that drifts silently.
- Encode a constraint instead: a name that says it, a type, an option without a default, an assertion, a lint or check whose error names the fix, or a test that fails when the constraint breaks.
- The only allowed comment is about something this code cannot change (an upstream bug, an external format quirk, a vendor requirement), and it must link to the external source.
- Design intent that code cannot express — rationale for structure, non-goals, rejected alternatives, trade-offs, cross-cutting constraints — goes in a `design.md` next to the code it describes.
- Never restate in documentation what the code already says (signatures, option values, file lists, step-by-step behavior).
- If a documented statement would become wrong after a mechanical code change (rename, reorder, restructure), it belongs in the code, not in a doc.

Use the `no-comments` skill to strip comments from a diff and encode what they claimed, the `design-doc` skill to create or update a `design.md`, and the `doc-audit` skill to find code/doc duplication and drift.

## Japanese Output

Before writing any Japanese text — a chat reply, a file, a commit message, or an artifact — load the `japanese-writing` skill and follow it.
