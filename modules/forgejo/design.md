# Forgejo Module Design

## Why This Structure

**The SQLite DB sits on a Docker named volume, split out from the bulk
git data.** Forgejo's data tree mixes two very different things: bulk
git content (repositories, LFS objects, SSH host keys) and a small
SQLite database plus app state (config, attachments, sessions, queues,
indexers). The bulk content stays on the external drive via the
existing host bind mount — it's large, and it isn't SQLite, so
virtiofs is fine for it. The SQLite portion is overridden by a second,
more specific named-volume mount nested inside the same tree, moving
only the DB onto VM-internal storage. This is the same underlying fix
as `modules/pocket-id/design.md` (host bind mounts on OrbStack are
served over virtiofs, and SQLite crashes with `SQLITE_BUSY` /
`SQLITE_IOERR_SHMLOCK` there as soon as a second process opens the
live DB), applied as a split rather than a full swap, since unlike
Pocket ID, most of Forgejo's data genuinely belongs on the external
drive.

The split relies on Docker mounting the more specific destination path
on top of the less specific one — the named volume shadows that one
subdirectory of the host bind mount. This was verified empirically
before relying on it: a fresh named volume mounted at that path is
auto-chowned to the container's app user by Forgejo's own entrypoint,
so no extra ownership handling was needed (unlike some other
named-volume migrations, Forgejo has no separate secret file that
needs its own bind mount).

## Rejected Alternatives

- **Moving all of `/data` (including git repositories and LFS objects)
  onto a named volume.** That data is large and not SQLite-fragile;
  keeping it on the external drive's host bind mount preserves
  host-visible backups and avoids consuming VM-internal disk space for
  content that doesn't need VM-internal storage.
