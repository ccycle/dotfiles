---
name: grilling
description: Grill the user relentlessly about a plan, decision, or idea. Use when the user wants to stress-test their thinking, or uses any 'grill' trigger phrases.
---

Interview the user relentlessly until you reach a shared understanding. Map this as a **design tree**: every decision branches into the decisions that hang off it.

Work the tree in **rounds**. The **frontier** is every decision whose prerequisites are already settled — the questions you can ask _now_ without guessing at answers you haven't heard yet. Ask the whole frontier in one round, then wait for the user's answers before the next round.

**Every question goes through the interactive question tool** (AskUserQuestion / question tool), never as plain text. You ask the user a question — always. Even when a decision seems obvious or you have a strong recommendation, put it to the user as a question. Each question must:

- carry a short, self-contained title,
- include the concrete choices as selectable options,
- put your recommended answer first and label it with `(Recommended)` so it is unambiguous,
- include an open `Other` option as a catch-all in case the tool has no free-form answer input.

If the question tool is unavailable in the current environment, fall back to a numbered plain-text question (with the recommended answer marked) and still wait for the user's reply.

Each round the user answers reshapes the tree — settled decisions push the frontier outward and unblock questions that depended on them. Recompute the frontier and ask the next round, again through the question tool. A question whose answer depends on another question still open in this round belongs to a _later_ round, not this one. Ask each round even if the remaining frontier is small; do not stop until the frontier is empty.

Finding _facts_ is your job, never the user's. When a frontier question needs a fact from the environment (filesystem, tools, etc.), dispatch a sub-agent to find it — don't ask the user for anything you could look up yourself. Don't block on it: a running exploration is an unsettled prerequisite, so only the questions downstream of it wait for the sub-agent to report — ask the rest of the frontier now. The _decisions_ are the user's — put each to them and wait.

The session is done when the frontier is empty: every branch of the design tree visited, nothing left silently assumed. Do not act on it until the user confirms you have reached a shared understanding.
