---
name: update-vendor-hash
description: Refresh a stale `vendorHash` on a buildGoModule package (gcx, gwq) after a flake.lock bump advances its go.mod deps. Use when a build fails with a vendorHash mismatch or "inconsistent vendoring" error.
---

# Update vendorHash

## Overview

`modules/grafana/drv.nix` (gcx) and `modules/git/gwq/drv.nix` (gwq) build Go
CLIs straight from an upstream flake input (`inputs.gcx`, `inputs.gwq`, both
`flake = false`) via `buildGoModule`. Unlike this repo's npm packages
(`importNpmLock` reads per-package hashes straight from `package-lock.json`)
or Rust packages (`cargoLock.lockFile` reads per-crate hashes straight from
`Cargo.lock`), Go's vendor directory has no such lockfile-derived path in
nixpkgs — `vendorHash` pins a single Fixed-Output-Derivation hash for the
whole `vendor/` tree, and it goes stale whenever `nix flake update` advances
`gcx`/`gwq` to a revision whose `go.mod` changed.

Two failure symptoms, same root cause (the pinned `vendorHash` no longer
matches the current input's `go.mod`/`go.sum`):

- A fixed-output hash mismatch.
- `go: inconsistent vendoring ... not marked as explicit in vendor/modules.txt`
  — happens instead of a hash mismatch when a stale vendor tree for the old
  hash was reused from the store/binary cache, so fetching succeeds but the
  Go build step fails.

## Workflow

`nix-update` is already part of this repo's toolchain
(`modules/nix/home.nix`, `flake.nix`'s `devShells.default`) and refreshes
`vendorHash` correctly for this exact package shape — a flake output whose
`src` is passed in externally via `callPackage`, not declared inline.

```bash
nix-update --flake --version skip gcx --build
nix-update --flake --version skip gwq --build
```

- `--flake` — resolve `gcx`/`gwq` from this flake's `packages.<system>.<attr>` output, not nixpkgs.
- `--version skip` — this repo pins the source via `flake.lock`, not a version string (`version = "master"` in both `drv.nix`); never let nix-update touch it.
- `--build` — after rewriting the hash, actually build the package to confirm it succeeds, not just that the vendor FOD hash matches.

Run only for whichever package's flake input actually advanced (check
`git diff flake.lock` to see which of `gcx`/`gwq` moved).

## Verify

```bash
git diff -- modules/grafana/drv.nix modules/git/gwq/drv.nix
```

Only the `vendorHash` line should change. Then run the repo's normal checks:

```bash
nix fmt -- modules/grafana/drv.nix modules/git/gwq/drv.nix
.agents/skills/verify-change/scripts/check.sh
```

Note: `verify-change`'s build dry-run does **not** catch a stale
`vendorHash` by itself — `nix build --dry-run` never reaches the build
phase where vendoring is checked. That's what this skill's `--build` step
is for. The full real-build safety net for this class of breakage is the
CI "Build and push to Attic" step in `.forgejo/workflows/verify.yaml`.

## Do not

- Do not hand-edit `vendorHash` with the `lib.fakeHash` trick and copy the
  `got:` value manually — `nix-update` already does this, position-aware in
  the source file, without the risk of leaving `lib.fakeHash` committed if a
  step is skipped.
- Do not pass a `--version` value other than `skip` — these packages track
  `flake.lock`, not an upstream version tag.
- This applies to any future `buildGoModule` package added under `modules/`
  with the same external-`src`-via-`callPackage` shape, not just gcx/gwq.
