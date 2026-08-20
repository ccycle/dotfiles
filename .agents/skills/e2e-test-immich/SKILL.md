---
name: e2e-test-immich
description: Run a browser-driven E2E test of Immich's local-auth admin sign-up, photo upload, and thumbnail generation, against an isolated per-worktree stack — never production.
---

# Immich E2E Test (Local Admin Sign-Up + Upload + Thumbnail)

Drives Immich's real admin-sign-up and login APIs and a real Chromium
browser through its upload UI, then asserts on real outcomes: the
uploaded photo actually lands on the host filesystem, and Immich actually
generates a thumbnail for it (not just that the UI shows an upload
animation). `nix build`/`nix flake check` and `smoke-test-immich`
(container/health-endpoint only) can't verify any of this. See
`tests/e2e-immich/design.md` for the full rationale, including why this
suite deliberately uses local auth instead of OIDC/passkey.

This never touches the real `services.immich` instance on
`mac-mini-m4-pro` or its data. It brings up a separate, isolated
docker-compose stack (project name derived from the worktree's directory
name), with its own throwaway ports and data/upload directories.

## Usage

Run from anywhere inside the repository (any worktree):

```bash
.agents/skills/e2e-test-immich/scripts/run.sh
```

## What It Does

1. Brings up an isolated Immich stack (server, machine-learning, redis,
   database, both exporters), waits for `/api/server/ping`.
2. Creates the first admin user via `POST /api/auth/admin-sign-up` (no
   OIDC/browser needed for this step - see design.md on why OIDC/passkey
   coverage stays concentrated in `e2e-test-opencloud` instead).
3. Logs in through the real browser UI (`/auth/login`), handling
   whatever one-time redirect a brand-new admin can land on
   (`/auth/change-password`, `/auth/onboarding`) before landing on the
   authenticated app.
4. Uploads a real (valid, minimal) JPEG via the UI's upload button and
   file chooser, then confirms via the API - not by re-deriving Immich's
   internal path scheme - that the asset both landed on the host
   filesystem under `services.immich.uploadDir` and has a generated
   thumbnail (`thumbhash` populated).
5. Publishes Playwright's own HTML report (trace: 'on', so every run
   stays inspectable in trace viewer, not just failures) to
   `modules/static-reports`'s `dataDir` under `<branch-slug>/immich/`
   (pruned after 14 days of inactivity) - after `services.staticReports`
   has been applied via `darwin-rebuild switch`, it's browsable at
   `https://reports.<hostname>.internal/<branch-slug>/immich/` from any
   device on the tailnet after a Pocket ID passkey login. Best-effort: a worktree on a host without that
   module enabled doesn't fail the test run over it.
6. Tears the stack (containers + volumes + data dirs) down completely,
   so every run starts from a clean instance - the only admin a fresh
   Immich database will ever let `admin-sign-up` create.

## When to Use

- After changing `modules/immich/compose.yaml` or `options.nix`'s
  storage/upload configuration, to confirm uploaded photos still land on
  the host filesystem and thumbnails still generate - something a build
  dry-run structurally cannot verify.
- After upgrading the pinned Immich image version, to catch API/UI
  surface changes before they hit `mac-mini-m4-pro`.

## Known Constraints

- Docker must be running.
- First run in a given worktree does `npm install` (Playwright + its test
  runner) before the suite itself starts.
- Only exercises local auth; OIDC/passkey login is never exercised here.
