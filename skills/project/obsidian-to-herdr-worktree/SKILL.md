---
name: obsidian-to-herdr-worktree
description: Dispatch up to 4 Obsidian TODO/idea notes (named via $ARGUMENTS, or picked autonomously by the AI if omitted) to parallel herdr worktrees for implementation-plan discussion only (no code changes). Each worker keeps its conclusion in the chat for live 壁打ち with the human via `herdr agent attach` — nothing is written back to the vault. Use when the user wants to turn vault TODO notes into parallel design discussions without touching code or Obsidian.
disable-model-invocation: true
allowed-tools: Bash, Read
---

# Obsidian to Herdr Worktree

Turn Obsidian TODO notes into parallel, isolated design discussions. Up to 4
notes are selected — named directly via `$ARGUMENTS`, or picked autonomously
by the AI if none are given — and each gets its own git worktree and its own
Claude/opencode agent whose job is to research and propose an implementation
approach — never to write code. The agent's conclusion stays in the chat, for
the human to 壁打ち with directly by attaching to the pane — it is not written
back into the Obsidian vault.

This is a narrower, opinionated sibling of the generic `/worktree` skill:
`/worktree` dispatches implementation work; this skill dispatches plan-only
research, sourced from the vault.

Task(s): $ARGUMENTS

## Prerequisite

```bash
test "${HERDR_ENV:-}" = "1"
```

If this fails, say you are not running inside Herdr and stop. This skill only
supports the herdr backend.

## You are a dispatcher, not an implementer

Do not investigate the codebase yourself, do not write or edit source files,
and do not decide the implementation approach. Your only job is to pick target
notes, generate slugs, spawn worker agents, and hand each one its source
note's content. The worker does all the research and keeps its conclusion in
its own chat — do not write anything into the Obsidian vault yourself.

## Step 1 — Select up to 4 target notes

- If `$ARGUMENTS` names one or more note titles, use those directly (max 4).
- Otherwise, read `$HOME/Obsidian/zettelkasten/dotfiles 整備 TODO リスト.md`,
  list its `[[...]]` links, and select up to 4 yourself using your own
  judgment. Favor items whose target note has enough content to reason about
  and that would benefit from a quick implementation-policy discussion; skip
  items that are pure duplicates of a note you already selected. Selection is
  autonomous — do not ask the user which ones to pick.

For each selected title, read the corresponding note at
`$HOME/Obsidian/zettelkasten/<title>.md` to get its current content (most of
these notes are 1-3 lines; that thinness is expected and is exactly what the
worker is for).

## Step 2 — Generate a slug per note

For each title, invent a short English kebab-case slug yourself (2-4 words).
This becomes the git branch name, the herdr agent name, and the worktree
label. Branch names must be ASCII; note titles are Japanese sentences, so this
translation step cannot be skipped or automated mechanically — use your own
judgment about what the note is actually about.

## Step 3 — Choose a backend per note (token/cost efficiency)

First, check that the local LLM server is actually up — it lives only on
`mac-mini-m4-pro`, and since it is now every worker's default (not a single
opt-in pilot slot), a sleeping/down server would otherwise fail all 4 workers
at once:

```bash
curl -sf --max-time 3 http://llm.mac-mini-m4-pro.internal/v1/models >/dev/null
```

If this fails, skip the opencode default entirely for this batch and fall
back to `--kind claude --permission-mode auto` for every worker instead — do
not retry per-note or half-fall-back, since the server being down affects all
opencode workers identically.

If it succeeds, default every worker to `--kind opencode -- --model
llamaswap/google/gemma-4-e4b` (the mac-mini-m4-pro llm-server). This is why
this skill's ceiling is 4 notes, not 3: llama-server auto-configures
`n_parallel=4` for whichever single model is loaded, and that model's
footprint (~13GB RSS for the 26B-A4B variant) leaves ample headroom under the
~55GB Metal working-set ceiling on 64GB unified memory — so 4 concurrent
opencode workers genuinely run in parallel, without reloading the model
between them.

- **All 4 opencode workers in a batch must use the identical model ID** —
  llama-swap only keeps one model loaded at a time, so mixed model IDs
  serialize instead of running in parallel (each swap costs up to ~1 minute of
  reload).
