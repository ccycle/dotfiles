# Tailscale Design

## Purpose

Provide the networking substrate for all self-hosted services. Every
service vhost (`*.internal`) is reachable only via Tailscale; the LAN
is explicitly excluded.

## Zero-Trust Roadmap

### Phase 1 — L4 least-privilege (this change)

- **Caddy binds to the Tailscale IP only** (`default_bind {$TAILSCALE_IP}`
  in the global Caddyfile block). The launchd script waits for Tailscale
  before starting Caddy, following the same pattern as dnsmasq. This
  closes the LAN exposure that existed when Caddy bound to 0.0.0.0.
- **ACL policy** (`policy.hujson`) defines a default-deny posture:
  servers are tagged `tag:server`. Client-to-server access is open on
  every port; server-to-server access stays restricted to the ports
  servers actually use to talk to each other — see "Why Client→Server
  Access Is Fully Open, But Server→Server Isn't" below. Backend
  service ports (1234, 2283, 3000, 8929, 9090, 9200) bind to 127.0.0.1
  and are never directly reachable from the tailnet — Caddy is the
  single entry point.
- The policy file is checked into this repo for review and versioning,
  and applied via OpenTofu (`modules/tailscale/terraform/`,
  `scripts/tailscale-acl-apply.sh` — see the `tailscale-acl-apply`
  skill). Apply is still a deliberate human step: `tofu plan` first,
  `tofu apply` second, never unattended/CI-driven.

### Phase 2 — L7 per-request authentication (in progress)

- **Chosen IdP: Pocket ID** (`modules/pocket-id`) — a passkey-only,
  OIDC Certified™ provider. Deployed and reachable at
  `https://auth.<hostname>.internal` via Caddy, Tailscale-only like
  every other vhost.
- **tsidp was the original candidate and was rejected**: it
  authenticates by tailnet device identity rather than WebAuthn/
  passkeys, so it doesn't meet the passkey requirement regardless of
  maturity, and its own README states it is experimental and not
  intended for production. See `modules/pocket-id/design.md` for the
  full rejection rationale and Pocket ID's own security posture
  (it has a nontrivial CVE history in core OIDC flows — all patched,
  but the module pins to a specific version rather than floating).
- Each SSO-capable service is wired to Pocket ID as an OIDC client
  through its own Nix configuration (compose.yaml env vars or
  `GITLAB_OMNIBUS_CONFIG`):
  - **OpenCloud** — public client (PKCE); the web client keeps Pocket
    ID's auto-generated client ID as-is. Desktop/mobile use hardcoded
    IDs (`OpenCloudDesktop`, `OpenCloudIOS`, `OpenCloudAndroid`).
    Role assignment via `PROXY_ROLE_ASSIGNMENT_DRIVER=oidc` with
    default mapping (opencloudAdmin → admin, etc.).
    Pocket ID groups with custom claims must be created manually.
  - **Forgejo** — confidential client, client ID and secret via sops.
  - **GitLab** — confidential client via OmniAuth, ID/secret via sops.
  - **Immich** — confidential client, ID/secret via sops.
    Auto-registration enabled (`IMMICH_OIDC_AUTO_REGISTER=true`).
  - **Grafana** — confidential client via `GF_AUTH_GENERIC_OAUTH_*`
    env vars, ID/secret via sops.
- Pocket ID OIDC clients are created manually in the Pocket ID admin
  UI (one-time bootstrap). Client IDs and secrets are then added to
  the respective module's `secrets.yaml` via `sops`.
- Caddy `forward_auth` (a shared L7 gate in front of vhosts, as
  opposed to each app doing its own OIDC login) has not been adopted
  for Forgejo/GitLab/OpenCloud/Immich; every one of them already has
  native OIDC support, so per-app login is sufficient there.
- **Prometheus** uses Caddy `basicauth` with a bcrypt hash set via
  `services.monitoring.prometheusAuthHash`. The hash is generated
  manually (`caddy hash-password --plaintext <PASSWORD>`) and set
  in the host profile. No OIDC support in Prometheus means this is
  the only practical per-app auth option.
