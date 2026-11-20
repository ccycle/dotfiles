# Obsidian Todo Agent Design

## Purpose

Let the user tag work by putting a card in the Todo column of the `Kanban (dotfiles)` board and have it advanced without being asked: once a day, a first-pass plan appears in `AgentDrafts/` (readable from Obsidian with no context switch) and a plan-only herdr worktree is already waiting with grilling questions.
It is the scheduled, unattended counterpart of the interactive [obsidian-to-herdr-worktree](../../../.agents/skills/obsidian-to-herdr-worktree/SKILL.md) skill.

## Non-Goals

- Implementing anything. Workers are plan-only. Code changes still start only after the user has talked to the worker.
- Editing existing notes. The vault writes are a new draft per card and the deterministic Kanban moves, nothing else.
- Handling `#TODO`-tagged household notes or other Kanban columns.
- Resolving ambiguous Kanban transitions (removed worktree, never merged). Those need a human, so they stay with the interactive `kanban-sync` skill.
- Sending vault content to any non-local model.

## Why This Structure

- A deterministic shell script drives the run, and the LLM is called only for the two steps that need judgment: making the slug and writing the draft. Driving the whole interactive skill with a local model would be unattended agentic tool use against the vault and the repo, which is exactly the "全自動だと破壊される" risk the source note warns about.
- Draft calls go to the Ollama HTTP API with no tools, so the model can produce text but cannot touch files. The script decides where that text is written.
- Supervision is two-stage. The draft is cheap to skim in Obsidian. The worktree is there for anything worth discussing. Discarding either one is the user's call, and re-eligibility follows the same rule as the interactive skill (remove the worktree).
- The per-run cap plus the Todo → In progress move bound the cost. A card is processed at most once, so a daily schedule never re-spends tokens on the same card.

## Rejected Alternatives

- **Also scanning `#TODO` notes**: those are almost all physical/household tasks that cannot be worked on from a repo. The user scoped the agent to the dotfiles board.
- **Claude, or the interactive skill's opencode free-tier default, for workers**: both send private vault content off the machine. Local-only was chosen over draft quality.
- **Appending results to the source note**: the source idea asked for in-note appends, but that conflicts with the obsidian-manager trust boundary (never edit existing notes). A linked draft in `AgentDrafts/` gives the same low-cognitive-load surface.
- **Fuzzy slug dedupe by LLM judgment**: the interactive skill uses it. Here only an exact branch match is checked, to keep the unattended path deterministic.

## Constraints

- The host is headless, and LiveSync only runs inside the Obsidian app. Without starting the app and syncing first, the run would read a stale board and could write Kanban moves over newer edits made on other devices.
- The job depends on a running herdr server. herdr is not managed by launchd, so the run fails loudly instead of queueing when the server is down.
- Dispatch state is shared with the interactive skill and the `kanban-sync` reconcile, so the scheduled and manual paths never dispatch the same card twice.
