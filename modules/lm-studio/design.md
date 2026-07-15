# LM Studio Design

## Purpose

Expose the LM Studio OpenAI-compatible API on the mac-mini-m4-pro host to
tailnet clients (specifically opencode), so local models can be used for
code assistance without external API calls.

## Non-Goals

- **No LAN exposure.** The server binds 127.0.0.1 only; Caddy is the sole
  tailnet-facing listener. Keep LM Studio's "Serve on Local Network" off.
- **No authentication.** Tailscale ACLs are the access boundary; adding an
  API key would complicate every client for no real gain on a personal
  tailnet.
- **No model lifecycle management.** Models must be downloaded manually in
  the LM Studio GUI. LM Studio JIT-loads a requested model if it is not
  already in memory; this module does not preload or pin models.

## Why HTTP, Not `internal_tls`

Every other Caddy vhost in this repo uses `import internal_tls` (Caddy's
internal CA). This vhost deliberately uses plain HTTP instead. Reasons:

- **Tailscale WireGuard already encrypts transport** — the vhost is only
  reachable via the tailnet (dnsmasq answers `*.internal` on the Tailscale
  IP only, `--bind-interfaces`), so TLS is defense-in-depth, not required.
- **opencode is Bun-based** and does not trust Caddy's internal CA out of
  the box. Adding `NODE_EXTRA_CA_CERTS` or equivalent on every client
  machine is high friction for negligible security gain on a personal
  tailnet.

## Why a launchd User Agent, Not a System Daemon

The `lms` CLI, model storage, and server configuration all live under the
user's home directory (`~/.lmstudio`). A system daemon would need to
hardcode or discover the user's home, and would run in a different
context. A user agent (`launchd.user.agents`) matches the cachix
watch-store precedent and avoids those issues.

## Constraints

- The `lms` CLI is only available after LM Studio has been launched at
  least once (it bootstraps itself to `~/.lmstudio/bin/lms`). The launchd
  agent script handles this gracefully (exits 0 with a message); after
  the first launch, kickstart the agent manually.
- Port 1234 must not collide with any other service on 127.0.0.1.
  Currently nothing else uses it.

## Rejected Alternatives

- **`tailscale serve`** to expose the port — rejected to keep all vhost
  routing in Caddy (single configuration surface, consistent with every
  other service).
- **HTTPS with `import internal_tls`** — rejected for the Bun CA-trust
  friction described above.
- **Binding LM Studio to 0.0.0.0 directly** (no Caddy) — rejected
  because it breaks the vhost routing pattern, requires remembering a
  port number instead of a hostname, and bypasses Caddy's access logging.
