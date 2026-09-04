# Attic Module Design

## CI Cache Push Is Non-Fatal

**`.forgejo/workflows/verify.yaml`'s `attic push` step must not fail the
job.** The build (`nix build .#darwinConfigurations....system`) and the
cache push are two independent concerns: a push failure means the CI
machine's local Attic cache didn't get warmed, not that the
configuration is broken. `scripts/darwin-rebuild.sh` already treats
`attic push` failure as a warning rather than a fatal error for exactly
this reason; the CI workflow step is aligned to the same pattern.

## `orbstack-2.2.1-20628` Can't Be Cached: Large-NAR Push Limitation, Not DB Corruption

**Pushing the `orbstack` package (a ~680 MB `.app` bundle NAR) to the
`dotfiles` cache on `dotfiles-ci`/`cache.mac-mini-m4-pro.internal`
consistently fails with `RequestError: General request error: Bad NAR
Hash or Size`.** This was investigated by querying the atticd SQLite DB
directly (`/var/lib/atticd/server.db`, readable with
`sqlite3 "file:...?mode=ro&immutable=1"` since the DB has no WAL
sidecar and is world-readable) and reproducing the push standalone on
the host running atticd (`attic push dotfiles
/nix/store/<hash>-orbstack-2.2.1-20628`):

- No `object` row exists for this store path's hash in any cache, and
  no `nar`/`chunk` row is in a stuck/pending state - this package has
  never once been cached successfully, ruling out a corrupted leftover
  DB entry as the cause (the kind of problem
  `scripts/attic-cleanup-orphans.sh` fixes).
- The error string traces (via `strings` on the `atticd` binary) to
  `server/src/api/v1/upload_path.rs:307-310` in
  [zhaofengli/attic](https://github.com/zhaofengli/attic) - the final
  check after all chunks are uploaded and reassembled, comparing the
  recomputed NAR hash/size against what the client declared. At the
  default chunking settings (`nar-size-threshold`/`avg-size` = 64 KiB,
  `max-size` = 256 KiB), a 680 MB NAR decomposes into on the order of
  10,000+ chunks, making this a large-NAR upload path that this
  package reproducibly exercises.

Given it reproduces standalone against our own atticd (not just under
CI's environment) and there is no corrupted state to clear, this reads
as an Attic-side limitation/bug with very large single-file NARs rather
than something fixable from this repo's config or database. The
non-fatal CI push above keeps an un-cacheable large binary from
blocking merges regardless of whether the underlying issue is fixed.

**Mitigation: larger chunk sizes.** `chunking.min-size`/`avg-size`/
`max-size` were raised from Attic's own upstream defaults
(16K/64K/256K) to 256K/1M/4M. This isn't a confirmed root-cause fix -
the exact failure mechanism inside the reassembly/verification path
wasn't pinned down - but it cuts the chunk count for a 680MB NAR from
10,000+ down to a few hundred, shrinking the exposure to whatever
per-chunk transient or edge-case failure is causing the mismatch.
Downside is coarser dedup across packages, which doesn't matter for a
mostly-unshared macOS `.app` bundle like this one.
