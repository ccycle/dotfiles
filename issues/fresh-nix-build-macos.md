# `nix build` fails on macOS with `attribute '"plan.md"' missing` in `lib.fileset`

- **Upstream:** https://github.com/sinelaw/fresh

## Summary

`nix build github:sinelaw/fresh` fails on macOS (case-insensitive APFS) with an error in `lib.fileset`.

## Environment

- macOS (aarch64-darwin), case-insensitive APFS
- Nix 2.31.2
- Tested at commit b64db9e6 (HEAD) and several older commits — all fail with the same error

## Steps to reproduce

```bash
nix build github:sinelaw/fresh
```

## Error

```
error: attribute '"plan.md"' missing
at /nix/store/...-source/lib/fileset/internal.nix:494:37:
    493|                 # We do +2 because builtins.split is an interleaved list of the inbetweens and the matches
    494|                 recurse (index + 2) localTree.${elemAt components index}
         |                                     ^
    495|             else
```

## Possible cause

The repository contains `PLAN.md` at the root. On macOS's case-insensitive filesystem, `lib.fileset` (or `crane`'s `commonCargoSources`) may be resolving `plan.md` (lowercase) as a path component, but the Nix store entry uses `PLAN.md` (uppercase), causing the attribute lookup to fail.

This does not reproduce on case-sensitive filesystems (likely why CI passes).

## Workaround

Building with `rustPlatform.buildRustPackage` directly (bypassing the flake's `lib.fileset` source filtering) works without issues.
