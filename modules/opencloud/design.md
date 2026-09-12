# OpenCloud Module Design

## Purpose

Run OpenCloud with a storage driver that keeps user files in a
human-readable directory tree, so files placed directly into the host
data directory (outside the OpenCloud web UI or sync client) become
visible to OpenCloud.

## Non-Goals

- Migrating existing data from the previous storage driver's on-disk
  layout. The two layouts are incompatible, and upstream provides no
  supported migration path between them; any pre-existing data must
  be re-uploaded through a client rather than copied at the
  filesystem level.

## Why This Structure

User-file storage uses the posix storage driver in its collaborative
sub-mode (`STORAGE_USERS_POSIX_WATCH_FS=true`), so files placed
directly into the host directory tree via SMB/Finder are picked up in
real time through inotify, without waiting for a restart or a manual
rescan. This was previously rejected in favor of non-collaborative
mode (see "Fallback" below); it was revisited to make externally
(SMB/Finder) added files visible without an explicit restart or
rescan. Validate inotify delivery through the OrbStack bind mount
before relying on this in production — see "Fallback" below for what
to do if it doesn't hold up.

System/metadata storage is intentionally left on the decomposed
driver — only user-file storage was moved to the posix driver.

### Fallback: non-collaborative mode

If inotify events don't reliably propagate through the OrbStack
bind-mount boundary (unresolved as of this writing — collaborative
mode requires filesystem-change notifications to cross the
host/container virtualization layer, which has a history of dropping
events), revert to non-collaborative mode
(`STORAGE_USERS_POSIX_WATCH_FS=false`, the previous configuration)
and fall back to manual assimilation: trigger a rescan, or restart
the container, after external writes. Do not silently keep
non-collaborative mode while also relying on dual ingest paths (SMB
writes and OpenCloud uploads) without documenting the resulting lag
— that combination is exactly the failure mode collaborative mode
exists to avoid.

Collaborative mode has independent limitations that apply even with
reliable notifications: no symlink support, no detection of files
moved across spaces, and possible tree-size miscalculation under
bulk edits.

### Host directory layout

User files are stored on the host at `${vol}/opencloud/user-files/`,
separate from internal OpenCloud data (metadata cache, service
configs) which lives at `${vol}/opencloud/data/`. The separation
is enforced by a dedicated Docker volume mount for the posix root.

```
${vol}/opencloud/
├── user-files/           # STORAGE_USERS_POSIX_ROOT
│   └── alice/            # STORAGE_USERS_POSIX_PERSONAL_SPACE_PATH_TEMPLATE
│       └── Documents/    # UI tree matches disk tree
└── data/                 # decomposed/metadata storage
    └── ...
```

### Path templates

`STORAGE_USERS_POSIX_PERSONAL_SPACE_PATH_TEMPLATE` is set to
`{{.User.Username}}` instead of the default
`users/{{.User.Id.OpaqueId}}`. This replaces the opaque UUID
directory with the human-readable username, so the on-disk tree
mirrors the UI hierarchy (e.g. `alice/Documents/` instead of
`a1b2c3d4-.../Documents/`).

The general (project) space template cannot be made human-readable
because `{{.SpaceId}}` is always a new UUID assigned by
`GenerateSpaceID()` — upstream explicitly lists this as a
limitation. Only personal spaces benefit from the template change.

## Rejected Alternatives

- **Keeping the previous (decomposed) user-storage driver**: rejected
  because it stores files as opaque, ID-addressed blobs rather than a
  filesystem tree, so files placed directly into the host directory
  outside of OpenCloud would never be recognized.
- **Distributing the shared music/photo masters (`${vol}/music`,
  `${vol}/photo`) via OpenCloud share links**, bind-mounting them into
  OpenCloud's posix tree: rejected after two failed approaches, in
  favor of Navidrome and Immich each reading their respective
  directory directly with no OpenCloud involvement (see
  `modules/navidrome/design.md`, `modules/immich/design.md`).
  Bind-mounting into a _personal_ space subdirectory (e.g.
  `<username>/Music`) hit two real failures: Docker auto-creates the
  mount destination at container start, and if that personal space
  had never been logged into yet, the pre-existing (xattr-less)
  directory makes reva's `GenerateSpaceID` permanently fail with
  "encountered empty space id on disk" on every future login for that
  user (confirmed against reva's source, reproduced in the isolated
  e2e stack); separately, the target volume is case-insensitive APFS
  and the production `ccycle` personal space already had a `music`
  folder, colliding with a `Music` mount destination. Switching to a
  dedicated _project_ space avoided both issues, but hit a third,
  unrelated one: reva does not assimilate a newly bind-mounted
  subdirectory of a project space by any means tried — not the
  container's own automatic initial fs scan, not collaborative mode's
  file watcher (writes under it log as "unhandled event" and are
  never applied), and not even an explicit `opencloud posixfs scan`
  targeted at the subdirectory or the whole tree (each left the
  subdirectory without a single `user.oc.*` xattr, and direct
  PROPFIND on its path 404s indefinitely) — confirmed empirically in
  the isolated e2e stack across multiple fresh container recreations.
  This is a structural limitation of project spaces specifically;
  personal-space subdirectories do not have it.

