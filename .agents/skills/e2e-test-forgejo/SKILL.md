---
name: e2e-test-forgejo
description: Run a Playwright E2E test (trace-viewer-inspectable API calls) of Forgejo's CI-runner, branch-protection, and backup automation, against an isolated per-worktree stack — never production.
---

# Forgejo E2E Test (Runner + Branch Protection + Backup)

Drives the real `forgejo`/`forgejo-cli`/`forgejo-runner` binaries and the
real Forgejo API the same way `modules/forgejo/options.nix`'s launchd
bootstrap jobs do, then asserts on real outcomes: a runner actually
connects and executes a workflow, branch protection actually rejects a
force-push, a `forgejo dump` file actually lands where the backup job
expects it. `nix build`/`nix flake check` only prove the Nix evaluates -
this is the part that proves the automation works. See
`tests/e2e-forgejo/design.md` for the full rationale, including two
non-obvious fixture gotchas it took a live failure to find.

Built on `@playwright/test` with no browser involved: every Forgejo REST
API call (repo creation, status polling, branch-protection create/read)
goes through Playwright's `request` fixture specifically so it's captured
by `trace: 'on'` and inspectable afterward in **trace viewer's Network
tab** - exact request/response bodies and timing, not just a pass/fail
line. `docker compose exec` calls (admin bootstrap, runner registration,
`forgejo dump`) aren't HTTP, so they're not traced the same way, but
still show in the report's step tree with their stdout attached. See "Why
Playwright, With No Browser" in `tests/e2e-forgejo/design.md`.

This never touches the real `services.forgejo` instance on
`mac-mini-m4-pro` or its data. It brings up a separate, isolated
docker-compose stack (project name derived from the worktree's directory
name), with its own throwaway ports, volume, and data directory. See
"Why Isolated" in `tests/e2e-forgejo/design.md` for why this matters -
a herdr worktree checked out on that same host shares its Docker daemon
with the real instance.

## Usage

Run from anywhere inside the repository (any worktree):

```bash
.agents/skills/e2e-test-forgejo/scripts/run.sh
```

## What It Does

1. Brings up an isolated Forgejo container, waits for it to be healthy.
2. Bootstraps a local admin account + API token (no OIDC/browser needed -
   none of the automation under test authenticates through Pocket ID).
3. Creates a test repo via a traced API call, pushes a minimal Forgejo
   Actions workflow.
4. Registers and starts a host-execution runner exactly the way
   `forgejo-runner-bootstrap` does.
5. Pushes the workflow, waits for it to run, and **logs the real
   commit-status context string Forgejo Actions reports** (also attached
   to the report) - compare this against
   `branchProtections.*.statusCheckContexts` in
   `modules/mac-mini-m4-pro/darwin.nix` whenever the workflow's name or
   job id changes, since a mismatched context permanently blocks merges.
6. Applies branch protection via the same (traced) API call
   `forgejo-branch-protection-bootstrap` uses, reads it back, and
   confirms a force-push is rejected.
7. Runs the exact `forgejo dump` invocation the backup job uses, and
   tests the retention-pruning logic against seeded fake generations.
8. Tears the container and its volume down, so every run starts from a
   clean instance (unlike `tests/e2e`'s OpenCloud suite, nothing here
   needs an expensive one-time manual bootstrap worth preserving between
   runs - see `tests/e2e-forgejo/design.md`).
9. Publishes Playwright's own HTML report (step tree, timing, and the
   trace.zip for every step - open it directly from the report to reach
   trace viewer) to `modules/static-reports`'s `dataDir` under a
   subdirectory named for the current worktree - after
   `services.staticReports` has been applied via `darwin-rebuild switch`,
   it's browsable at `https://reports.<hostname>.internal/<worktree-name>/`
   from any device on the tailnet. Best-effort: a worktree on a host
   without that module enabled doesn't fail the test run over it.

## When to Use

- After changing `modules/forgejo/options.nix`'s runner, branch-protection,
  or backup logic, to confirm the actual Forgejo/forgejo-runner CLI and
  API calls still work - something a build dry-run structurally cannot
  verify.
- After upgrading the pinned Forgejo image version, to catch CLI/API
  surface changes before they hit `mac-mini-m4-pro`.
- Whenever `.forgejo/workflows/verify.yaml`'s workflow name or job id
  changes, to re-confirm the commit-status context string - open the
  published report's trace to read the exact value off a real API
  response instead of guessing.

## Known Constraints

- Docker must be running.
- First run in a given worktree does `npm install` (Playwright + its test
  runner) before the suite itself starts.
- Uses the registry's `nixpkgs` (not this repo's pinned flake input) for
  `forgejo-runner`/`yq-go` - see `tests/e2e-forgejo/design.md`.
