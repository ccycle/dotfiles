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

## Constraints

- Switching a deployment's user-storage driver requires the host data
  and config directories to be cleared first — the old and new
  drivers use incompatible on-disk layouts, and the new driver will
  not read data written by the old one.