- **Escalate an individual note to Claude** (`--kind claude --permission-mode
  auto`) when it likely needs real architectural judgment — the worker must be
  able to find and reason against existing precedent, the way the real `hunk
  導入` trial run found `modules/difit/` and corrected its own initial (wrong)
  plan after reading it. Local-LLM instruction-following quality for this
  skill's task (deciding what's in scope, correcting its own wrong
  assumptions, keeping the conclusion tight enough for a chat) is still only
  validated on a single-note pilot, not at 4-way scale — treat every
  escalation to Claude as a per-note judgment call, not a reason to abandon
  the local-LLM default across the board.
- **Cheaper Claude model** (add `--model <alias>` such as `haiku`) and
  **`--bare`** remain available for any note you escalate to Claude, same as
  before: `--bare` skips hooks/LSP/plugin sync/CLAUDE.md auto-discovery, which
  is fine for genuinely plan-only, non-nix items, but means that worker does
  not inherit the global CLAUDE.md rules (verification-first, nix rules,
  etc.).

Do not add generic "explore efficiently" instructions to the Step 5 prompt —
`loop-engineering.md`'s Token Efficiency section already applies automatically
to every Claude worker that isn't `--bare`, and repeating it here would
duplicate that documentation.

## Step 4 — Create all worktrees and start all agents first

Do this for every selected note before sending any prompts, so all workers run
genuinely in parallel rather than one after another:

```bash
result=$(herdr worktree create --cwd "$PWD" --branch <slug> --base main --label "<title>" --no-focus --json)
pane_id=$(echo "$result" | jq -r '.result.root_pane.pane_id')
herdr agent start <slug> --kind <kind from step 3> --pane "$pane_id" -- <native args from step 3, e.g. --permission-mode auto, or --model llamaswap/google/gemma-4-e4b>
```

Pass `--permission-mode auto` explicitly on every `claude` `agent start` — do
not rely on whatever the session's default happens to be.

## Step 5 — Send each worker its task (no `--wait`)

```bash
herdr agent prompt <slug> "$(cat <<'EOF'
実装方針だけを検討すること。コードは変更しない。
結論はこのチャットにそのまま書くこと。Obsidian vault やその他のファイルには
一切書き込まないこと。人間が後でこのペインにアタッチして壁打ちする前提なので、
結論は簡潔に、かつ根拠(読んだファイルやコマンド結果)が追えるようにまとめること。

対象ノート(<title>)の中身:
<note content>
EOF
)" --timeout 600000
```

Do not pass `--wait`. This skill's job ends once all prompts are sent — do not
block waiting for workers to finish, and do not spawn a separate monitor
agent. The user watches progress directly in the herdr TUI (idle/working/
blocked/done per tab) and attaches to a pane (`herdr agent attach <slug>`)
whenever they want to read the conclusion or continue the discussion live;
that is sufficient and costs no extra tokens.

## Step 6 — Report and stop

Tell the user which slugs/branches/worktrees were created, which backend each
one is running, and that the plan discussion is visible by attaching to each
pane or watching the herdr TUI. Do not read the workers' output, merge
anything, or clean up worktrees yourself — that is a separate, later human
step (converse with the worker directly, then `herdr worktree remove` when
done with a branch).

## Rules

1. Never exceed 4 concurrent dispatches per invocation. If the user wants
   more, tell them to run this skill again after the first batch's workers
   are attached-to/finished.
2. Never let a worker touch code — the prompt must say plan-only every time.
3. Never let a worker write to the Obsidian vault or any other file — the
   conclusion lives only in its own chat.
4. Never add a monitoring/polling agent — herdr TUI plus attaching to a pane
   is the whole surface for both status-checking and 壁打ち.
5. Note selection is autonomous (your own judgment, Step 1) — do not ask the
   user which notes to pick.
6. Never mix different local-LLM model IDs across opencode workers in the
   same batch.
7. Escalating a note from the local-LLM default to Claude (Step 3) is a
   per-note judgment call, not a standing configuration — apply it selectively
   when a note looks architecturally non-trivial.
