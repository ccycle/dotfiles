# pi Design

## Purpose

Install the `pi` coding-agent CLI as a hermetic, Cachix-cacheable Nix package, and symlink the shared AI-behavioral rules from `modules/ai-rules` into its config directory — the same live-editable symlink pattern used for Claude and Cursor.

## Non-Goals

- Building `pi` ourselves via `buildNpmPackage`/`importNpmLock` (the pattern used for `opencode-ai` in `modules/nodejs/node-tools`). Blocked by the npm behavior described below; delegated entirely to the upstream `pi.nix` flake instead.
- Using `pi.nix`'s `programs.pi.coding-agent` home-manager module. Only its `packages.<system>.coding-agent` output is consumed (exposed here as the `piPackage` special arg, alongside `herdrPackage`/`hunkPackage`). The module wraps the binary in a generated shell script that injects `rules`/`settings`/`environment` at runtime instead of writing real files, which doesn't fit this repo's convention of symlinking config files directly into the dotfiles checkout. `jail.enable` (bubblewrap sandboxing) is also part of that module and is Linux-only besides, moot for this Darwin-only repo.
- Declarative management of `~/.pi/agent/settings.json`. Nothing in this repo needs it yet; would require either hand-rolling a `home.file` block or reconsidering the `programs.pi.coding-agent` module.

## Why This Structure

`pi`'s dependency tree pulls in a package, nested several levels deep through one of its AI-provider integrations, that npm cannot install strictly from a lockfile: npm re-derives that package's requirements from the *actual* manifest embedded in its dependent's published tarball rather than trusting the lockfile, then falls back to a live registry fetch to reconcile the two. This reproduces with a plain `npm install` or `npm ci --offline`, independent of Nix, and survives editing the lockfile to remove the offending dependency entirely — so no lockfile-level fix is available. It specifically breaks `pkgs.importNpmLock.buildNodeModules` (the mechanism `modules/nodejs/node-tools/drv.nix` uses), because that mechanism reconstructs `node_modules` fully offline inside the build sandbox.

`github:lukasl-dev/pi.nix` avoids this by using plain `buildNpmPackage` with a precomputed `npmDepsHash` instead: the dependency-fetch step runs as a fixed-output derivation, which is allowed network access and is instead verified after the fact by content hash. That sidesteps the specific offline-reconstruction failure entirely. The flake also carries the source patches upstream `pi` needs to build outside its own monorepo tooling (workspace build-order fixes, vendored `models.generated.ts`/provider files, changelog URL rewrites) and stays current: `VERSION.json` is bumped by an automated daily cron job in that repo, tracking upstream releases within about a day (confirmed: pinned to `v0.84.1` here, matching npm's `latest` dist-tag at the time of writing).

The `~/.pi/agent/AGENTS.md` symlink (in `modules/ai-rules/home.nix`) relies on a real `pi` feature, not something `pi.nix` adds: `pi` reads that path as its global instruction file the same way it reads a project-level `AGENTS.md`/`CLAUDE.md`.

## Rejected Alternatives

- **`buildNpmPackage`/`importNpmLock` via `modules/nodejs/node-tools`**: blocked by the npm behavior described above.
- **`pnpm add --global` from a `home.activation` step** (mirroring `modules/herdr`'s imperative-installer pattern): worked and was implemented first, but was abandoned once `pi.nix` was found. It traded away Nix's hermeticity and Cachix caching, required network access on every `darwin-rebuild switch`, and needed an explicit `--ignore-scripts` decision to avoid running arbitrary install scripts with full user permissions outside any sandbox.
- **`node2nix`**: forbidden repository-wide — removed from nixpkgs and unmaintained.
- **`programs.pi.coding-agent.rules`**: works (verified: builds and injects the intended content via `--append-system-prompt`), but was rejected in favor of the plain `home.packages` + symlink approach above, to keep `pi` consistent with how every other agent's rules file is managed in this repo.

## Constraints

- `pi.nix` pins its own `nixpkgs` (`nixos-unstable`) rather than following this repo's `nixpkgs` input, since its build carries upstream-specific patches tested against that pin. Left un-followed deliberately — forcing `.follows` risks breaking a build that was never tested against this repo's `nixpkgs-26.05`.
- Freshness tracks `pi.nix`'s own sync cadence (daily cron in that repo) plus whenever this repo runs `nix flake update` on the `pi` input — not continuous per-build "latest" like an imperative installer would give.
- `~/.pi/agent/AGENTS.md` only gets `rules.md`, not the topic-specific `rules/nix.md`/`rules/loop-engineering.md` — a real file can only symlink to one source, and `pi` has no directory-of-files convention like Claude's `~/.claude/rules/` to point at instead. This matches how Cursor is already handled in the same file.
