---
name: obsidian-to-herdr-worktree
description: Dispatch Obsidian TODO/idea notes (named via $ARGUMENTS, or picked autonomously by the AI if omitted) to parallel herdr worktrees for implementation-plan discussion only (no code changes). Self-throttles against already-running workers from prior invocations and skips notes still in flight, so repeated invocations drain the backlog gradually instead of piling load on the machine. Each worker is spawned via a priority/fallback chain (opencode nemotron-3.5-lightning-free by default, then the pi coding agent on llamaswap's gemma-4-26b-a4b if nemotron hits a rate limit) and keeps its conclusion in the chat for live 壁打ち with the human via `herdr agent attach` — the worker's conclusion is never written back to the vault, and the only vault writes are the Kanban moves described below. On each run it also reconciles the `Kanban (dotfiles)` board with the worktree state, via the shared script also used by the standalone `kanban-sync` skill: deterministic moves (Todo → In progress for a live worktree; → Done for a worktree removed after its branch merged to main) apply automatically, while ambiguous moves (a removed worktree whose branch was never started or never merged) still require explicit per-card user confirmation. Use when the user wants to turn the Todo-status cards on the `Kanban (dotfiles)` board into parallel design discussions without touching code or Obsidian.
disable-model-invocation: true
allowed-tools: Bash, Read
---

# Obsidian to Herdr Worktree

Turn Obsidian TODO notes into parallel, isolated design discussions.
The worker is spawned via a priority/fallback chain (Step 4): opencode nemotron-3.5-lightning-free by
default, falling back to the pi coding agent on llamaswap's gemma-4-26b-a4b if
nemotron hits a rate limit. The agent's conclusion stays in the chat, for the
human to 壁打ち with directly by attaching to the pane — it is not written back
into the Obsidian vault. Grilling starts immediately at dispatch: right after
producing its plan, the worker loads the `grilling` skill and drives the
discussion as a design tree (rounds of frontier questions through the
interactive question tool) until the shared understanding is reached. The
questions wait in the pane for the human to attach and answer.

The only vault writes this skill ever makes are the Kanban column moves from
Step 1's reconcile (via the shared `kanban-sync` script) and Step 7's direct
move for newly dispatched notes: `Todo → In progress` for a live worktree
applies automatically (a live worktree is deterministic evidence), as does
`→ Done` for a worktree removed after its branch merged to main. A removed
worktree whose branch was never started or never merged still asks per-card
before moving it to `Done`, `Canceled`, or leaving it in place — nothing else
is ever written to the vault.

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
its own chat. The only vault writes you may make are the Kanban column moves
from Step 1's reconcile and Step 7's direct move — nothing else goes into the
Obsidian vault.

## Step 1 — Prune state, reconcile the Kanban, check load

This step exists so repeated invocations of this skill drain the TODO backlog
gradually instead of stacking load on top of whatever prior batches are still
running. State lives outside the vault (the only vault writes this skill makes
are the Kanban moves described below) in a machine-local file:

```bash
state_file="$HOME/.local/state/obsidian-todo-dispatch/dispatched.json"
board="$HOME/Obsidian/zettelkasten/Kanban (dotfiles).md"
```

1. **Run the shared reconcile script** — this prunes state entries whose
   worktree is gone, auto-applies every deterministic Kanban move (a live
   worktree → `In progress`; a worktree removed after its branch merged to
   main → `Done`), and reports the ambiguous cases for you to ask about. It
   is the same script the standalone `kanban-sync` skill uses — see
   `.agents/skills/kanban-sync/SKILL.md` for the full output contract:

   ```bash
   .agents/skills/kanban-sync/scripts/reconcile.sh "$board" "$state_file"
   ```

   For every `CONFIRM` line in its output, ask the user individually via the
   interactive question tool — never batch-apply. Offer `Done`, `Canceled`,
   or leave in `<from>`, and apply a confirmed choice with:

   ```bash
   .agents/skills/obsidian-to-herdr-worktree/scripts/move-card.sh \
     "$board" "<from>" "<target-column>" "<title>"
   ```

   Every `AUTO` and `BACKFILL` line already happened — no confirmation
   needed, just fold them into this run's report (Step 7).

2. **Collect remaining titles as "in flight"** — these are notes already
   dispatched by a prior batch whose worktree still exists (worker may be
   idle, blocked, or mid-discussion with the human). Read this *after* the
   reconcile script above has finished pruning and backfilling:

   ```bash
   in_flight_titles=$(jq -r '[.[].title] | join("\n")' "$state_file")
   ```

3. **Collect existing branch names** — for the Step 3 slug similarity check,
   gather all worktree branch names (excluding `main`) so they can be
   consulted during slug generation:

   ```bash
   existing_branches=$(herdr worktree list | jq -r \
     '[.result.worktrees[].branch | select(. != "main")]')
   ```

## Step 2 — Select target notes

- If `$ARGUMENTS` names one or more note titles, use those directly. An explicit
  user request always wins over the in-flight exclusion below.
- Otherwise, read the Todo column of the Kanban board at
  `$HOME/Obsidian/zettelkasten/Kanban (dotfiles).md` and select target notes
  only from the cards that carry the Todo status — the `- [ ]` items under the
  `## Todo` heading. Cards in Backlog, In progress, Done, Canceled, Duplicate,
  or Archive are never selected. Extract the Todo cards and strip their
  `[[...]]` delimiters to get the titles:

  ```bash
  kanban="$HOME/Obsidian/zettelkasten/Kanban (dotfiles).md"
  todo_titles=$(awk '
    /^## Todo/ { f = 1; next }
    /^## / && f { f = 0 }
    f && /^- \[ \] / { line = $0; sub(/^- \[ \] /, "", line); gsub(/^\[\[|\]\]$/, "", line); print line }
  ' "$kanban")
  ```

  A Todo card is either a `[[wiki-link]]` whose target note holds the task
  details, or plain text where the card line itself is the whole task. Skip any
  title present in `in_flight_titles` (Step 1) — it is already being discussed
  in another pane. Favor items whose target note has enough content to reason
  about and that would benefit from a quick implementation-policy discussion;
  skip items that are pure duplicates of a note you already selected. Selection
  is autonomous — do not ask the user which ones to pick.

For each selected title, get its content: if the card was a `[[wiki-link]]`,
read the corresponding note at `$HOME/Obsidian/zettelkasten/<title>.md` (most
of these notes are 1-3 lines; that thinness is expected and is exactly what the
worker is for). If the card was plain text, the title itself is the content —
use it as-is.

## Step 3 — Generate a slug per note

For each title, invent a short English kebab-case slug yourself (2-4 words).
This becomes the git branch name, the herdr agent name, and the worktree
label. Branch names must be ASCII; note titles are Japanese sentences, so this
translation step cannot be skipped or automated mechanically — use your own
judgment about what the note is actually about.

After generating each slug, **check it against `existing_branches`** (from
Step 1). If the generated slug describes the same concept as an existing
branch (even with different wording — e.g., `per-machine-age-key` vs
`per-machine-age-keys`), then this note is already in flight under a slightly
different name — drop it from this batch and do not create a duplicate
worktree. Selection remains autonomous: use your own judgment about what
counts as "the same topic."

## Step 4 — Worker configuration

Each worker is spawned from a fixed priority/fallback chain, tried in order
until one starts successfully:

1. **opencode nemotron-3.5-lightning-free (default)** — `--kind opencode -- --auto --model
   opencode/nemotron-3.5-lightning-free`, a free-tier model hosted through opencode
   zen. `--auto` is required because these workers run unattended (no human
   present to answer a permission prompt). Use `--auto` over
   `--dangerously-skip-permissions`, which bypasses permission checks entirely
   rather than applying the auto-mode classifier. This is the default
   destination for every note.
2. **pi coding agent on llamaswap gemma (rate-limit fallback)** — `--kind pi
   -- --model google/gemma-4-26b-a4b --print`, the pi coding agent using
   llamaswap's locally-hosted `google/gemma-4-26b-a4b`. Use the fully-qualified
   `google/gemma-4-26b-a4b` ID — a bare `gemma-4-26b-a4b` resolves to a
   different provider (e.g. cloudflare-ai-gateway) and fails for lack of an API
   key. Use this only when tier 1 fails specifically because of a rate limit
   (e.g. nemotron is over its free-tier quota) — it is a fallback, not a
   preference, and is not used on ordinary start failures of other kinds.

In all cases pass `--auto` (opencode) or `--print` (pi) explicitly — do not
rely on whatever the session's default happens to be.

## Step 5 — Create all worktrees and start all agents first

Do this for every selected note before sending any prompts, so all workers run
genuinely in parallel rather than one after another. For each note, create the
worktree once, then walk the Step 4 priority chain until `herdr agent start`
succeeds:

```bash
result=$(herdr worktree create --cwd "$PWD" --branch <slug> --base main --label "<title>" --no-focus --json)
pane_id=$(echo "$result" | jq -r '.result.root_pane.pane_id')

out=$(herdr agent start <slug> --kind opencode --pane "$pane_id" -- --auto --model opencode/nemotron-3.5-lightning-free 2>&1)
if [ $? -eq 0 ]; then
  backend="opencode/nemotron-3.5-lightning-free"
elif printf '%s' "$out" | grep -qi -E "rate.?limit|quota|429|too many requests"; then
  # nemotron failed specifically due to a rate limit — fall back to pi on llamaswap gemma
  if herdr agent start <slug> --kind pi --pane "$pane_id" -- --model google/gemma-4-26b-a4b --print; then
    backend="pi/google/gemma-4-26b-a4b"
  else
    backend=""
  fi
else
  backend=""
fi
```

The pi-on-llamaswap-gemma fallback (tier 2) is used only when the nemotron
attempt (tier 1) fails because of a rate limit — inspect the failure output
for rate-limit signals (e.g. `rate limit`, `quota`, `429`, `too many
requests`) before falling back. Do not fall back to pi on ordinary start
failures of other kinds; in those cases treat the note as skipped like any
other failure.

If both attempts fail, drop this note from the batch (do not consume a
prompt step for it) and report it to the user as skipped in Step 7 rather
than silently losing track of it. Record the resolved `backend` per slug —
Step 7's report and the dispatch state should reflect which tier actually
started, since it is no longer uniform across notes.

## Step 6 — Send each worker its task (no `--wait`)

```bash
herdr agent prompt <slug> "$(cat <<'EOF'
実装方針だけを検討すること。コードは変更しない。
結論はこのチャットにそのまま書くこと。Obsidian vault やその他のファイルには
一切書き込まないこと。結論は簡潔に、かつ根拠(読んだファイルやコマンド結果)が
追えるようにまとめること。
結論をまとめたら、人間のアタッチを待たずに `grilling` skill をロードして
即座に壁打ちを開始すること。決定ツリーをラウンド単位で掘り下げ、質問は必ず
対話の質問ツールで出すこと。人間がまだアタッチしていなくても、最初のラウンドの
質問を先に提示しておくこと。質問ツールで待機できない環境なら、質問をチャットに
番号付きで書き出して人間の回答を待つこと。フロンティアが空になり共有理解に
達するまで止まらないこと。

対象ノート(<title>)の中身:
<note content>
EOF
)"$'\n' --timeout 600000
```

Do not pass `--wait`. This skill's job ends once all prompts are sent — do not
block waiting for workers to finish, and do not spawn a separate monitor
agent. Each worker starts grilling immediately after dispatch (per the Step 6
prompt): it produces its plan, then drives the grilling session, so the first
round of frontier questions is already waiting in the pane. The user watches
progress in the herdr TUI (idle/working/blocked/done per tab) and attaches to
a pane (`herdr agent attach <slug>`) to answer the waiting questions and
continue the discussion. That is the whole surface — sufficient and costs no
extra tokens.

## Step 7 — Record dispatch state, report, and stop

For each note actually dispatched this run, append it to the state file from
Step 1 so future invocations know it is in flight:

```bash
tmp=$(mktemp)
jq --arg slug "<slug>" --arg title "<title>" --arg branch "<slug>" \
   --arg backend "<backend>" \
   --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   '. + {($slug): {title: $title, branch: $branch, backend: $backend, dispatched_at: $ts}}' \
   "$state_file" > "$tmp" && mv "$tmp" "$state_file"
```

Then tell the user which slugs/branches/worktrees were created, which backend
tier each one actually started on (opencode nemotron-3.5-lightning-free vs. the pi-on-llamaswap
gemma fallback —
per Step 5 this can differ note to note), which notes were dropped because
both tiers failed to start, how many slots were skipped due to prior
in-flight workers (if any), and that the plan discussion is visible by
attaching to each pane or watching the herdr TUI. Do not read the workers'
output, merge anything, or clean up worktrees yourself — that is a separate,
later human step (converse with the worker directly, then `herdr worktree
remove` when done with a branch). Next run's Step 1 reconcile will then move
that card out of `In progress` automatically if the branch was merged to
main, or ask what to do with it otherwise (never started, or started but
never merged).

For each note dispatched this run, its worktree now exists but its card is
still in `Todo` — the board would be out of sync with the worktrees until the
next invocation. A live worktree is the same deterministic evidence Step 1's
reconcile auto-applies on, so move each of these directly, without asking:

```bash
.agents/skills/obsidian-to-herdr-worktree/scripts/move-card.sh \
  "$board" "Todo" "In progress" "<title>"
```

## Rules

1. Never let a worker touch code — the prompt must say plan-only every time.
2. Never let a worker write to the Obsidian vault or any other file — the
   conclusion lives only in its own chat. The only vault writes this skill
   itself makes are the Kanban column moves from Step 1's reconcile and
   Step 7's direct In-progress move, applied via `scripts/move-card.sh`
   (Step 1's `AUTO` and `BACKFILL` cases and all of Step 7 apply without
   asking; Step 1's `CONFIRM` cases still require an explicit per-card
   answer). The dispatch-state file lives outside the vault at
   `$HOME/.local/state/obsidian-todo-dispatch/`, never inside it.
3. Never add a monitoring/polling agent — herdr TUI plus attaching to a pane
   is the whole surface for both status-checking and 壁打ち. The Step 1 load
   check is a one-shot query at the start of a run, not a polling loop.
4. Note selection is autonomous (your own judgment, Step 2) — do not ask the
   user which notes to pick, and do not ask which in-flight notes to skip.
   This does not cover Step 1's `CONFIRM` cases, the one place you DO ask the
   user, per-card, before applying a Kanban move. Step 1's `AUTO`/`BACKFILL`
   cases and Step 7's In-progress move are deterministic and apply without
   asking.
5. Every worker is spawned through the same fixed priority chain (Step 4:
   opencode nemotron-3.5-lightning-free → pi on llamaswap gemma) — the *chain* is uniform across
   notes, but which tier actually ends up running is not, since it depends on
   tier availability at spawn time. Never skip a tier or reorder the chain per
   note.
6. Never edit `dispatched.json` by hand or skip Step 1's prune — the human's
   only supported way to make a note re-eligible is `herdr worktree
   remove`, which the prune step then detects automatically.
```