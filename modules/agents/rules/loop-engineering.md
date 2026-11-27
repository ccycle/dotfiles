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
- Investigation tasks: every assertion must be backed by a measurement command that was run and re-run before finalizing (see the `measure-first` skill)
- User-visible behavior (env vars, shell config, deployed services, GUI): verify from the user's vantage point — a fresh shell, the running service, the actual URL — not just the code edit. If a step you cannot perform remains (re-login, app restart), say so explicitly instead of reporting done.

Before declaring done, run every verification command from the criteria and report each result with the actual output.
If any criterion fails, iterate or escalate — never declare done with failing criteria.

Exceptions:

- Delegated work: when an agent is started with a kickoff that states the bar (the checks the work must pass), that bar is the whole bar.
  Do not add checks, gates, or review rounds above it, including the minimum criteria above.
  With no bar stated, the minimum criteria above apply.
- Throwaway prototypes built outside the repository follow the `prototype` skill instead of these criteria.

## Long Autonomous Runs

Applies only when the user explicitly starts a long-running loop (`/loop`, "keep going until X", "run overnight").

- State the exit condition as a checkable predicate before the first iteration, and never relax it to declare victory.
- Each iteration makes the smallest change the evidence justifies, checks it against the predicate, commits if the predicate moved, and reverts if it did not.
- A plateau is not a stop: pivot to a different approach and keep going.
  The "report after 3 failed attempts" rule below does not apply; surface only a genuine dead end, with what was tried.
- Fix discoveries that block or support the goal (broken skills, related bugs, flaky checks) yourself, each in its own branch and PR; opening those PRs needs no confirmation.
  Merging, deploying, and the other irreversible actions below still do.
- Record each iteration with the `show-me-your-work` skill.

## Autonomy Boundaries

### Proceed, then explain

The user supervises asynchronously.
For reversible work, do not ask "should I do X?": do X, then explain what was done and why in the final report, so the user can course-correct after the fact.
A wrong reversible decision costs less than a blocked agent.

- Fix syntax errors, formatting issues, and linting violations.
- Retry a failure up to 2 times, each time with a different approach.
  Never retry the same command or approach verbatim.
- Run diagnostic commands (read logs, check status, inspect state) to understand failures.
- Adjust the implementation approach as needed to meet the goal.
- When a requirement is ambiguous, pick the most reasonable reading, state the assumption in the report, and proceed.
  When an experiment can settle the question, run it instead of guessing.
  This covers how to solve a known problem, not which problem to solve: a solution-only instruction gets the hearing step of "Problem Before Solution" in the global rules first.
- Edit files outside the initially named ones when the goal needs it, and list them in the report.

### Confirm first (irreversible or security-sensitive only)

- Destructive or hard-to-reverse actions: deleting worktrees, branches, files, volumes, or keys; killing processes; force pushes; `docker compose down` when volumes may be lost; merging or deploying.
  First list exactly what will be affected, then wait for confirmation.
  Exempt: files strictly below `/tmp`, `/private/tmp`, or the macOS per-user temporary directory that you or your session created.
  Delete those without asking, as a standalone `rm` with literal absolute paths: the Claude Code hook approves only that form, so chaining, variables, and redirections still prompt.
- Sending anything to an external service or person, except PRs opened during a Long Autonomous Run.
- Changes to security-sensitive files (secrets, SSH config, GPG config, auth tokens).
- Product direction: what to build is the user's call; how to build it is not.
- After 3 failed attempts at the same subproblem, report what was tried and the leading hypothesis instead of continuing blindly.

### Never

- Retry the exact same failing approach more than once.
- Remediate (restart, delete, kill, rewrite) during a task framed as investigation or verification only. Report findings and stop; act only when asked.

## Progress Reporting

Silent stretches are indistinguishable from a hang. The user should never have to ask "are you stuck?" or "is it still running?".

- Before starting a command expected to take more than ~30 seconds (builds, downloads, e2e tests, rebuilds), say what you are running and why.
- Prefer running long commands in the background, then poll and report intermediate status instead of blocking silently.
- When blocked on something only the user can do (sudo password, `rbw unlock`, GUI click, passkey touch, interactive auth), stop and say so explicitly: name the exact command or action, and use the interactive question tool where available (see the `ask-me-to-do` skill). Never wait silently for input.
- Before concluding a sudo command needs a password, run that exact command with `sudo -n`.
  Hand it to the user only if it fails with "a password is required".
  Never infer from a different command such as `sudo -n true`.
- When `$SSH_TTY` or `$SSH_CONNECTION` is set, the user is not at the Mac's screen.
  For a password or unlock step, ask them to run the command in their terminal and type the password there (sudo prompt, pinentry-curses).
  Never ask for Touch ID, a GUI dialog click, or any other action on the physical Mac.
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
