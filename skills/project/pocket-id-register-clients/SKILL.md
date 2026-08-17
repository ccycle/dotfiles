---
name: pocket-id-register-clients
description: Register OIDC clients and user groups on the production Pocket ID instance by running scripts/pocket-id-register-clients.sh on the target host. Use when adding or updating an SSO client (OpenCloud, Forgejo, Immich, Grafana), the opencloud_role groups, or the admin user's group membership. Must be run on the target host itself, never from a random machine.
---

# Pocket ID OIDC Client / Group Registration

The production Pocket ID instance (`https://auth.<host>.internal`) is
reconciled by an idempotent script against the declaration in
`modules/pocket-id/options.nix` (`services.pocket-id.oidcClients` /
`oidcGroups`). Service modules own their client/group declarations; this
skill runs the script that turns them into live Pocket ID state.

The script is the only supported way to create or update these clients.
Creating them by hand in the Pocket ID UI causes drift from the
declaration (and leaves stale `*_oidc_client_id` sops keys behind).

## When To Use

- Adding or changing an OIDC client for a service that logs in through
  Pocket ID (OpenCloud web/desktop/mobile, Forgejo, Immich, Grafana).
- Adding the `opencloud_*` role-mapping groups or their custom claims.
- (Re)assigning the admin user to the admin groups after a rebuild.
- Removing the stale `*_oidc_client_id` keys from a host's sops secrets.

## Prerequisites

- Run **on the target host** (`mac-mini-m4` or `mac-mini-m4-pro`). The
  script detects the hostname, evals that host's Nix config, and only
  touches that host's own sops files. It talks to Pocket ID on
  `http://127.0.0.1:1411` (no TLS/tailnet dependency).
- The operator holds that host's sops age key (normal on the host itself).
- A Pocket ID admin API key exists in
  `modules/pocket-id/secrets-<host>.yaml` under `pocket_id_admin_api_key`.
  One-time creation: Pocket ID UI → Settings → API Keys, then
  `sops set modules/pocket-id/secrets-<host>.yaml '["pocket_id_admin_api_key"]' '"<key>"'`.
- Pocket ID is running and healthy on the host.

## Workflow

1. **Edit the declaration** (if the goal is a new/changed client or group),
   not the live Pocket ID. Client definitions belong in the owning service
   module, e.g. `modules/opencloud/options.nix`,
   `modules/forgejo/options.nix`, `modules/immich/options.nix`,
   `modules/monitoring/options.nix`. Groups and the option schemas live in
   `modules/pocket-id/options.nix`. See that file for the option fields
   (`name`, `clientId`, `isPublic`, `pkceEnabled`, `callbackURLs`,
   `logoutCallbackURLs`, `allowedGroups`, and for confidential clients
   `secretFile`/`secretKey`).
2. **Preview** with `--dry-run` (works without an API key; existence of
   live objects is then not checked).
3. **Apply** on the target host:
   ```bash
   scripts/pocket-id-register-clients.sh --admin-user <username>
   ```
   `--admin-user` adds the named user to every group flagged `adminGroup`
   (e.g. `opencloud_admins`). OpenCloud returns 500 for users in no group,
   so pass it at least once. Repeat the script after every config change;
   it is idempotent.
4. **Commit the sops writes** the script made (`git diff` → commit), then
   `scripts/darwin-rebuild.sh <profile>`.

## What The Script Does

- Ensures groups exist and sets their custom claims (e.g.
  `opencloud_role` → `opencloudAdmin`).
- Creates missing clients, updates existing ones to match the declaration,
  and recreates a confidential client whose sops secret is still a
  `CHANGE_ME_*` placeholder (generating a fresh secret).
- Writes newly generated confidential secrets into the owning module's
  sops file via `sops set` (`POST /api/oidc/clients/{id}/secret` returns
  the plaintext; the create call does not).
- Sets each client's allowed user groups.
- Removes the stale `*_oidc_client_id` keys from the host's own secrets
  files (`sops unset`).
- With `--admin-user`, finds-or-creates the user and merges the admin
  group IDs into its current group membership (never drops existing
  groups).

## Notes / Caveats

- **Per-host secrets files** (`modules/<svc>/secrets-<host>.yaml`) are
  only decryptable on their own host. mac-mini-m4's stale
  `*_oidc_client_id` keys are therefore removed the first time the script
  runs on mac-mini-m4, not from mac-mini-m4-pro.
- The script writes **only** inside the current checkout and only to the
  clients/groups/users it owns. It never touches GitLab (disabled on both
  hosts).
- Client IDs are fixed strings on purpose (mandatory for OpenCloud
  desktop/mobile; harmless otherwise because a client ID is not a secret —
  see `docs/oidc-setup.md`).
