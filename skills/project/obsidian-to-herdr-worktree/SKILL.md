---
name: obsidian-to-herdr-worktree
description: Dispatch Obsidian TODO/idea notes (named via $ARGUMENTS, or picked autonomously by the AI if omitted) to parallel herdr worktrees for implementation-plan discussion only (no code changes). Self-throttles against already-running workers from prior invocations and skips notes still in flight, so repeated invocations drain the backlog gradually instead of piling load on the machine. Each worker is spawned via a priority/fallback chain (opencode deepseek by default, then the pi coding agent on llamaswap's gemma-4-26b-a4b if deepseek hits a rate limit) and keeps its conclusion in the chat for live 壁打ち with the human via `herdr agent attach` — nothing is written back to the vault. Use when the user wants to turn vault TODO notes into parallel design discussions without touching code or Obsidian.
disable-model-invocation: true
allowed-tools: Bash, Read
---

# Obsidian to Herdr Worktree

Turn Obsidian TODO notes into parallel, isolated design discussions.
The worker is spawned via a priority/fallback chain (Step 4): opencode deepseek by
default, falling back to the pi coding agent on llamaswap's gemma-4-26b-a4b if
deepseek hits a rate limit. The agent's conclusion stays in the chat, for the
human to 壁打ち with directly by attaching to the pane — it is not written back
into the Obsidian vault.

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

## Step 1 — Check current load and prune finished dispatches

This step exists so repeated invocations of this skill drain the TODO backlog
gradually instead of stacking load on top of whatever prior batches are still
running. State lives outside the vault (this skill never writes to the vault)
in a machine-local file:

```bash
state_file="$HOME/.local/state/obsidian-todo-dispatch/dispatched.json"
mkdir -p "$(dirname "$state_file")"
test -f "$state_file" || echo '{}' > "$state_file"
```

1. **Prune state entries whose worktree is gone** — once the human removes a
   worktree (`herdr worktree remove`) the note is considered resolved or
   abandoned, and becomes eligible for re-selection again:

   ```bash
   current_branches=$(herdr worktree list | jq -r '.result.worktrees[].branch')
   keep=$(printf '%s\n' "$current_branches" | jq -R -s -c 'split("\n") | map(select(length > 0))')
   tmp=$(mktemp)
   jq --argjson keep "$keep" \
     'with_entries(select(.value.branch as $b | $keep | index($b)))' \
     "$state_file" > "$tmp" && mv "$tmp" "$state_file"
   ```

2. **Collect remaining titles as "in flight"** — these are notes already
   dispatched by a prior batch whose worktree still exists (worker may be
   idle, blocked, or mid-discussion with the human):

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

- If `$ARGUMENTS` names one or more note titles, use those directly. An explicit user request always wins
  over the in-flight exclusion below.
- Otherwise, read `$HOME/Obsidian/zettelkasten/dotfiles 整備 TODO リスト.md`,
  list its `[[...]]` links, and select target notes yourself using
  your own judgment. Skip any title present in `in_flight_titles` (Step 1) —
  it is already being discussed in another pane. Favor items whose target
  note has enough content to reason about and that would benefit from a quick
  implementation-policy discussion; skip items that are pure duplicates of a
  note you already selected. Selection is autonomous — do not ask the user
  which ones to pick.

For each selected title, read the corresponding note at
`$HOME/Obsidian/zettelkasten/<title>.md` to get its current content (most of
these notes are 1-3 lines; that thinness is expected and is exactly what the
worker is for).

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

1. **opencode deepseek (default)** — `--kind opencode -- --auto --model
   opencode/deepseek-v4-flash-free`, a free-tier model hosted through opencode
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
   (e.g. deepseek is over its free-tier quota) — it is a fallback, not a
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

out=$(herdr agent start <slug> --kind opencode --pane "$pane_id" -- --auto --model opencode/deepseek-v4-flash-free 2>&1)
if [ $? -eq 0 ]; then
  backend="opencode/deepseek-v4-flash-free"
elif printf '%s' "$out" | grep -qi -E "rate.?limit|quota|429|too many requests"; then
  # deepseek failed specifically due to a rate limit — fall back to pi on llamaswap gemma
  if herdr agent start <slug> --kind pi --pane "$pane_id" -- --model google/gemma-4-26b-a4b --print; then
    backend="pi/google/gemma-4-26b-a4b"
  else
    backend=""
  fi
else
  backend=""
fi
```

The pi-on-llamaswap-gemma fallback (tier 2) is used only when the deepseek
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
一切書き込まないこと。人間が後でこのペインにアタッチして壁打ちする前提なので、
結論は簡潔に、かつ根拠(読んだファイルやコマンド結果)が追えるようにまとめること。

対象ノート(<title>)の中身:
<note content>
EOF
)"$'\n' --timeout 600000
```

Do not pass `--wait`. This skill's job ends once all prompts are sent — do not
block waiting for workers to finish, and do not spawn a separate monitor
agent. The user watches progress directly in the herdr TUI (idle/working/
blocked/done per tab) and attaches to a pane (`herdr agent attach <slug>`)
whenever they want to read the conclusion or continue the discussion live;
that is sufficient and costs no extra tokens.

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
tier each one actually started on (opencode deepseek vs. the pi-on-llamaswap
gemma fallback —
per Step 5 this can differ note to note), which notes were dropped because
both tiers failed to start, how many slots were skipped due to prior
in-flight workers (if any), and that the plan discussion is visible by
attaching to each pane or watching the herdr TUI. Do not read the workers'
output, merge anything, or clean up worktrees yourself — that is a separate,
later human step (converse with the worker directly, then `herdr worktree
remove` when done with a branch — this also frees the note up for
re-selection next run, per Step 1's pruning).

## Rules

1. Never let a worker touch code — the prompt must say plan-only every time.
2. Never let a worker write to the Obsidian vault or any other file — the
   conclusion lives only in its own chat. The dispatch-state file (Step 1) is
   the only file this skill itself writes, and it lives outside the vault at
   `$HOME/.local/state/obsidian-todo-dispatch/`, never inside it.
3. Never add a monitoring/polling agent — herdr TUI plus attaching to a pane
   is the whole surface for both status-checking and 壁打ち. The Step 1 load
   check is a one-shot query at the start of a run, not a polling loop.
4. Note selection is autonomous (your own judgment, Step 2) — do not ask the
   user which notes to pick, and do not ask which in-flight notes to skip.
5. Every worker is spawned through the same fixed priority chain (Step 4:
   opencode deepseek → pi on llamaswap gemma) — the *chain* is uniform across
   notes, but which tier actually ends up running is not, since it depends on
   tier availability at spawn time. Never skip a tier or reorder the chain per
   note.
6. Never edit `dispatched.json` by hand or skip Step 1's prune — the human's
   only supported way to make a note re-eligible is `herdr worktree
   remove`, which the prune step then detects automatically.
```