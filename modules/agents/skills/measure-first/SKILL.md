---
name: measure-first
description: Mandatory workflow for investigation tasks. Use when the user asks to investigate, debug, root-cause, verify, check the cause of, or confirm the current state of a system, service, file, config, or behavior. Requires starting from measurement (creating the measurement if none exists), invoking the measure-reviewer subagent before finalizing, and ending the answer with the MEASURE-REVIEW marker. Do not answer investigation questions from memory or speculation.
---

# Measure First: Investigation Workflow

Investigation tasks must start from measurement, not memory. An unsupported
assertion is a bug in the answer. Follow this order for every investigation
task.

## 1. Decompose the question into checkable claims

Restate the question as one or more claims that can each be confirmed or
refuted by a concrete observation. If a question cannot be decomposed this way,
say so and ask for a scoping decision — do not answer from memory.

## 2. Assign each claim a measurement

For every claim, name the exact observable and the command that reads it.
Preferred sources, in order:

1. A local measurement: running a command, reading a file, querying an API
   (for example `docker compose -p <project> ps`, `curl <metrics endpoint>`,
   `logcli query`, `nix eval`, reading the relevant file).
2. An existing artifact: a smoke-test script, a monitoring query, a check.
3. **If no measurement exists, create one** (script, query, or smoke test) and
   run it. Creating the measurement is in scope for investigation tasks.

If a claim genuinely cannot be measured, mark it `unverifiable` and say why —
never substitute a guess.

## 3. Measure

Run the measurements. Record the actual output verbatim as evidence.

## 4. Draft the answer in claim / evidence / confidence schema

For each claim:

- **Claim** — the assertion.
- **Evidence** — the command run and its actual output, or `file:line` with the
  read content. No evidence line means no claim.
- **Confidence** — `high` / `medium` / `low`, or `unverifiable`.

A claim with no evidence must be deleted or relabeled, never shipped.

## 5. Invoke the measure-reviewer subagent (mandatory)

Before presenting the final answer, call the `measure-reviewer` subagent via
the task tool and pass your draft (claims + evidence + measurement commands).

- Claude Code: task tool with the `measure-reviewer` agent.
- opencode: task tool with `subagent_type: "measure-reviewer"`.

The reviewer re-runs the measurements itself and returns APPROVED or a list of
issues. Do not skip this step for small or obvious tasks.

## 6. Iterate on issues

Address every issue the reviewer raises (re-measure, correct, or relabel as
`unverifiable`) and re-invoke the reviewer. If the second review still fails,
report the reviewer's issues verbatim to the user and stop.

## 7. Finalize with the marker

End the final answer with the exact line:

```
MEASURE-REVIEW: approved
```

Keep it exactly as written, on its own line.
