# Navidrome Module Design

## Purpose

Serve the music library from `${vol}/music` on the shared external
volume rather than a Navidrome-private copy, so music placed there
directly (Finder/SMB/rsync) becomes streamable without duplication or
a sync step. Navidrome is the sole manager of this directory — see
"Rejected Alternatives" for why a shared/OpenCloud-distributed layout
was tried and dropped.

## Why the Mount Stays ro

`musicDir` is mounted `:ro`. Navidrome has no library-write feature
(`ND_ENABLEDOWNLOADS`, `ND_ENABLESHARING`, and `ND_ENABLEUSEREDITING`
are all disabled) — it only ever reads the library to build its
index, so a read-only mount loses nothing and keeps Navidrome unable
to modify files it doesn't own.

## Ingest and Discovery

Files arrive in `${vol}/music` via a direct host-side copy
(Finder/SMB/rsync — rsync **must** pass `--xattrs`, or extended
attributes on the copied files are silently dropped). Navidrome
discovers new/changed files only via its own scan
(`ND_SCANSCHEDULE=1h`), not a live filesystem watch — new music can
take up to an hour to appear.

## Rejected Alternatives

- **Distributing `${vol}/music` via OpenCloud share links**
  (bind-mounting it into OpenCloud's posix tree, alongside a second
  ingest path for uploads through OpenCloud itself): rejected after
  hitting real defects in OpenCloud's handling of externally-mounted
  directories (both a personal-space and a project-space variant were
  tried) — see `modules/opencloud/design.md`'s "Rejected
  Alternatives" for the specifics. Navidrome reading `${vol}/music`
  directly, with no OpenCloud involvement, was unaffected by any of
  this and needed no changes.
