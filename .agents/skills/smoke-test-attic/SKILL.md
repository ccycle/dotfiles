---
name: smoke-test-attic
description: Run smoke tests to verify the Attic Nix binary cache is reachable and can push/read cache objects correctly.
---

# Attic Smoke Test

Verifies the Attic binary cache (`services.atticd`, deployed only on `mac-mini-m4-pro`) is healthy from the
perspective of a consumer: reachable through Caddy over HTTPS, and able to push a fresh object and read it
back with byte-level integrity.

Unlike the other `smoke-test-*` skills, this one is designed to run from **any** host on the network, not
just the service host — it exercises exactly the path Nix substituters use (Caddy HTTPS), not the local
daemon.

## Prerequisites

- A `smoke` role Attic token deployed via sops/home-manager (`modules/attic/home.nix`), readable at
  `~/.config/sops-nix/secrets/attic-smoke-token`. Generate one with
  `.agents/skills/attic-credentials/scripts/generate-token.sh smoke` if it doesn't exist yet.
- The Caddy internal CA trusted in this Mac's **System keychain** (not just `/etc/nix/ca-bundle.crt`):
  the `attic` client validates TLS against the system trust store, independent of Nix's own CA bundle.
  One-time setup per host:
  ```bash
  sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain /etc/nix/attic-ca.crt
  ```
  (On `mac-mini-m4-pro` itself, use `/var/lib/caddy/caddy/pki/authorities/local/root.crt` instead — see
  `bootstrap/modules/attic/darwin.nix`.)
- `zstd` on `PATH` (used to decompress the downloaded NAR for integrity verification).

## Usage

Run from the repository root:

```bash
.agents/skills/smoke-test-attic/scripts/test.sh
```

## Checks Performed

1. **Pre-flight reachability**: `GET /dotfiles/nix-cache-info` through Caddy HTTPS, both with `-k` and with
   `/etc/nix/ca-bundle.crt` (repo-managed on every host, unlike the client's system-trust dependency below).
   This isolates "is the server up" from "does my push token/TLS trust work" before attempting the round-trip.
2. **Push→read round-trip**: pushes a freshly created, unique store path (so it can never be short-circuited
   as "already cached") to the `dotfiles` cache via `attic push` over Caddy HTTPS, using an ephemeral
   `XDG_CONFIG_HOME`-scoped client config (never touches a host's real `~/.config/attic/config.toml`).
3. **narinfo verification**: fetches `/dotfiles/<hash>.narinfo` and checks the `StorePath` field matches.
4. **NAR integrity**: downloads the `.nar`, decompresses with `zstd`, and checks its sha256 matches both the
   narinfo's `NarHash` and a local `nix-store --dump` of the same store path — proving the bytes served
   through Caddy are exactly what was pushed.

The pushed object is tiny (~150 bytes) and is never deleted — the `attic` client has no delete command, and
it ages out naturally via `services.atticd.settings.garbage-collection` (30-day default retention).

## When to Use

- After `darwin-rebuild switch` on `mac-mini-m4-pro` to verify the cache deployed correctly.
- From any other host, to verify the cache is usable as a substituter from a consumer's perspective.
- When debugging Attic service issues or `attic-credentials` token problems.

## Known limitations

- Not wired into `darwin-rebuild` or `verify-change` — run manually.
- Does not check the `atticd` launchd daemon or local process state (host-specific; out of scope for a
  test meant to run from any client). Use `ssh mac-mini-m4-pro -- launchctl print system/org.nixos.atticd`
  to inspect the daemon directly.
