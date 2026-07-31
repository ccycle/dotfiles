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
| Web | `web` | `https://opencloud.<host>/*` |
| Desktop | `OpenCloudDesktop` | `http://127.0.0.1:*` |
| iOS | `OpenCloudIOS` | `oc://ios.opencloud.com` |
| Android | `OpenCloudAndroid` | `oc://android.opencloud.com` |

Clients are created manually in Pocket ID admin (`Settings > OIDC Clients`).
The `web` client ID is set to match OpenCloud's WebFinger default so no
sops secret is needed. Desktop and mobile client IDs are hardcoded in the
OpenCloud apps.

**User groups (created manually in Pocket ID):**

| Group | Custom Claim | Maps to OpenCloud role |
|-------|-------------|----------------------|
| OpenCloud Admin | `roles: opencloudAdmin` | admin |
| OpenCloud Space Admin | `roles: opencloudSpaceAdmin` | spaceadmin |
| OpenCloud User | `roles: opencloudUser` | user |
| OpenCloud Guest | `roles: opencloudGuest` | user-light |

Role mapping uses the oidc driver with default role_claim `roles` and the
four claim values above. Add the admin user to the "OpenCloud Admin" group
in Pocket ID.

## Constraints
