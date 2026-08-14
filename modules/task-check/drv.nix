{ writeShellApplication, jq }:
writeShellApplication {
  name = "task-check";
  runtimeInputs = [ jq ];
  text = ''
    # Pull-only design (no daemon, no push notification, no p10k segment) —
    # decided after several rounds of always-on display designs turned out
    # to distract from unrelated work; see the design discussion this was
    # built from for the rejected alternatives.
    vault_dir="$HOME/Obsidian/zettelkasten"
    board="$vault_dir/Kanban (dotfiles).md"
    config_dir="$HOME/.config/dotfiles"
    config_file="$config_dir/task-check.json"
    default_stale_days=5

    mkdir -p "$config_dir"
    if [ ! -f "$config_file" ]; then
      printf '{"staleDays": %d}\n' "$default_stale_days" > "$config_file"
    fi
    stale_days=$(jq -r '.staleDays' "$config_file")

    if [ ! -f "$board" ]; then
      echo "task-check: Kanban board not found: $board" >&2
      exit 1
    fi

    extract_section() {
      awk -v heading="## $1" '
        $0 == heading { found=1; next }
        found && /^## / { exit }
        found { print }
      ' "$board"
    }

    extract_titles() {
      while IFS= read -r line; do
        case "$line" in
          *'[['*']]'*)
            title="''${line#*\[\[}"
            title="''${title%%\]\]*}"
            printf '%s\n' "$title"
            ;;
          '- [ ] '*)
            printf '%s\n' "''${line#"- [ ] "}"
            ;;
        esac
      done
    }

    # Track A: flag "In progress" cards whose linked note hasn't been
    # touched in stale_days — fact only, no self-questioning prompt.
    in_progress_titles=$(extract_section "In progress" | extract_titles || true)
    while IFS= read -r title; do
      [ -z "$title" ] && continue
      note="$vault_dir/$title.md"
      if [ -f "$note" ]; then
        mtime=$(date -r "$note" +%s)
        now=$(date +%s)
        days=$(( (now - mtime) / 86400 ))
        if [ "$days" -ge "$stale_days" ]; then
          echo "停滞: 「''${title}」が ''${days} 日更新されていません(閾値: ''${stale_days} 日)"
        fi
      fi
    done <<< "$in_progress_titles"

    # Track B: recommend exactly one next action — Todo before Backlog,
    # topmost card in each section wins. No AI inference, board order only.
    todo_titles=$(extract_section "Todo" | extract_titles || true)
    backlog_titles=$(extract_section "Backlog" | extract_titles || true)
    next_action=$(printf '%s\n%s\n' "$todo_titles" "$backlog_titles" | grep -v '^$' | head -n1 || true)

    if [ -n "$next_action" ]; then
      if printf '%s\n' "$todo_titles" | grep -qxF "$next_action"; then
        echo "次の一手: 「''${next_action}」(Todoの中で一番上に書かれているため)"
      else
        echo "次の一手: 「''${next_action}」(Backlogの中で一番上に書かれているため)"
      fi
    fi
  '';
}