## External OIDC (Pocket ID)

OpenCloud uses Pocket ID as its external OIDC identity provider, replacing
the built-in `idp` service (excluded via `OC_EXCLUDE_RUN_SERVICES=idp`).

**OIDC clients (all public / PKCE):**

| Client  | Client ID                              | Callback URLs                                                                    |
| ------- | -------------------------------------- | -------------------------------------------------------------------------------- |
| Web     | `77e88611-a8b6-4eec-bfd7-7bd2bd4fe642` | `https://opencloud.<host>/`, `/oidc-callback.html`, `/oidc-silent-redirect.html` |
| Desktop | `OpenCloudDesktop`                     | `http://127.0.0.1`, `http://localhost`                                           |
| iOS     | `OpenCloudIOS`                         | `oc://ios.opencloud.eu`                                                          |
| Android | `OpenCloudAndroid`                     | `oc://android.opencloud.eu`                                                      |

Clients are created manually in Pocket ID admin. The web client uses the
UUID Pocket ID generates when the client is created as-is, with no
override — it is a public PKCE client, so the client ID is not a secret
and needs no sops entry (per
https://pocket-id.org/docs/client-examples/opencloud). Desktop and mobile
client IDs are hardcoded in the OpenCloud apps, so those three clients'
IDs must be overridden via Show Advanced Options to match; only the web
client keeps Pocket ID's generated UUID.

**User groups (created manually in Pocket ID):**

| Group                   | Custom Claim                          | Maps to OpenCloud role |
| ----------------------- | ------------------------------------- | ---------------------- |
| `opencloud_admins`      | `opencloud_role: opencloudAdmin`      | admin                  |
| `opencloud_spaceadmins` | `opencloud_role: opencloudSpaceAdmin` | spaceadmin             |
| `opencloud_users`       | `opencloud_role: opencloudUser`       | user                   |
| `opencloud_guests`      | `opencloud_role: opencloudGuest`      | user-light             |

Role mapping uses the oidc driver with `PROXY_ROLE_ASSIGNMENT_OIDC_CLAIM`
set to `opencloud_role` (see `modules/opencloud/options.nix`). Every user
must belong to at least one of these groups, and each OIDC client must
have them under Allowed Groups, or login is denied (`access_denied`) or
fails with 500 (no role claim). Add the admin user to `opencloud_admins`
in Pocket ID.

### Content Security Policy for the external IdP

The web client fetches the OIDC discovery document from the IdP via XHR
before redirecting to the authorize endpoint. The default OpenCloud CSP
only allows connections to `'self'`, so an external IdP on another domain
is silently unreachable — the client stalls on the loading screen. The
module therefore ships `csp.yaml` (generated with the host's OIDC domain
substituted) and points `PROXY_CSP_CONFIG_FILE_LOCATION` at it. Keep the
IdP domain listed in `connect-src`, `frame-src`, and `script-src`;

## Web Apps (unzip extension)

OpenCloud ships built-in web apps at build time; additional apps are picked
up from a directory that defaults to `$OC_BASE_DATA_PATH/web/assets/apps`.
This module bundles the `unzip` web extension declaratively instead of
downloading a zip in the App Store GUI (which only downloads the archive on
the client and cannot place it on the server).

Each extension is a directory containing a `manifest.json` (entrypoint +
version) and the built assets. The bundles are pinned via Nix
(`webApps = pkgs.callPackage ./drv.nix`), so apps land in the Nix store,
which then gets mounted read-only into the container's apps directory via
`${OPENCLOUD_APPS_DIR}:/var/lib/opencloud/web/assets/apps:ro`. Because the
mount target defaults to OpenCloud's apps path, no `WEB_ASSET_APPS_PATH`
override is needed.

The compose service needs a restart to (re)load apps — `darwin-rebuild
switch` recreates the container, which picks up new/updated apps.

## Constraints

- Switching a deployment's user-storage driver requires the host data
  and config directories to be cleared first — the old and new
  drivers use incompatible on-disk layouts, and the new driver will
  not read data written by the old one.
