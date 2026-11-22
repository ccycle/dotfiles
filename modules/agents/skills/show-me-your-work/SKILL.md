---
name: show-me-your-work
description: Keep a reviewable decision trail as one TSV file, one row per decision or checkpoint, so the user can audit what an agent chose and why after the fact. Use for long or unattended work, Long Autonomous Runs, /show-me-your-work, or "keep a decision log".
---

# Show Me Your Work

Agents proceed without asking and explain afterwards, so the explanation needs a trail a reviewer can scan in a minute.
Keep exactly one log per effort.

## Format

One TSV file, one row per decision, header row first:

```text
ts	phase	decision	why	evidence	result
```

- `ts`: ISO 8601 UTC timestamp.
- `phase`: the phase or workstream.
- `decision`: what was chosen or done, one line.
- `why`: the reason in plain words.
- `evidence`: a pointer, never prose — commit SHA, PR number, `file:line`, or an artifact path.
- `result`: the outcome, such as `build passed`, `reverted`, `inconclusive`, `open`.

Every cell is a single line with no tabs.

## Logging a row

```bash
log_decision() {
  local log=$1; shift
  [ -s "$log" ] || printf 'ts\tphase\tdecision\twhy\tevidence\tresult\n' > "$log"
  local cells=("$(date -u +%Y-%m-%dT%H:%M:%SZ)")
  for c in "$@"; do cells+=("$(printf '%s' "$c" | tr '\t\n' '  ')"); done
  (IFS=$'\t'; printf '%s\n' "${cells[*]}") >> "$log"
}
log_decision "$log" <phase> <decision> <why> <evidence> <result>
```

Log forks chosen, units completed with their check result, pivots and reverts with their trigger, and blockers.
In a loop, log one row per iteration.
Skip the trivial.

When resuming a log another session wrote, read its last rows first, then add a row with phase `start` that names this session.

## Where it lives

The log is a working artifact, not a commit.
Default path: `decisions.tsv` in the session scratchpad, or `<scratchpad>/<task-slug>.tsv` when several efforts run at once.
Name the full path in the final report.

## Sources

Adapted (rewritten, not copied) from the `show-me-your-work` skill in [cursor/plugins pstack](https://github.com/cursor/plugins/tree/main/pstack) (MIT).
