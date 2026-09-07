---
description: Loop engineering rules for agent task lifecycle, autonomy boundaries, and token efficiency
alwaysApply: true
---

# Loop Engineering

## Completion Criteria Protocol

Before starting implementation, state completion criteria as checkable assertions.
Each assertion must be verifiable by reading a file, running a command, or observing behavior.

Minimum criteria by task type:

- Nix changes: `nix flake check` passes (or `/verify-change` skill)
- Service changes: the relevant smoke-test skill passes
- All changes: name the specific files created or modified
- Investigation tasks: every assertion must be backed by a measurement command that was run; the answer must carry the `measure-reviewer` marker (`MEASURE-REVIEW: approved`)
- User-visible behavior (env vars, shell config, deployed services, GUI): verify from the user's vantage point — a fresh shell, the running service, the actual URL — not just the code edit. If a step you cannot perform remains (re-login, app restart), say so explicitly instead of reporting done.

Before declaring done, run every verification command from the criteria and report each result with the actual output.
If any criterion fails, iterate or escalate — never declare done with failing criteria.

## Autonomy Boundaries

### Act autonomously

- Fix syntax errors, formatting issues, and linting violations.
- Retry a failure up to 2 times, each time with a different approach.
  Never retry the same command or approach verbatim.
- Run diagnostic commands (read logs, check status, inspect state) to understand failures.
- Adjust the implementation approach within the stated scope of the task.

### Ask before proceeding

- After 3 failed attempts at the same subproblem.
- Changes that would modify files outside the task's stated scope.
- Changes to security-sensitive files (secrets, SSH config, GPG config, auth tokens).
- Requirements that are ambiguous in a way that changes what to build.
- Destructive or hard-to-reverse actions: deleting worktrees, branches, files, volumes, or keys; killing processes; force pushes; `docker compose down` when volumes may be lost. First list exactly what will be affected, then wait for confirmation.

### Never

- Continue beyond the task's stated scope without explicit approval.
- Retry the exact same failing approach more than once.
- Remediate (restart, delete, kill, rewrite) during a task framed as investigation or verification only. Report findings and stop; act only when asked.

## Progress Reporting

Silent stretches are indistinguishable from a hang. The user should never have to ask "are you stuck?" or "is it still running?".

- Before starting a command expected to take more than ~30 seconds (builds, downloads, e2e tests, rebuilds), say what you are running and why.
- Prefer running long commands in the background, then poll and report intermediate status instead of blocking silently.
- When blocked on something only the user can do (sudo password, `rbw unlock`, GUI click, passkey touch, interactive auth), stop and say so explicitly: name the exact command or action, and use the interactive question tool where available (see the `ask-me-to-do` skill). Never wait silently for input.
- When retries or searches take longer than expected, report what you are stuck on and what you are trying next — do not go quiet.
- When the user asks for status, answer with: what is currently running, what is blocking, and what happens next.

## Token Efficiency

### Exploration

- Use `grep`/`find` to locate relevant files before reading them.
  Never read files speculatively.
- In unfamiliar areas, read `design.md` (if it exists) before reading code files.
- For files longer than ~200 lines, read only the relevant line range.

### Nix-specific

- The directory structure mirrors the dependency graph.
  Read only the target module and its parent aggregation file.
  Read sibling modules only if the change depends on them.

### Incremental verification

- After editing a `.nix` file, run `nix-instantiate --parse <file>` on just the changed file before running full `/verify-change`.
- When checking a single profile, pass the profile name to avoid checking all profiles.

### Avoid redundant reads

- Do not re-read files just written or edited — the tool confirms success.
- On build failure, parse the error message and read only the file(s) it references.
