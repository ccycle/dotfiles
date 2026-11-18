---
name: e2e-test-opencloud
description: Run a browser-driven E2E test of OpenCloud's passkey (Pocket ID) login and file upload, against an isolated per-worktree stack — never production.
---

# OpenCloud E2E Test (Passkey Login + Upload)

Runs a real Playwright browser through OpenCloud's OIDC login redirect to
Pocket ID, performs an actual WebAuthn passkey registration and login via
Chrome DevTools Protocol's virtual authenticator, then uploads a file and
asserts it lands on the host filesystem under the OpenCloud posix
driver's personal-space directory. The login ceremony is the part a Nix
build check or a health-endpoint smoke test structurally cannot exercise.

This never touches the real `services.pocket-id` / `services.opencloud`
instances. It brings up a separate, isolated docker-compose stack (same
images and env wiring as production), fronted by its own dedicated Caddy
process, scoped to the current git worktree. See [modules/opencloud/tests/e2e/design.md](../../../modules/opencloud/tests/e2e/design.md)
for the full rationale.

## Usage

Run from anywhere inside the repository (any worktree):

```bash
.agents/skills/e2e-test-opencloud/scripts/run.sh
```

It runs unattended: no `sudo`, no browser setup, no pasted key, so it
works with stdin closed.

While running, both services are also reachable over HTTPS from other
devices on the tailnet (same URLs the script prints) for manual visual
verification. Expect a certificate warning there: the test Caddy signs
with its own per-worktree CA, which nothing outside the suite trusts.

## What It Does

1. Picks free ports, brings up an isolated `pocket-id` + `opencloud`
   docker-compose stack (project name derived from the worktree's
   directory name, matching `.agents/skills/vm-verify`'s VM-naming
   convention), and starts a dedicated Caddy process fronting both.
2. On a worktree's first run, bootstraps Pocket ID through its admin API
   with a generated per-worktree `STATIC_API_KEY` (stored in the
   gitignored `.env`): user group, role claim, OIDC client.
3. Finds-or-creates a stable `e2e-test-runner` user via Pocket ID's admin
   API, registers a fresh passkey for it via a CDP virtual authenticator,
   confirms login through OpenCloud's OIDC redirect succeeds, uploads a
   file via the UI, and asserts it appears under the host's
   `user-files/e2e-test-runner/`.
4. Publishes the Playwright HTML report to `modules/static-reports`'s
   `dataDir` under `<branch-slug>/opencloud/` (pruned after 14 days of
   inactivity) — after this repo's `services.staticReports` module has
   been applied via `darwin-rebuild switch`, it's browsable at
   `https://reports.<hostname>.internal/<branch-slug>/opencloud/` from
   any device on the tailnet after a Pocket ID passkey login (see
   [modules/static-reports/design.md](../../../modules/static-reports/design.md) for
   why this is the only way to get an ad-hoc report reachable from
   another device without an ACL change — `tailscale serve` and
   arbitrary ports
   don't work on this host).
5. Stops the containers and the test Caddy (data persists).

## When to Use

- After changing `modules/opencloud/` or `modules/pocket-id/` OIDC/auth
  wiring, to confirm the passkey login flow and basic file operations
  actually still work end-to-end — something `nix flake check` and
  `smoke-test-opencloud` (container/health/HTTPS only) can't verify.
- To visually inspect the isolated instance from another device.

## Known Constraints

- **Never delete the pocket-id test user out-of-band (e.g. via `curl`)
  without also wiping `modules/opencloud/tests/e2e/.state/opencloud/`** — doing so once
  during this suite's own development left OpenCloud holding orphaned
  internal state and made the personal space stop appearing (see
  [modules/opencloud/tests/e2e/design.md](../../../modules/opencloud/tests/e2e/design.md)'s debugging note). The test code itself never
  does this — identity is stable, not disposable — so this only matters
  if manually poking at pocket-id's state while debugging.
- Docker/OrbStack must be running.
