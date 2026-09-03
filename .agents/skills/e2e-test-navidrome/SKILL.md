---
name: e2e-test-navidrome
description: Run a Playwright E2E test of Navidrome's web UI, Subsonic API, and music library scanning, against an isolated per-worktree stack — never production.
---

# Navidrome E2E Test (Web UI + Subsonic API + Library Scanning)

Drives Navidrome's web UI, Subsonic API, and music library scanning
through real HTTP requests and Playwright browser checks, asserting on
real outcomes: the web UI loads, Subsonic API responds, and uploaded
music files appear in the library after scanning. `nix build`/`nix flake check`
and `smoke-test-navidrome` (container/health-endpoint only) can't verify
any of this. See `tests/e2e-navidrome/design.md` for the full rationale.

This never touches the real `services.navidrome` instance on
`mac-mini-m4-pro` or its data. It brings up a separate, isolated
docker-compose stack (project name derived from the worktree's directory
name), with its own throwaway ports and data directories.

## Usage

Run from anywhere inside the repository (any worktree):

```bash
.agents/skills/e2e-test-navidrome/scripts/run.sh
```

## What It Does

1. Brings up an isolated Navidrome stack (navidrome container), waits
   for the health endpoint to respond.
2. Verifies the web UI loads and shows a login form.
3. Pings the Subsonic API and validates the XML response.
4. Places a minimal valid FLAC file in the music directory, triggers a
   scan via Subsonic API, and polls `getArtists` until the scanned
   content appears.
5. Publishes Playwright's own HTML report to `modules/static-reports`'s
   `dataDir` under `<branch-slug>/navidrome/` (pruned after 14 days of
   inactivity) — after `services.staticReports` has been applied via
   `darwin-rebuild switch`, it's browsable at
   `https://reports.<hostname>.internal/<branch-slug>/navidrome/` from any
   device on the tailnet after a Pocket ID passkey login.
6. Tears the stack (containers + volumes + data dirs) down completely,
   so every run starts from a clean instance.

## When to Use

- After changing `modules/navidrome/compose.yaml` or `options.nix`'s
  storage/music configuration, to confirm music files still scan
  correctly — something a build dry-run structurally cannot verify.
- After upgrading the pinned Navidrome image version, to catch API/UI
  surface changes before they hit `mac-mini-m4-pro`.

## Known Constraints

- Docker must be running.
- First run in a given worktree does `npm install` (Playwright + its test
  runner) before the suite itself starts.
- Only exercises Subsonic API and web UI; OIDC/passkey login is not
  exercised (ND_EXTAUTH is disabled in the test stack).
