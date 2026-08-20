# Reports E2E Suite Design

## Purpose

Browser-driven E2E coverage for the static-reports auth gate
(`modules/static-reports`): the full chain from "anonymous browser hits
`reports.<hostname>.internal`" through oauth2-proxy's forward_auth,
Pocket ID's passkey-only login, consent, and back to a served static file.
Reuses the passkey-ceremony machinery from `tests/e2e/lib/pocket-id-auth.ts`
(the same helper the OpenCloud suite uses — it was written to be reusable
for any pocket-id-fronted service; see `tests/e2e/design.md`).

This is the first test suite for a **Caddy L7 gate** rather than an app
with native OIDC: everything else in the repo (OpenCloud, Immich, Forgejo,
Grafana) performs its own OIDC login inside the app. A `file_server`
cannot — which is exactly why the production fix is an oauth2-proxy
forward_auth gate, and why this suite's job is to prove that gate end to
end.

## Non-Goals

- Production. Never touches the real `services.pocket-id` or the real
  `https://reports.<hostname>.internal` vhost.
- The other services' suites (OpenCloud, Forgejo, Immich, Monitoring) —
  those already cover their own login paths; this suite only exercises
  the reports gate.
- Publishing flow mechanics (cp into `/var/lib/static-reports`) — that
  part is covered by every sibling suite's run.sh and is orthogonal to
  the auth question.

## Why an Isolated Per-Worktree Stack (Same Reasoning as tests/e2e)

Pocket ID's WebAuthn `RPOrigins` is fixed to its `APP_URL` at startup
(verified in `modules/pocket-id` and `tests/e2e/design.md`), and the whole
point is a *browser-visible* redirect chain through a real IdP. That can
only be exercised against a live Pocket ID, so the suite gets its own
per-worktree one, exactly like the OpenCloud suite — same container
(`modules/pocket-id/compose.yaml` + a volume-name override so it never
mounts the production volume), same dedicated test Caddy fronting both
pocket-id and the reports vhost on one origin reachable locally and from
the tailnet, same one-time manual admin-API-key bootstrap per worktree.

## Why oauth2-proxy, Mirrored From Production

The production gate is oauth2-proxy + Caddy `forward_auth`
(`modules/static-reports/options.nix`). Testing a different mechanism
(e.g. testing the browse-only path and hand-waving the auth) would prove
nothing about the real deployment. So the test Caddy's reports vhost is a
line-for-line miniature of the production Caddyfile block — `/oauth2/*`
proxied straight to oauth2-proxy, everything else `forward_auth`'d with a
401 → `/oauth2/sign_in?rd=...` redirect — and oauth2-proxy runs natively
on the host (inside the pinned `devShells.e2e`, added in `flake.nix`),
loopback-only, like the production launchd daemon.

oauth2-proxy needs a *confidential* client with a generated secret, so the
bootstrap order differs from the OpenCloud suite: `bootstrap_if_needed`
creates the client and captures its secret into `.env` **before**
`start_oauth2_proxy` runs (the proxy can't start without the secret). The
bootstrap itself needs the admin API key once per worktree, same as the
OpenCloud suite.

## Why Three Tests, Not One

- **Unauthenticated redirect**: proves the gate exists for a stranger —
  an anonymous browser must land on pocket-id, not on any file.
- **Authenticated browse + read**: proves the passkey ceremony completes
  through the gate and that `file_server browse` (listing + file content)
  is what's actually served behind it.
- **Sign-out re-engages the gate**: proves sessions are real — after
  logout the same URL that was just served bounces back to pocket-id
  again. `clearCookies` is required because oauth2-proxy's sign_out only
  clears its own cookie; the pocket-id session cookie would otherwise
  silently re-authenticate the next gate pass.

## Constraints

- **Never delete the pocket-id test user out-of-band** without also
  wiping `tests/e2e-reports/.state/` — same coupling rule as
  `tests/e2e/design.md` (stable identity + fresh passkey per run).
- **The CA-copy step needs `sudo` once per worktree** (`ensure_test_ca`,
  reads `/var/lib/caddy/...`), and the native oauth2-proxy process trusts
  the test Caddy's certs only because the copied root is already in the
  macOS System keychain (Go reads the system store) — same trust the
  production proxy relies on.
- **Ports are persisted, not re-picked** — the registered OIDC client's
  callback URL bakes in the reports vhost URL, so re-picking ports would
  desync it; deleting `tests/e2e-reports/.env` forces a full re-bootstrap.
- **Browser sessions are fresh per test** (`workers: 1`,
  `fullyParallel: false`), so test 1's anonymous state and tests 2/3's
  authenticated state never bleed into each other.