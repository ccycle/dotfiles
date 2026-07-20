---
name: obsidian-manager
description: Draft zettelkasten notes on the user's behalf in their Obsidian vault style. Expands stub notes via research, turns conversation conclusions into notes, and finds related/duplicate notes. Use when the user asks to write, expand, or connect notes in their zettelkasten.
---

# Obsidian Manager

Delegated note-writing for the user's zettelkasten vault at `$HOME/Obsidian/zettelkasten`.

Division of labor: the user captures ideas as short stubs and decides what matters; the agent researches, drafts in the user's style, and surfaces connections.
The agent never decides what enters the permanent note graph — the user reviews every draft.

## Prerequisites

- The vault is plain Markdown; access it directly with Read/Grep/Glob. No CLI or running Obsidian app is required.
- **Read `references/note-conventions.md` before drafting anything.** Every draft must follow it.

## Output policy (trust boundary)

- **Never edit existing notes.** All workflows below either read the vault or produce new drafts.
- The designated draft location is `AgentDrafts/` inside the vault: one file per draft, named `<conclusion title>.md`.
- **If `AgentDrafts/` does not exist, do not write to the vault at all** — present drafts as Markdown code blocks in chat instead.
  Creating `AgentDrafts/` is the user's explicit opt-in switch for vault writes; never create it yourself.
- The user reviews drafts and moves accepted ones to the vault root (or discards them). Do not do this move.

## Workflows

### Expand stub

Input: a stub note (empty or a few lines) chosen by the user, or a title they give directly.

1. Treat the title as the note's conclusion. Read the stub body for any existing bullets — they are constraints, not filler.
2. Research as needed (`/web-search`, reading code, reasoning). Search the vault for related notes to weave in as `[[links]]`.
3. Draft a bullet-tree body per the conventions: evidence and elaboration nested under top-level claims, open questions left as `？` bullets.
4. Output as a **new draft** (per output policy). Even when expanding an existing stub, do not edit the stub file; the user merges.

### Conversation → note

Input: the current conversation or investigation session.

1. Extract each distinct conclusion reached. One claim = one note; do not bundle a session summary into a single file.
2. For each, phrase the conclusion as a Japanese-sentence title, then write a short bullet body: the reasoning, key sources as links, and unresolved questions.
3. Output each as a separate draft.

### Find related / detect duplicates

Input: a new idea, a draft, or an existing note. Read-only — produces a report in chat, never files.

1. Search the vault (Grep/Glob over titles and bodies; titles carry most meaning) for notes touching the same concepts. Try both Japanese and English phrasings of key terms.
2. Report two lists:
   - **Link candidates:** notes worth referencing as `[[...]]`, with one line on the connection.
   - **Merge candidates:** notes making the same claim (duplicates are expected by design; merging is the user's call).

## Error handling

If the vault directory is missing or unreadable, stop and tell the user; do not guess an alternative path.
