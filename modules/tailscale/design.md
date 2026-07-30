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
  servers are tagged `tag:server`, and only specific ports (80, 443, 53,
  22) are open to `group:users`. Backend service ports (1234, 2283, 3000,
  8929, 9090, 9200) bind to 127.0.0.1 and are never directly reachable
  from the tailnet — Caddy is the single entry point.
- The policy file is checked into this repo for review and versioning.
  It must be applied to the tailnet manually via the Tailscale admin
  console or API; there is no automated GitOps sync yet.

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
  - **OpenCloud** — public client (PKCE), client ID `web` matches
    WebFinger default. Desktop/mobile use hardcoded IDs
    (`OpenCloudDesktop`, `OpenCloudIOS`, `OpenCloudAndroid`).
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

### Phase 3 — audit (future)

- Caddy access logs → Loki (requires lifting the "no Caddy logs"
  non-goal in `modules/monitoring/design.md`).
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

## Why the ACL Policy Is Not Auto-Applied

Applying ACLs via the API is a destructive operation that can lock out
devices. The policy file is versioned here for review, but applying it
is a deliberate manual step. Automated GitOps sync (e.g.
`gitops-acl-action`) is a future option once the policy stabilizes.

## Constraints

- Caddy must wait for Tailscale at boot; if Tailscale is down, Caddy
  cannot start (KeepAlive retries until it succeeds).
- If the Tailscale IP changes (rare — typically stable), Caddy must be
  restarted to rebind.
- `tag:server` must be applied to mac-mini-m4-pro and mac-mini-m4 in
  the Tailscale admin console before the ACL policy takes effect.
