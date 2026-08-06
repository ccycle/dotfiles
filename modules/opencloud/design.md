# OpenCloud Module Design

## Purpose

Run OpenCloud with a storage driver that keeps user files in a
human-readable directory tree, so files placed directly into the host
data directory (outside the OpenCloud web UI or sync client) become
visible to OpenCloud.

## Non-Goals

- Real-time reflection of externally-added files. Files dropped into
  the host data directory become visible after an OpenCloud restart
  or a triggered rescan, not instantly.
- Migrating existing data from the previous storage driver's on-disk
  layout. The two layouts are incompatible, and upstream provides no
  supported migration path between them; any pre-existing data must
  be re-uploaded through a client rather than copied at the
  filesystem level.

## Why This Structure

User-file storage uses the posix storage driver in its
non-collaborative sub-mode. Non-collaborative mode discovers
external filesystem changes via OpenCloud's own scan/assimilation
step rather than by watching the filesystem for events, so it works
regardless of how reliably filesystem-change notifications propagate
into the container.

System/metadata storage is intentionally left on the decomposed
driver — only user-file storage was moved to the posix driver.

### Host directory layout

User files are stored on the host at `${vol}/opencloud/user-files/`,
separate from internal OpenCloud data (metadata cache, service
configs) which lives at `${vol}/opencloud/data/`. The separation
is enforced by a dedicated Docker volume mount for the posix root.

```
${vol}/opencloud/
├── user-files/           # STORAGE_USERS_POSIX_ROOT
│   └── alice/            # STORAGE_USERS_POSIX_PERSONAL_SPACE_PATH_TEMPLATE
│       ├── Documents/    # UI tree matches disk tree
│       │   └── report.pdf
│       └── Photos/
│           └── vacation.jpg
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

- **Collaborative mode** (real-time filesystem watching): rejected
  because this stack runs OpenCloud inside a container on top of a
  bind-mounted host directory, and that virtualization layer has
  known unreliable delivery of filesystem-change notifications across
  the host/container boundary — a collaborative-mode deployment would
  silently fail to detect some externally-made changes. Collaborative
  mode also has independent limitations that would apply even with
  reliable notifications: no symlink support, no detection of files
  moved across spaces, and possible tree-size miscalculation under
  bulk edits.
- **Keeping the previous (decomposed) user-storage driver**: rejected
  because it stores files as opaque, ID-addressed blobs rather than a
  filesystem tree, so files placed directly into the host directory
  outside of OpenCloud would never be recognized.

## External OIDC (Pocket ID)

OpenCloud uses Pocket ID as its external OIDC identity provider, replacing
the built-in `idp` service (excluded via `OC_EXCLUDE_RUN_SERVICES=idp`).

**OIDC clients (all public / PKCE):**

| Client | Client ID | Callback URLs |
|--------|-----------|---------------|
| Web | `77e88611-a8b6-4eec-bfd7-7bd2bd4fe642` | `https://opencloud.<host>/`, `/oidc-callback.html`, `/oidc-silent-redirect.html` |
| Desktop | `OpenCloudDesktop` | `http://127.0.0.1`, `http://localhost` |
| iOS | `OpenCloudIOS` | `oc://ios.opencloud.eu` |
| Android | `OpenCloudAndroid` | `oc://android.opencloud.eu` |

Clients are created manually in Pocket ID admin. The web client uses the
UUID Pocket ID generates when the client is created as-is, with no
override — it is a public PKCE client, so the client ID is not a secret
and needs no sops entry (per
https://pocket-id.org/docs/client-examples/opencloud). Desktop and mobile
client IDs are hardcoded in the OpenCloud apps, so those three clients'
IDs must be overridden via Show Advanced Options to match; only the web
client keeps Pocket ID's generated UUID.

**User groups (created manually in Pocket ID):**

| Group | Custom Claim | Maps to OpenCloud role |
|-------|-------------|----------------------|
| `opencloud_admins` | `opencloud_role: opencloudAdmin` | admin |
| `opencloud_spaceadmins` | `opencloud_role: opencloudSpaceAdmin` | spaceadmin |
| `opencloud_users` | `opencloud_role: opencloudUser` | user |
| `opencloud_guests` | `opencloud_role: opencloudGuest` | user-light |

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
