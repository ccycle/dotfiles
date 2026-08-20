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
process, scoped to the current git worktree. See `tests/e2e/design.md`
for the full rationale.

## Usage

Run from anywhere inside the repository (any worktree):

```bash
.agents/skills/e2e-test-opencloud/scripts/run.sh
```

While running, both services are also reachable over HTTPS from other
devices on the tailnet (same URLs the script prints) — useful for manual
visual verification, or for completing the one-time passkey bootstrap
below from a different device.

## First Run In A New Worktree

Pocket ID has no way to create its first admin account or register a
passkey without a real browser and authenticator — this is a Pocket ID
constraint, not something this suite works around (matches production;
see `modules/pocket-id/design.md`). The first `run.sh` in a given
worktree will print a URL and pause, asking you to:

1. Open the printed `/setup` URL (locally, or from any other tailnet
   device — same URL either way) and create the admin account + register
   a passkey with a real authenticator.
2. Create an API key under Settings → Admin → API Keys and paste it back
   into the terminal.

Everything else (OIDC client, user group, role claim) is then automated.
This only happens once per worktree — the isolated stack's data
directory (`tests/e2e/.state/`, gitignored) persists across runs even
though the containers themselves stop between runs.

The first run also needs `sudo` once, to copy production's internal CA
root cert+key so the test Caddy's certificates are already trusted (see
`tests/e2e/design.md`).

## What It Does

1. Picks free ports, brings up an isolated `pocket-id` + `opencloud`
   docker-compose stack (project name derived from the worktree's
   directory name, matching `.agents/skills/vm-verify`'s VM-naming
   convention), and starts a dedicated Caddy process fronting both.
2. Bootstraps Pocket ID on first run for this worktree (see above).
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
    `modules/static-reports/design.md` for
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
  without also wiping `tests/e2e/.state/opencloud/`** — doing so once
  during this suite's own development left OpenCloud holding orphaned
  internal state and made the personal space stop appearing (see
  `tests/e2e/design.md`'s debugging note). The test code itself never
  does this — identity is stable, not disposable — so this only matters
  if manually poking at pocket-id's state while debugging.
- `sudo` is needed once per worktree, to copy production's internal CA
  root cert+key (read-only reuse of its identity, never a live-shared
  process — see `tests/e2e/design.md`).
- Docker/OrbStack must be running.
