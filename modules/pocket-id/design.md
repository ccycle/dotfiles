# Pocket ID Module Design

## Purpose

Provide the passkey-only OIDC identity provider for the zero-trust
Phase 2 roadmap (see `modules/tailscale/design.md`). Pocket ID issues
OIDC tokens backed by WebAuthn/passkey authentication, replacing each
service's own local-account login with a single passkey-gated sign-in.

## Non-Goals

- Wiring individual services (Forgejo, GitLab, OpenCloud, Immich) to
  Pocket ID as an OIDC client. Each of those requires either a manual
  admin-console step (Forgejo, Immich, OpenCloud) or a client
  secret that only exists after the corresponding OIDC client is
  created through Pocket ID's own admin UI — this is a per-service,
  post-deployment task, not something this module can express
  declaratively. Track it as a follow-up once Pocket ID is confirmed
  healthy.
- LDAP sync, MaxMind geolocation, and email notifications. Not needed
  for a single-owner homelab.

## Why This Structure

**No `volumeRoot`/`mountPoint` indirection.** Unlike Forgejo or
OpenCloud, Pocket ID's data is a small SQLite database plus WebAuthn
credential records — not bulk user content — so it stays on the
internal disk under `/var/lib/pocket-id`, following the same pattern
as `modules/attic` rather than the external-volume services.

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
