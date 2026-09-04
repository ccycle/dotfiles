# Attic Module Design

## CI Cache Push Is Non-Fatal

**`.forgejo/workflows/verify.yaml`'s `attic push` step must not fail the
job.** The build (`nix build .#darwinConfigurations....system`) and the
cache push are two independent concerns: a push failure means the CI
machine's local Attic cache didn't get warmed, not that the
configuration is broken. `scripts/darwin-rebuild.sh` already treats
`attic push` failure as a warning rather than a fatal error for exactly
this reason; the CI workflow step is aligned to the same pattern.

## `orbstack-2.2.1-20628` Push Failures Were Local Store Corruption, Not Attic

**A `Bad NAR Hash or Size` error when pushing `orbstack` (a ~680 MB
`.app` bundle) to the `dotfiles` cache was initially misdiagnosed as an
Attic-side large-NAR limitation - it was actually silent corruption of
that one store path on the host's own Nix store.** `nix store verify
--no-trust /nix/store/<hash>-orbstack-2.2.1-20628` was the measurement
that found the real cause:

```
path '...' was modified! expected hash 'sha256:0pmyk8ml...', got 'sha256:098ysr7k...'
```

The registered hash (Nix's SQLite path database) no longer matched the
path's actual on-disk content. `attic push` reads store content
trusting that database, so it faithfully streamed the corrupted bytes
and Attic's server-side reassembly check (`server/src/api/v1/upload_path.rs:307-310`
in [zhaofengli/attic](https://github.com/zhaofengli/attic)) correctly
rejected the mismatch. Two things pointed away from Attic and were
false leads:

- Querying the atticd DB directly (`/var/lib/atticd/server.db`,
  readable with `sqlite3 "file:...?mode=ro&immutable=1"` since it has
  no WAL sidecar and is world-readable) found no stuck `object`/`nar`/
  `chunk` rows for this path - ruling out server-side leftover
  corruption (the kind `scripts/attic-cleanup-orphans.sh` fixes), but
  not ruling out *client-side* (local store) corruption.
- Raising `chunking.min-size`/`avg-size`/`max-size` from Attic's
  upstream defaults (16K/64K/256K) to 256K/1M/4M, on the theory that
  fewer chunks meant less exposure to a per-chunk transient failure,
  had **no effect** - the push failed identically afterward. That null
  result is what motivated checking local store integrity instead of
  digging further into Attic's chunking internals. The larger chunk
  sizes were left in place anyway (harmless, and the final successful
  push after the real fix still showed healthy 27% dedup), but they
  are not why the push started working.

### Repairing a live, corrupted store path

`nix store repair`/`nix-store --repair-path` is the sanctioned tool for
a corrupted-but-still-live path (one that's part of the current system/
home-manager generation, so plain `nix-store --delete` refuses it
without `--ignore-liveness`). It failed here with a Nix bug:

```
error: filesystem error: in rename: Not a directory [".../OrbStack_v2.2.1_20628_arm64.dmg"] [".../OrbStack_v2.2.1_20628_arm64.dmg/.old-<pid>-<rand>"]
```

`orbstack`'s derivation unpacks a `.dmg` fetched by a separate
fixed-output derivation; repairing `orbstack` transitively tries to
repair that `.dmg` output too, and attic hit a Nix bug where repair's
backup-rename step assumes it can nest `.old-<pid>-<rand>` *inside*
the output path - which fails for a plain-file (non-recursive) output
like a single `.dmg`, since a file can't have a child path. This
reproduced consistently regardless of whether the `.dmg` already
existed on disk.

**Workaround: fix the non-live dependency first, normally.** The
`.dmg` fetch output wasn't itself reachable from any live GC root (only
a transitive build input, not a runtime dependency of the final
`orbstack` closure), so `nix-store --delete <path>` worked on it
directly - unlike `rm`, this atomically clears both the file and its
DB row. A plain `nix-store --realise <drv>` afterward then did a
genuine fresh rebuild (re-fetching the `.dmg`) instead of trusting a
stale "valid" DB entry, because there was no longer a DB entry to
trust. With the `.dmg` dependency now valid, `sudo nix-store --store
local --repair-path <orbstack-path>` no longer needed to touch it and
completed cleanly - `repair-path` requires `--store local` (bypassing
the nix-daemon, which doesn't implement this operation remotely) and
therefore root.

The CI push step was still made non-fatal (matching
`scripts/darwin-rebuild.sh`'s existing pattern) so a future one-off
cache push failure - for whatever reason - doesn't block merges; this
particular failure just happened to have an actual fixable root cause.
