---
name: reasoning
description: Structured problem-solving loop for complex, ambiguous, or multi-step tasks, including debugging and root-cause analysis. Use when a task has unclear scope, spans multiple files or systems, requires investigation before action, or when previous attempts have failed. Covers goal clarification, decomposition, evidence gathering, hypothesis testing, and self-verification.
---

# Reasoning: A Problem-Solving Loop

A model-agnostic operating procedure for solving nontrivial tasks. It assumes
only generic capabilities: reading files, running commands, and searching.
Follow the phases in order, but return to an earlier phase whenever new
evidence invalidates its output.

## 1. Clarify the Goal Before Touching Anything

- Restate the task in your own words: what changes, for whom, and why.
- Define observable "done" criteria — something you can check by reading a
  file, running a command, or exercising the behavior. "The test passes" is a
  criterion; "the code is better" is not.
- Surface implicit constraints: conventions in the surrounding code,
  compatibility requirements, things the user did not say but the environment
  implies.
- If the request is ambiguous in a way that changes what you would build, ask.
  Otherwise state your interpretation explicitly and proceed — do not silently
  guess.

## 2. Maintain a Fact/Assumption Ledger

Every statement you rely on is in exactly one of three states:

| State | Meaning | Allowed use |
|---|---|---|
| Verified | You observed it: read the file, ran the command, saw the output | Build on it freely |
| Assumed | Plausible but unchecked | Build on it only if cheap to undo; label it |
| Unknown | You have no evidence either way | Investigate before depending on it |

Rules:

- Never let an assumption silently upgrade to a fact. Either verify it or keep
  the label.
- Before claiming a file contains something, read it. Before claiming a
  command behaves some way, run it. Before claiming something does not exist,
  search for it.
- When you catch yourself writing "should", "probably", or "likely" about the
  current state of the system, that is an assumption — verify it or mark it.

## 3. Decompose by Verifiability

- Split the problem into subproblems, each of which can be independently
  confirmed as done or correct.
- Order the subproblems so the cheapest information-gaining step comes first.
  Prefer steps that could invalidate the whole approach early — discovering a
  dead end after step 1 is cheap; after step 9 it is expensive.
- If a subproblem cannot be verified in isolation, that is a sign the
  decomposition is wrong — re-split it.

## 4. Investigate by Competing Hypotheses

When something is unknown or broken:

- Write down at least two candidate explanations before investigating. A
  single hypothesis invites tunnel vision: every observation gets bent to
  confirm it.
- Choose the next observation by how well it *discriminates* between the
  candidates at the lowest cost — ideally one command or one file read that
  would produce a different result under each hypothesis.
- After each observation, update the whole set: eliminate contradicted
  hypotheses, add new ones the evidence suggests. Do not keep testing a
  favorite that the evidence has already killed.
- Distinguish "this fix worked" from "the symptom disappeared". If you cannot
  explain *why* the fix works, the root cause is still unknown.

## 5. Read Before Writing

- Before creating anything new, search for existing implementations, patterns,
  and utilities that already solve part of the problem. Imitate the
  surrounding code's structure, naming, and idioms.
- Surrounding code is evidence about constraints nobody told you: if every
  sibling module does X, there is probably a reason — find it before
  deviating.

## 6. Act in Reversible Increments

- Take small steps that can each be verified before building on them. One
  verified step is worth more than five stacked unverified ones.
- Before any hard-to-reverse action (deleting, overwriting, pushing,
  deploying), re-check that the evidence supports that *specific* action. A
  situation that pattern-matches a known problem may have a different cause.
- If a step fails, do not immediately retry it verbatim. The failure is new
  evidence — feed it back into the ledger first.

## 7. On Contradiction, Stop and Re-Derive

- When an observation contradicts the current plan or model of the problem,
  do not patch around it. The contradiction is the most valuable information
  you have.
- Go back to the ledger: which "verified" fact was actually an assumption?
  Revise the hypothesis set and the plan from there.
- Two or more failed fixes in a row means the model of the problem is wrong,
  not that the next patch will work. Widen the investigation instead of
  narrowing it.
- For concrete retry limits and escalation policy, see `~/.claude/rules/loop-engineering.md`.

## 8. Self-Review Before Declaring Done

- Re-read every claim in your final answer and check that each one is backed
  by an observation from this session. Verify or relabel anything that is not.
- Exercise the change end-to-end against the "done" criteria from phase 1 —
  actually run the behavior, not just a compiler, linter, or type check.
- Report outcomes faithfully: if a test fails, say so with the output; if a
  step was skipped, say that. Never report success with hidden caveats.

## 9. Calibrated Language

- Mark unverified statements as such: "unverified, but likely X" — never
  present an assumption as fact.
- Prefer "X, because I observed Y" over bare assertions.
- When a decision is yours to make, give one recommendation with the reason,
  not a survey of options.
- State what you did not check. A precise boundary of your verification is
  more useful than an impression of completeness.
