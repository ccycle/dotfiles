---
name: herdr-tab-handoff
description: Inside Herdr, when you cannot run a shell command yourself, pre-type it into a new Herdr tab and let the user review it and press Enter. Use when a command was denied by the permission check or a safety rule (even if the user already approved it in conversation), needs sudo or a password, needs an interactive TTY or interactive auth (e.g. `rbw unlock`, `gcloud auth login`), or is long-running and the user wants to watch it. Requires HERDR_ENV=1.
---

# Herdr Tab Handoff

Prepare a command in a separate Herdr tab, typed but not executed, so the user
can review it and press Enter themselves.
This is the Herdr-native form of the "human-only action" case in
[ask-me-to-do](../ask-me-to-do/SKILL.md); follow that skill for how to phrase
the question.

## The one rule that must not bend

**Never press Enter for the user.**
Do not use `herdr pane run`, `herdr pane send-keys ... enter`, a trailing
newline in `send-text`, or any other way of submitting the typed line.

When the reason you could not run the command is a permission denial or a
safety check, executing it through another pane would circumvent that check.
The user reading the exact command and pressing Enter is the entire point of
this skill, not a formality.
The same flow applies to the other cases (sudo, interactive prompts, long
runs): you type, the user executes.

## Prerequisite

```bash
test "${HERDR_ENV:-}" = 1
```

If this fails, you are not inside Herdr.
Fall back to the `!`-prefix suggestion from
[ask-me-to-do](../ask-me-to-do/SKILL.md) and do not use this skill.

## Steps

1. **Create an unfocused tab** with a short purpose label, in the caller's
   workspace and directory.
   Read the IDs from the JSON; never predict them.

   ```bash
   out=$(herdr tab create --workspace "$HERDR_WORKSPACE_ID" --cwd "$PWD" --label <short-purpose> --no-focus)
   tab=$(printf '%s' "$out" | jq -r .result.tab.tab_id)
   pane=$(printf '%s' "$out" | jq -r .result.root_pane.pane_id)
   ```

2. **Wait for the shell prompt** so the text does not race shell startup.

   ```bash
   herdr pane wait-output "$pane" --regex '\S' --timeout 10000
   ```

3. **Type the exact command without Enter.**
   Pass it as one argument.
   If it contains single quotes, quote it so the typed line is byte-for-byte
   what you intend.
   Never type secret values; let the command fetch them, or let the user type
   them at the prompt.

   ```bash
   herdr pane send-text "$pane" '<exact command>'
   ```

4. **Ask the user to run it** with AskUserQuestion: name the tab label, show
   the exact command, and tell them to switch to the tab, review it, and
   press Enter.
   Offer options such as `Pressed Enter, it finished (Recommended)` and
   `Not running it`.

5. **Read the result** after they answer.

   ```bash
   herdr pane read "$pane" --source recent-unwrapped --lines 50
   ```

   Then verify the outcome independently with your own read-only commands
   (e.g. `ls`, `df`, `git status`), interpret it yourself, and report.
   Never ask the user to summarize the output.

6. **Close only the tab you created**, once you have what you need:

   ```bash
   herdr tab close "$tab"
   ```

   If the user chose not to run it, still close the tab.
   If the command is still running, or the user wants to keep the tab, leave
   it open and say so.
