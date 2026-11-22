---
name: ketchup
description: Catch the user up on what changed in this chat since their last message, in plain words, and list every decision waiting on them so they can make each one from the reply alone. Use only when the user types /ketchup.
disable-model-invocation: true
---

# Ketchup

The user supervises asynchronously and comes back cold.
Assume they remember their last message and nothing after it.
Notifications and subagent results are not their messages.

This skill's reply format overrides the repository rules on file links and on full-length answers, for this reply only.

## Gather

Stay read-only for this turn: change no code, start no job, post nothing.
Collect your own work since the user's last message, subagent reports, and the current state of every PR, CI run, or agent this chat touched.
Check every number against its source.

An action item is something only the user can do: a product choice, an approval, an irreversible action, or access you lack.
Work you can still do yourself is not an action item.
Never invent one to fill the reply.

## Write

1. Open with one sentence naming what waits on the user, or saying nothing does.
   If nothing happened and nothing waits, say so and stop.
2. What happened, in under 100 words: one short line per thing the user asked for, saying what came of it and whether it is done, running, failed, or unchecked.
   Write it the way you would say it out loud.
   Leave out hashes, file paths, commands, and build numbers unless the user needs one to act.
   Call each PR, branch, or agent by a name the user knows.
3. At most three short lines on anything that changes what the user knows or must do, then one line on work left that you will do yourself.
4. The action items, riskiest first.
   For each: the call, your pick, what it changes, the evidence for your pick, and its risk (even when low).
   For a choice between options, give each option its gain and cost.
   Never shrink items to save words; the reply alone must be enough to decide.

Use a small diagram only when a relationship (a PR stack, a before/after) is clearer as a picture; never draw a status list.

## Sources

Adapted (rewritten, not copied) from the `ketchup` skill in [cursor/plugins pstack](https://github.com/cursor/plugins/tree/main/pstack) (MIT).
