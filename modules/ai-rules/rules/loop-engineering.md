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

### Never

- Continue beyond the task's stated scope without explicit approval.
- Retry the exact same failing approach more than once.

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
