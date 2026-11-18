---
name: e2e-test-reports
description: Run a browser-driven E2E test of the static-reports Caddy forward_auth gate (oauth2-proxy + Pocket ID passkey login), against an isolated per-worktree stack — never production.
---

# Reports E2E Test (static-reports forward_auth gate)

Drives the _real_ auth chain of `modules/static-reports` end to end in a
browser: an anonymous visit to `reports.<hostname>.internal` must be
redirected through oauth2-proxy's `/oauth2/sign_in` to Pocket ID's
passkey-only login, then back to a served static file. The gate is
exercised as deployed — a test Caddy vhost that is a line-for-line
miniature of the production forward_auth Caddyfile block, a natively run
oauth2-proxy (pinned `devShells.e2e`), and a per-worktree Pocket ID
container. See [modules/static-reports/tests/e2e/design.md](../../../modules/static-reports/tests/e2e/design.md) for the full rationale,
including why this suite exists when OpenCloud/Immich/Forgejo/Grafana do
their own in-app OIDC (a `file_server` can't — hence the Caddy-level gate
that this suite proves).

This never touches the real `services.staticReports` instance, the real
`services.pocket-id`, or their data. It brings up an isolated stack
(project name derived from the worktree's directory name) with throwaway
ports, secrets, volumes, and a dedicated test Caddy.

## Usage

Run from anywhere inside the repository (any worktree):

```bash
.agents/skills/e2e-test-reports/scripts/run.sh
```

## What It Does

1. Brings up an isolated Pocket ID + test Caddy + native oauth2-proxy
   stack, waiting for pocket-id's `/healthz` and for the reports gate to
   answer (a redirect counts — that's the gate doing its job).
2. On a worktree's first run, bootstraps Pocket ID through its admin API
   with a generated per-worktree `STATIC_API_KEY` (no human step):
   registers the confidential `reports-e2e` OIDC client and captures its
   generated secret — oauth2-proxy can't start without it.
3. Proves the gate with three Playwright cases:
   - anonymous visit → redirected to pocket-id login;
   - provisioned passkey user → consent → browse listing + file read;
   - `/oauth2/sign_out` + cleared cookies → the same URL is gated again.
4. Publishes Playwright's HTML report (trace: 'on') to
   `modules/static-reports`'s `dataDir` under `<branch-slug>/reports/`
   (pruned after 14 days of inactivity) — after
   `services.staticReports` is applied via `darwin-rebuild switch`,
   browsable at
   `https://reports.<hostname>.internal/<branch-slug>/reports/` from any
   device on the tailnet after a Pocket ID passkey login. Best-effort: a
   worktree on a host without that module enabled doesn't fail over it.
5. Stops the containers, test Caddy, and oauth2-proxy (data persists,
   so later runs reuse the bootstrapped client).

## When to Use

- After changing [modules/static-reports/options.nix](../../../modules/static-reports/options.nix) (Caddyfile block,
  oauth2-proxy flags, launchd service, newsyslog), to confirm the real
  gate still behaves — a build dry-run structurally cannot verify a
  redirect chain.
- After changing `modules/pocket-id` or the passkey flow in
  [modules/pocket-id/tests/lib/pocket-id-auth.ts](../../../modules/pocket-id/tests/lib/pocket-id-auth.ts), since this suite exercises the same
  helper against a fresh Pocket ID instance.

## Known Constraints

- Docker must be running.
- Runs unattended (no `sudo`, no browser setup, stdin may be closed).
  First run in a given worktree does `npm install` (Playwright + its test
  runner); the generated API key is stored in the worktree's gitignored
  `.env`.
- The test Caddy signs with its own per-worktree CA; oauth2-proxy trusts
  it via `--provider-ca-file`, and a browser on another tailnet device
  will show a certificate warning.
- Ports are persisted in `.env`, not re-picked (the OIDC client's callback
  URL bakes in the reports vhost URL); deleting `.env` forces a full
  re-bootstrap.
