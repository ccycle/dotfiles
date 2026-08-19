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
is a vhost *on production Caddy itself*. That's a materially different
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

## Why No App-Level Auth

Reachability is already gated by the Tailscale ACL (`group:users` only,
the same trust boundary every other internal service in this homelab
uses). Report contents are test artifacts, not user data, and branch
names in URLs aren't secret. Matches the existing posture rather than
inventing a stricter one for this specific service.

## Constraints

- **Consumers are responsible for populating and pruning their own
  subdirectory** under `dataDir` — this module only serves whatever is
  there. It doesn't schedule anything itself; each consumer's own
  run script prunes on its own schedule (currently: on every run, not
  a separate timer).
- **`browse` lists directory contents** — anyone who can reach
  `https://reports.<hostname>.internal` at all (i.e. anyone already on
  this tailnet) can enumerate every subdirectory, not just ones they
  already know the name of.
