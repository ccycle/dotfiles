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

## Why Both HTTP and HTTPS (ca.caddy Pattern)

The vhost listens on both `http://` and `https://` with `import
internal_tls`, following the `ca.caddy` precedent. Caddy's auto-HTTPS
generates a 308 redirect for any hostname that appears in an HTTPS site
block; an HTTP-only vhost for `llm.*` would be redirected to an HTTPS
endpoint with no certificate, breaking the connection. Listing both
addresses ensures HTTP works directly (useful for clients that don't trust
the internal CA) while HTTPS also works for clients that do.

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
- **HTTP-only vhost** — rejected because Caddy's auto-HTTPS generates a
  308 redirect for hostnames that appear in other HTTPS site blocks,
  breaking the connection. The ca.caddy dual-listen pattern is required.
- **Binding LM Studio to 0.0.0.0 directly** (no Caddy) — rejected
  because it breaks the vhost routing pattern, requires remembering a
  port number instead of a hostname, and bypasses Caddy's access logging.
