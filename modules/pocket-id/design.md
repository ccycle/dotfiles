# Pocket ID Module Design

## Purpose

Provide the passkey-only OIDC identity provider for the zero-trust
Phase 2 roadmap (see `modules/tailscale/design.md`). Pocket ID issues
OIDC tokens backed by WebAuthn/passkey authentication, replacing each
service's own local-account login with a single passkey-gated sign-in.

## Non-Goals

- LDAP sync, MaxMind geolocation, and email notifications. Not needed
  for a single-owner homelab.

## Why This Structure

**No `volumeRoot`/`mountPoint` indirection.** Unlike Forgejo or
OpenCloud, Pocket ID's data is a small SQLite database plus WebAuthn
credential records — not bulk user content — so it stays on the
internal disk under `/var/lib/pocket-id`, following the same pattern
as `modules/attic` rather than the external-volume services.

**`dataDir` must be written in resolved-realpath form.**
`cfg.dataDir` defaults to `/private/var/lib/pocket-id/data`, not the
`/var/lib/pocket-id/data` symlink form. macOS's `/var` is a symlink to
`/private/var`, and OrbStack only treats a bind-mount source written
as a resolved realpath as a host share (mounted via virtiofs); the
symlink form silently mounts as a VM-internal overlay directory that
auto-vivifies empty and never reflects host content. This is the root
cause that several earlier fixes missed: they wrote the encryption key
on the host under `/var/lib/...` but never fixed that the bind mount
was not delivering that directory to the container at all. The
host-side directory is `/private/var/lib/pocket-id/data` — same
files, correct mount source.

**Passkey-only enforcement via explicit env vars.** Both
`EMAIL_ONE_TIME_ACCESS_AS_UNAUTHENTICATED_ENABLED` and
`EMAIL_ONE_TIME_ACCESS_AS_ADMIN_ENABLED` are set to `false`. Pocket ID
has no password-login feature at all, but it does offer an
email-delivered one-time login code as a passkey-recovery path; the
project's own docs describe enabling it as reducing security
"significantly," and one of its own GHSA advisories
(`GHSA-hp74-gm6m-2qm5`) was specifically a step-up-auth bypass via
this code path. Disabling it keeps passkey as the only credential,
matching the requirement that started this work.

**`ALLOW_USER_SIGNUPS=disabled`.** Single-owner homelab; there is no
scenario where self-service signup is wanted.

**Version pinned to `v2.11.0`, not the floating `v2` tag the upstream
compose example recommends.** See Constraints below.

## Rejected Alternatives

- **tsidp** (Tailscale's own OIDC IdP), the original Phase-2 candidate
  named in `modules/tailscale/design.md`. Rejected for two reasons:
  it authenticates based on tailnet device identity, not WebAuthn/
  passkeys, so it doesn't satisfy the passkey requirement regardless
  of its maturity; and its own README states it is "experimental,
  work in progress, community project" and not intended for
  production use.

## Constraints

- **Pin to a patched version and track advisories.** Pocket ID has
  published 7 GHSA security advisories as of this writing, 4 rated
  High, several in core OIDC primitives: redirect_uri validation
  (`GHSA-9h33-g3ww-mqff`, CVE-2026-28512), authorization-code
  cross-client exchange (`GHSA-qh6q-598w-w6m2`, CVE-2026-28513),
  refresh-token bypass of revocation/disablement
  (`GHSA-w6p7-2fxx-4f44`, CVE-2026-43983), and client-credentials
  audience confusion (`GHSA-q4xm-p75h-h9p3`, CVE-2026-62662, fixed in
  v2.10.0). All were patched promptly, but the pattern means this
  service should never float on a major-version tag — bump the pin
  deliberately after checking
  `https://github.com/pocket-id/pocket-id/security/advisories`.
- **Tailscale-only exposure is the primary mitigation for the above.**
  Several of the known CVEs require either an already-registered
  OIDC client or tailnet-level access to exploit. Keeping Pocket ID
  reachable only via Caddy's Tailscale-bound listener (no public
  ingress) substantially narrows the exploitable surface without
  waiting on upstream fixes.
- **First-run admin bootstrap is manual.** Pocket ID has no way to
  provision an admin account or register a passkey non-interactively;
  the first visit to `https://auth.<hostname>.internal/setup` must
  happen from a browser with a platform authenticator or security key.
- **Revocation behavior should be spot-checked after any version
  bump**, given `CVE-2026-43983` was specifically about refresh
  tokens outliving revocation/disablement — confirm a disabled user's
  refresh token actually stops working before trusting this as the
  zero-trust auth layer.
- **The encryption key must live inside the `dataDir` bind mount, not
  as its own separate bind mount.** OrbStack auto-vivifies a standalone
  bind-mount source as an empty VM-internal directory unless the source
  path is written in resolved-realpath form, which is the same class of
  bug this module hit with `/var` — a key file at `/var/lib/pocket-id/
  encryption_key` would never reach the container. A file appearing
  inside a directory that is already a host bind mount (`dataDir`) is
  always visible. Any future secret this service needs as a file should
  go through the same `dataDir`-relative pattern rather than its own
  top-level bind mount entry.
- **The host `dataDir` must be writable by the primary user, not
  root.** The container runs as uid 1000, which OrbStack maps to the
  host user; the launchd script therefore `chown`s `dataDir` to
  `config.system.primaryUser` (same pattern as `modules/static-reports`)
  after creating it. Without this, once the mount path is correct the
  container still fails with `unable to open database file (14)`.
