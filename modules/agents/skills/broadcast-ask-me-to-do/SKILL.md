---
name: broadcast-ask-me-to-do
description: Send the ask-me-to-do skill to every other Herdr agent at once. Runs only when the user types /broadcast-ask-me-to-do.
disable-model-invocation: true
allowed-tools: Bash
---

# Broadcast Ask Me To Do

Push [ask-me-to-do](../ask-me-to-do/SKILL.md) to every other live agent in the current Herdr session.

## Usage

Preview the targets first, then send:

```bash
~/.claude/skills/broadcast-ask-me-to-do/scripts/broadcast.sh --dry-run
~/.claude/skills/broadcast-ask-me-to-do/scripts/broadcast.sh
```

Show the dry-run output to the user before sending, then report the script's `sent` / `skip` / `FAILED` lines.

Agents in `working` or `blocked` state are skipped so no text lands in a running turn or an approval prompt.
Rerun the script once they settle to reach them.
