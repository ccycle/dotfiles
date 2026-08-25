# Static Reports Module Design

## Purpose

Give anything in this repo (currently: `.agents/skills/e2e-test-opencloud`'s
Playwright HTML report, but written to be reusable for any future
tooling — coverage reports, build artifacts, ad-hoc dashboards) a way to
publish static files that are browsable over the tailnet, without each
consumer needing to solve TLS/reachability/ACL problems itself.

## Why This Exists (Instead of Ad-Hoc Per-Tool Solutions)

Getting a Playwright report visible from another Tailscale device
surfaced a chain of dead ends worth recording so they aren't
re-discovered:

- **`tailscale serve --https=443`** doesn't work on this host: production
  Caddy already owns `<TAILSCALE_IP>:443` via `default_bind` in
  `modules/caddy/darwin.nix`. Caddy holds the actual OS socket, so
  `tailscale serve`'s own HTTPS listener never receives traffic for it —
  connections complete a TCP handshake but fail TLS, because Caddy
  receives the ClientHello, doesn't recognize the `.ts.net` SNI among its
  configured vhosts, and rejects it.
- **A new arbitrary port** (e.g. for a one-off `npx playwright
show-report --host <tailscale-ip>`) is blocked at the network layer
  regardless of what's listening: `modules/tailscale/policy.hujson`'s ACL
  only permits `group:users -> tag:server` on ports 80, 443, 53, 22.
  Verified empirically (`nc -zv`) that 80/443 (Caddy) and 22 (sshd) are
  already the only three actually reachable.
- **SSH port forwarding** through the already-permitted port 22 does
  work in principle, but pushes real setup burden onto whoever wants to
  look at a report (GUI SSH clients like Termius require an explicit,
  separately-configured local-forward rule — connecting alone isn't
  enough), so it's a fine one-off but not something worth building
  tooling around.
- **A per-worktree dedicated Caddy process** (the approach
  `tests/e2e/scripts/stack.sh` uses for the isolated OpenCloud/pocket-id
  stack) doesn't generalize here: it exists specifically to give pocket-id
  a single stable WebAuthn origin reachable both locally and remotely
  (see `tests/e2e/design.md`), and it runs on a **dynamic** port every
  time — which the ACL blocks from other devices just as much as any
  other arbitrary port. That design was never actually about generic
  "reach this over the tailnet" access; it happened to be local-reachable
  as a side effect of solving a WebAuthn-specific problem.

Given 80/443 are the only tailnet-reachable HTTP(S) ports and they're
already Caddy's, the only path that doesn't require an ACL policy change
is a vhost _on production Caddy itself_. That's a materially different
kind of change than the ephemeral per-worktree Caddy: it's added **once**
via the normal `darwin-rebuild switch` path, like any other module, and
never needs Caddy to restart again afterward — only the files underneath
`file_server`'s root change per use, which Caddy picks up without a
config reload.

## Why Serve The Whole Directory, Not Just E2E Reports

Scoped narrowly this would be `services.e2eTestReports` serving one
fixed subdirectory. Kept generic instead (`file_server browse` over
`dataDir`, arbitrary subdirectories) because the actual problem —
"I made some static HTML/files somewhere in this repo's tooling and want
to glance at them from my phone" — isn't specific to Playwright or to
`tests/e2e/`, and the marginal cost of genericity here is zero (no extra
config surface beyond a directory).

## Why Pocket ID Auth (and Why It's a Caddy-Level Gate)

The original design deliberately had no app-level auth: reachability was
gated by the Tailscale ACL (`group:users` only — the same trust boundary
every other internal service uses), report contents were test artifacts
rather than user data, and branch names in URLs weren't secret.

That posture changed when the goal became "only Pocket ID-authenticated
users may view reports": `group:users` is broader than the set of people
with a registered Pocket ID passkey. Pocket ID is a pure OIDC provider
with no built-in proxy (its own docs point users to a proxy), and this
service is a bare `file_server` with no app behind it to implement
native OIDC — so the gate has to live at Caddy's L7, as an
oauth2-proxy + `forward_auth` pair.

Alternatives rejected:

- **caddy-security plugin in the shared Caddy** would require rebuilding
  the one binary that fronts every vhost (OpenCloud, Immich, Forgejo,
  Grafana, Pocket ID, CA, Attic, index). It has a well-documented history
  of breaking config changes between releases, and this Caddy runs with
  `admin off` (config only changes on daemon restart) — a broken plugin
  upgrade would take down every service at once.
- **basicauth** (Prometheus's approach) is not Pocket ID / passkey.
- **A dedicated Caddy process just for reports** would isolate the blast
  radius but adds a second Caddy where a stock first-party `forward_auth`
  is the standard, Pocket-ID-documented path.

oauth2-proxy runs as a native launchd daemon on `127.0.0.1:4180`
(loopback-only; the tailnet ACL never exposes it) and the reports vhost
`forward_auth`s every non-`/oauth2/*` path to it. The client is a
confidential OIDC client `reports` registered via
`services.pocket-id.oidcClients`, secret captured into sops by
`scripts/pocket-id-register-clients.sh`; no `allowedGroups`, so any
authenticated user may browse. The gate failing (401, e.g. while
oauth2-proxy is down) is accepted — reports is a browse-when-you-need-it
service, and launchd `KeepAlive` restarts the proxy — and OAuth callback
query strings never reach the access log because `internal_tls` already
drops all query strings on every vhost.

TLS trust for oauth2-proxy's OIDC calls to `https://auth.<hostname>.internal`
needed explicit setup, confirmed by measurement: oauth2-proxy runs as a
root system launchd daemon, so it only sees the System keychain, not any
user's login keychain. The `ca.<hostname>.internal` download page installs
trust into whichever keychain the _browser's_ user chose (typically the
login keychain) — a root daemon never observes that. Live discovery
against `https://auth.<hostname>.internal/.well-known/openid-configuration`
failed with `x509: certificate signed by unknown authority` until
`--provider-ca-file` was pointed directly at Caddy's own CA root
(`/var/lib/caddy/caddy/pki/authorities/<hostname>/root.crt`), which
sidesteps keychain state entirely.

A live login also surfaced `Error redeeming code during OAuth2 callback:
email in id_token isn't verified`: this Pocket ID instance has no SMTP
configured, so `emailVerified` is permanently `false` for every account —
not specific to any one user. oauth2-proxy's default `email_verified`
enforcement would therefore reject every login forever, so
`--insecure-oidc-allow-unverified-email=true` is set. This isn't a
weakened check relative to the rest of the stack: no other Pocket
ID-backed client here (OpenCloud, Immich, Grafana, Forgejo) enforces
`email_verified` either.

## Constraints

- **Consumers are responsible for populating and pruning their own
  subdirectory** under `dataDir` — this module only serves whatever is
  there. It doesn't schedule anything itself; each consumer's own
  run script prunes on its own schedule (currently: on every run, not
  a separate timer).
- **`browse` lists directory contents for any authenticated user** —
  auth gates the whole vhost, not individual paths; `file_server browse`
  still enumerates every subdirectory to anyone who has passed the
  Pocket ID login. Per-path gating was rejected because browse defeats it.
