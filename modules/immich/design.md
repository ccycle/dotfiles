# Immich Module Design

## Purpose

Read photo/video masters from `${vol}/photo` on the shared external
volume as an Immich external library, instead of requiring every
photo to be uploaded through Immich's own upload path. Immich is the
sole manager of this directory — see "Non-Goal: Declarative
External-Library Provisioning" and the note below on why an
OpenCloud-distributed layout was tried and dropped.

## Why the Mount Is rw, Not ro

External library import paths are commonly mounted read-only, since
Immich only needs to read the originals. This deployment mounts
`photoDir` read-write instead: Immich's XMP sidecar write-back (the
Sidecar Write job, and any in-app metadata edit) fails silently on a
read-only mount — favoriting or tagging a photo appears to succeed in
the UI but the change is never persisted to either the `.xmp` sidecar
or, on next scan, is lost, because it's re-read from the (unwritable)
sidecar during the metadata-extraction pass. This is a known upstream
gap, not a misconfiguration: https://github.com/immich-app/immich/issues/10538.
A read-only mount would silently discard user edits, which is worse
than the extra exposure of a writable mount for this deployment.

## Non-Overlap With uploadDir

`photoDir` (`${vol}/photo`, mounted at `/mnt/media/photo`) must never
be the same path as, or nested inside, `uploadDir` (`${vol}/immich/upload`,
mounted at `/usr/src/app/upload`). Upstream explicitly prohibits an
external library import path overlapping `UPLOAD_LOCATION` — Immich's
own upload/thumbnail management assumes exclusive ownership of that
tree. `modules/immich/darwin.nix` derives both paths from the same
`vol`, but as sibling directories (`immich/upload/` vs `photo/`), so
this can't regress by accident as long as neither default is edited
independently of the other.

## Sync Method: Watch + Scan, Not Watch Alone

`services.immich.options.nix` writes `library.watch.enabled: true`
into the generated system-config file (the same file used for OIDC,
`IMMICH_CONFIG_FILE`) alongside `library.scan.enabled: true` with a
daily `cronExpression`. Automatic library watching is upstream-labeled
experimental, and (like OpenCloud's collaborative posix mode, see
`modules/opencloud/design.md`) depends on inotify events crossing the
OrbStack container/host boundary reliably — validate this before
depending on watch-only visibility. The daily cron scan is the
fallback that makes visibility eventually-consistent even if watch
silently misses events, matching the "reliable base" role scan plays
for OpenCloud's own collaborative-mode fallback.

## Non-Goal: Declarative External-Library Provisioning

This module mounts and scans `photoDir`, but does **not** create the
Immich external library resource itself. Unlike system config
(`library.scan`/`library.watch`, OAuth), an external library is a
per-user database row (`POST /api/libraries`, requires an `ownerId`)
rather than something `IMMICH_CONFIG_FILE` or an env var can declare,
and the owning user only exists after their first OIDC-autoprovisioned
login. Create the library once, manually, via Administration >
External Libraries in the Immich UI (or a one-off authenticated API
call), pointing its import path at `/mnt/media/photo` — the container
path this module mounts `photoDir` to.

## Rejected Alternatives

- **Distributing `${vol}/photo` via OpenCloud share links**
  (bind-mounting it into OpenCloud's posix tree): rejected after
  hitting real defects in OpenCloud's handling of externally-mounted
  directories (both a personal-space and a project-space variant were
  tried) — see `modules/opencloud/design.md`'s "Rejected
  Alternatives" for the specifics. Immich reading `${vol}/photo`
  directly, with no OpenCloud involvement, was unaffected by any of
  this and needed no changes.

## Non-Goal: Mobile-Upload Consolidation

Photos taken on a phone still land in `uploadDir` via the mobile app,
not directly in `photoDir`. Periodically moving them into `${vol}/photo`
(with their `.xmp` sidecars, so metadata travels with the file) is a
manual/future step, intentionally out of scope here. Note the
trade-off if that move is performed: favorites, album membership, and
face-recognition data are stored only in Immich's database, keyed to
the original asset — moving a file out of `uploadDir` and re-importing
it from `photoDir` as a new external-library asset loses that
metadata. Only file-level metadata that round-trips through XMP
(rating, keywords, GPS, capture time, etc.) survives the move.
