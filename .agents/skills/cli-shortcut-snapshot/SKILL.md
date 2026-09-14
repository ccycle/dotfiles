---
name: cli-shortcut-snapshot
description: VHS-based CLI shortcut test and recording. --check mode runs structural assertions against the TUI's text snapshot (replaces the former pytest Tier B). Default mode records .webm for human review.
---

# CLI Shortcut Snapshot

Tests and records a CLI's configured shortcut actually firing, using VHS
tape files. Two modes:

- **`--check`** (automated): runs the tape, extracts the last text frame,
  and asserts structural markers from a `.assertions` file (e.g. "reviewr
  panel opened", "sidebar rendered"). Replaces the former pytest-based
  Tier B.
- **default** (visual): records a `.webm` video and publishes it for human
  review.

See `tests/cli-shortcut-snapshot/design.md` for the full rationale,
including why the target CLI must be launched as its own foreground process.

## Usage

```bash
# Automated test (structural assertions)
.agents/skills/cli-shortcut-snapshot/scripts/run.sh --check [path/to/*.tape]

# Visual recording for human review
.agents/skills/cli-shortcut-snapshot/scripts/run.sh [path/to/*.tape]
```

Defaults to `tests/cli-shortcut-snapshot/tapes/herdr-reviewr-toggle.tape`.

## Adding a New Test

1. Write a `.tape` file in `tests/cli-shortcut-snapshot/tapes/` that
   launches the target CLI and sends the key sequence.
2. Write a `.assertions` file next to it (same basename) with one
   extended-regex pattern per line — every pattern must appear in the
   last rendered text frame for the test to pass.
3. Run `--check` to verify.

## What --check Does

1. Injects an `Output <tmp>.txt` directive into a temporary copy of the
   tape (the original tape stays unchanged).
2. Runs VHS inside the `cli-shortcut-snapshot` Nix devShell.
3. Extracts the last complete text frame from the `.txt` output (VHS
   concatenates all rendered frames separated by `─` lines).
4. Greps each pattern from the `.assertions` file against that frame.
5. Reports PASS (all patterns found) or FAIL (with the missing patterns
   and the full last frame for debugging).

## Known Constraints

- Manual-only — not wired into CI. Run on demand.
- For herdr, the tape must launch `herdr --session $SESSION_NAME` as its
  own foreground process. Remote control (`herdr pane send-keys`/
  `terminal attach`) does not reach herdr's keybinding router.
- `scripts/run.sh` strips `HERDR_*` env vars before invoking VHS to
  bypass herdr's nested-herdr guard — safe because the recording always
  uses a disposable, isolated named session.
