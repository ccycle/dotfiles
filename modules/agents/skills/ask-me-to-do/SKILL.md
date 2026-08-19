---
name: ask-me-to-do
description: When you need something from the user — a decision, or an action only they can perform (GUI clicks, physical steps, interactive auth, reading a private dashboard) — minimize their cognitive load instead of asking an open-ended plain-text question. Use whenever you are about to ask the user what to do next, or need them to execute something your tools can't reach and report the result back.
---

# Ask Me To Do

Whenever you need something from the user, never leave it as an open
plain-text question when a narrower form is available. There are two
distinct situations, and each has its own narrow form.

## 1. Decision needed (you don't know what to do next, or there's a real choice)

Use the interactive question tool (AskUserQuestion), never plain text:

- Short, self-contained title per question.
- Concrete, mutually exclusive options.
- Your recommended choice first, labeled `(Recommended)`, whenever you have
  one.
- Rely on the tool's built-in free-form escape — don't add your own "other"
  option.

Batch every question you can currently ask into one round rather than
asking one at a time and waiting between each.

## 2. Human-only action needed (something your tools can't do)

This is delegation, not a question — GUI clicks, physical steps,
interactive auth, reading a private dashboard, anything outside your tool
reach. Structure it to minimize the user's effort and the room for error:

- Give the **exact** action: a copy-pasteable command, or a precise,
  minimal instruction ("click X", "run: `...`") — never a vague
  description like "check whether service Y is up."
- State exactly what you need back:
  - If the possible results are enumerable, present them as
    AskUserQuestion options (e.g. "did it say active or failed?").
  - If the result is inherently free text (command output, an ID, an
    error message), ask for exactly that one piece of information —
    nothing more.
- If it is a shell command the user should run in this session, suggest
  they prefix it with `!` so the output lands directly back in the
  conversation instead of being manually copy/pasted.
- Do the interpretation yourself once the raw result comes back — never
  ask the user to summarize or judge it on your behalf.

## Rules

1. Never pose an open-ended free-text question when a structured choice
   covers it.
2. Every decision-type question goes through AskUserQuestion, with a
   recommended option first whenever you have one.
3. Every delegated action is a concrete, minimal, copy-pasteable
   instruction — never vague.
4. Ask for the smallest possible piece of information back — a choice, a
   yes/no, or one specific value — never "tell me what happened."
5. Batch what you can ask now into one round; don't drip questions one at
   a time when several are already answerable.
6. If the question tool is unavailable, fall back to a numbered
   plain-text question, still narrow and with the recommendation marked,
   and wait for the reply.
