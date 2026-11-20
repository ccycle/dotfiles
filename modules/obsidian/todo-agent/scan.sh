#!/usr/bin/env bash
# Scheduled, headless counterpart of the obsidian-to-herdr-worktree skill.
# Picks up to MAX_PER_RUN Todo cards from the `Kanban (dotfiles)` board and,
# for each one, writes a first-pass plan into AgentDrafts/ and opens a
# plan-only herdr worktree whose worker starts grilling the user.
# Everything LLM-side goes to the local Ollama server — vault content never
# leaves this machine.
#
# Env (set by darwin.nix): REPO_DIR, LLM_URL, MODEL.
# DRY_RUN=1 prints what would be dispatched (including the generated drafts)
# without syncing, creating worktrees, or writing to the vault/state file.
set -euo pipefail

: "${REPO_DIR:?REPO_DIR is required (dotfiles checkout used for git/herdr)}"
: "${LLM_URL:?LLM_URL is required (Ollama base URL)}"
: "${MODEL:?MODEL is required (Ollama model id)}"
DRY_RUN="${DRY_RUN:-0}"

MAX_PER_RUN=3
vault="$HOME/Obsidian/zettelkasten"
board="$vault/Kanban (dotfiles).md"
drafts="$vault/AgentDrafts"
state_file="$HOME/.local/state/obsidian-todo-dispatch/dispatched.json"
skills="$REPO_DIR/.agents/skills"

log() { printf '%s %s\n' "$(date -u +%FT%TZ)" "$*" >&2; }

# One Ollama chat turn; $2 is an optional JSON schema for structured output.
ask_llm() {
  local body
  body=$(jq -nc --arg m "$MODEL" --arg p "$1" --argjson f "${2:-null}" \
    '{model: $m, stream: false, think: false, messages: [{role: "user", content: $p}]}
     + (if $f == null then {} else {format: $f} end)')
  curl -fsS -m 900 "$LLM_URL/api/chat" -d "$body" | jq -r '.message.content'
}

test -f "$board" || {
  log "board not found: $board"
  exit 1
}
herdr status server >/dev/null || {
  log "herdr server is not running; nothing dispatched"
  exit 1
}
cd "$REPO_DIR"

if [ "$DRY_RUN" != 1 ]; then
  # Obsidian (and so LiveSync) is not normally running on this headless host;
  # without it the local vault copy is stale and Kanban moves would be
  # written against an old board. -g keeps it in the background.
  open -g -a Obsidian
  sleep 30
  "$skills/obsidian-livesync-sync/scripts/sync.sh"
  sleep 30
  # Deterministic moves only. CONFIRM lines need a human and are left for
  # the interactive kanban-sync skill.
  "$skills/kanban-sync/scripts/reconcile.sh" "$board" "$state_file" |
    while IFS= read -r line; do log "reconcile: $line"; done
fi

in_flight=$(jq -r '.[].title' "$state_file" 2>/dev/null || true)
branches=$(herdr worktree list | jq -r '.result.worktrees[].branch')

# Same Todo-column extraction as obsidian-to-herdr-worktree Step 2.
mapfile -t todo < <(awk '
  /^## Todo/ { f = 1; next }
  /^## / && f { f = 0 }
  f && /^- \[ \] / { line = $0; sub(/^- \[ \] /, "", line); gsub(/^\[\[|\]\]$/, "", line); print line }
' "$board")

conventions=$(cat "$skills/obsidian-manager/references/note-conventions.md")
dispatched=0
for title in "${todo[@]}"; do
  [ "$dispatched" -ge "$MAX_PER_RUN" ] && break
  [ -n "${title// /}" ] || continue
  grep -qxF -- "$title" <<<"$in_flight" && continue

  note="$vault/$title.md"
  if [ -f "$note" ]; then content=$(cat "$note"); else content="$title"; fi

  slug=$(ask_llm "Give a 2-4 word English kebab-case git branch slug for this task. Task: $title" \
    '{"type":"object","properties":{"slug":{"type":"string"}},"required":["slug"]}' |
    jq -r '.slug' | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-*//; s/-*$//')
  # ponytail: exact-match dedupe only; the interactive skill also catches
  # near-duplicate slugs by judgment.
  if [ -z "$slug" ] || grep -qxF -- "$slug" <<<"$branches"; then
    log "skip '$title': slug '$slug' empty or already a branch"
    continue
  fi

  draft=$(ask_llm "以下の TODO ノートについて、着手するための実装方針の初稿を書け。
dotfiles リポジトリ（nix-darwin / home-manager）のタスクである。
出力はノート本文のみとし、次の規約に従うこと。

$conventions

元ノートへのリンク: [[$title]]

対象ノート（${title}）の中身:
$content")

  if [ "$DRY_RUN" = 1 ]; then
    printf '=== %s -> %s\n%s\n\n' "$title" "$slug" "$draft"
    dispatched=$((dispatched + 1))
    continue
  fi

  # obsidian-manager rule: AgentDrafts/ is the opt-in switch for vault
  # writes, and existing notes are never overwritten.
  draft_file="$drafts/${title//\//-}.md"
  if [ -d "$drafts" ] && [ ! -e "$draft_file" ]; then
    printf '%s\n' "$draft" >"$draft_file"
  fi

  pane=$(herdr worktree create --cwd "$REPO_DIR" --branch "$slug" --base main \
    --label "$title" --no-focus --json | jq -r '.result.root_pane.pane_id')
  # Interactive pi (no --print): --print exits after one answer, which would
  # end the worker before grilling starts.
  if ! herdr agent start "$slug" --kind pi --pane "$pane" -- --model "ollama/$MODEL"; then
    log "skip '$title': pi failed to start in pane $pane"
    continue
  fi
  prompt="実装方針だけを検討すること。コードは変更しない。
結論はこのチャットにそのまま書くこと。Obsidian vault やその他のファイルには
一切書き込まないこと。結論は簡潔に、かつ根拠(読んだファイルやコマンド結果)が
追えるようにまとめること。
初稿が ${draft_file} にある。読むだけにし、編集しないこと。
結論をまとめたら、人間のアタッチを待たずに grilling skill をロードして
即座に壁打ちを開始すること。質問ツールで待機できない環境なら、質問を
チャットに番号付きで書き出して人間の回答を待つこと。

対象ノート(${title})の中身:
${content}"
  # Trailing newline submits the prompt (same as the interactive skill).
  herdr agent prompt "$slug" "$prompt"$'\n' --timeout 600000

  tmp=$(mktemp)
  jq --arg slug "$slug" --arg title "$title" --arg backend "pi/ollama/$MODEL" \
    --arg ts "$(date -u +%FT%TZ)" \
    '. + {($slug): {title: $title, branch: $slug, backend: $backend, dispatched_at: $ts}}' \
    "$state_file" >"$tmp" && mv "$tmp" "$state_file"
  "$skills/obsidian-to-herdr-worktree/scripts/move-card.sh" "$board" "Todo" "In progress" "$title"
  log "dispatched '$title' as $slug"
  dispatched=$((dispatched + 1))
done

[ "$DRY_RUN" = 1 ] || "$skills/obsidian-livesync-sync/scripts/sync.sh"
log "done: $dispatched dispatched"