- Loki has no Caddy vhost and stays localhost-only for the
  `investigate-service` skill; no remote access path exists today.
- Non-interactive API clients (opencode → LM Studio) use API keys
  distributed via sops-nix, not OIDC.

### Phase 3 — audit (in progress)

- Caddy access logs and metrics — design captured in
  `modules/monitoring/design.md`, which lifts its prior "no Caddy
  metrics or access logs" non-goal for this work (blackbox/synthetic
  probing remains out of scope there).
- Device posture checks (Tailscale paid feature, evaluate when needed).

## Why `.internal` TLD

`.internal` is an ICANN-reserved TLD (July 2024) guaranteed never to
be delegated in the public DNS root — the DNS equivalent of RFC 1918
private IP ranges. Unlike `.local` (mDNS collision), `.home`, `.lan`,
or `.corp` (no reservation, future gTLD risk), `.internal` is the
only TLD with an official private-use guarantee. Tailscale's
`tailscale serve` and automatic TLS certificates only work with
`*.ts.net` domains and do not support custom TLDs like `.internal`
(tailscale/tailscale#11563), but the benefits of a stable,
collision-free namespace outweigh the CA trust friction that
`*.ts.net` would eliminate.

## Why `default_bind` Instead of Per-Site `bind`

`default_bind` in the global block applies to every site automatically,
including sites defined by service modules (`environment.etc."caddy/
sites/*.caddy"`). A per-site `bind` directive would require every module
to repeat the Tailscale IP reference, coupling them to the networking
layer.

## Why ACL Apply Stays a Human Step

Applying ACLs via the API is a destructive operation that can lock out
devices. OpenTofu (`modules/tailscale/terraform/`) replaced the old
copy-into-the-admin-console step with `tofu plan`/`tofu apply`, which
mitigates the lockout risk by showing the exact diff before anything
changes — but apply is still run by a human reading that diff, never by
CI or on a schedule. `tofu import` was used once to adopt the
already-live policy without recreating it; see the `tailscale-acl-apply`
skill for the full workflow.

## Why Client→Server Access Is Fully Open, But Server→Server Isn't

This is a single-user tailnet: `autogroup:member` is only the owner's
own devices, never a third party. Restricting client→server access
port-by-port therefore only guards against one scenario — a
compromised client device (malware, a malicious dependency, a rogue
background process) using its tailnet reach to pivot into a service
that was never meant to be network-reachable. That guard was judged
not worth its cost: per-port rules meant every new service needed a
policy edit and re-apply before it was reachable at all, which is
exactly the kind of day-to-day friction the OpenTofu migration was
meant to remove. So client→server grants cover every port on
`tag:server` devices.

Server→server traffic stays restricted to the ports servers actually
use to talk to each other. A compromised server (a container escape,
a vulnerable dependency) is a more realistic and higher-value target
than a personal device, and — unlike the client case — nothing about
day-to-day development depends on servers reaching arbitrary ports on
each other, so the narrower rule costs nothing in practice while still
limiting lateral movement between hosts.

Backend service ports that bind to 127.0.0.1 stay unreachable from the
tailnet regardless of this ACL (defense in depth). For a host this
repo doesn't manage (a NAS, say), the ACL is the *only* defense for
its tailnet-facing ports, since a bind-address restriction isn't an
option there — the fully-open client→server grant relies on that
host's own services not exposing anything unintended.

## Constraints

- Caddy must wait for Tailscale at boot; if Tailscale is down, Caddy
  cannot start (KeepAlive retries until it succeeds).
- If the Tailscale IP changes (rare — typically stable), Caddy must be
  restarted to rebind.
- Any device that should be reachable under the server grants (Caddy,
  DNS, SSH, and now full client access) must be tagged `tag:server` in
  the Tailscale admin console first — an untagged device matches none
  of the `tag:server` rules and is unreachable, including for Tailscale
  SSH, which is gated by its own independent ACL layer.
