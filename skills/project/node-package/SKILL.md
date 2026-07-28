---
name: node-package
description: Add or update an npm-managed CLI tool in modules/nodejs/node-tools (package.json + package-lock.json), built via buildNpmPackage/importNpmLock. Use when adding a new Node.js CLI tool that isn't packaged in nixpkgs, or bumping an existing one's version (e.g. opencode-ai).
---

# Node Package Add/Update

## Overview

CLI tools written in Node.js/npm that aren't packaged in nixpkgs are declared in
`modules/nodejs/node-tools/package.json` and built by
`modules/nodejs/node-tools/drv.nix` via `pkgs.importNpmLock` + `pkgs.buildNpmPackage`.
This builds directly from `package-lock.json` — no node2nix, no manual hash pinning.
`modules/nodejs/home.nix` installs the resulting derivation as a single package
(`callPackage ./node-tools/drv.nix { }`); every binary under its `node_modules/.bin`
is exposed automatically.

## Workflow

### Add a new package

1. Add the dependency to `modules/nodejs/node-tools/package.json` under
   `dependencies`. Use `"latest"` for tools that should always track the newest
   release, or a semver range for tools pinned to a specific line.
2. Regenerate `package-lock.json` **without** creating `node_modules`:
   ```bash
   cd modules/nodejs/node-tools
   npm install --package-lock-only
   ```

### Update an existing package's version

1. Force re-resolution of that one package (plain `npm install --package-lock-only`
   does not re-check packages already satisfied by the lockfile, even ones pinned
   to `"latest"`):
   ```bash
   cd modules/nodejs/node-tools
   npm install <package>@latest --package-lock-only
   ```
2. This rewrites the `package.json` range to `^<resolved-version>`. If the
   dependency was meant to always track latest, revert that line back to
   `"latest"` afterward — `package-lock.json` keeps the newly resolved version
   pinned regardless of what `package.json` says, so reverting doesn't undo the
   update.

### Verify

1. Build the derivation directly and check the binary:
   ```bash
   nix build --impure --expr '
     let pkgs = import <nixpkgs> {}; in
     pkgs.callPackage ./modules/nodejs/node-tools/drv.nix { nodejs = pkgs.nodejs; }
   '
   ./result/bin/<binary> --version
   rm result
   ```
2. Run the `verify-change` skill for the full syntax/structure/build-dry-run check.

## Do not use node2nix

This module previously shipped node2nix-generated files (`default.nix`,
`node-env.nix`, `node-packages.nix`). node2nix was removed from nixpkgs
(2026-03-03, alongside the retirement of the `nodePackages` set) and is
unmaintained upstream — regenerating it produces broken output (empty
`sources`). The module was migrated to `drv.nix`, which builds straight from
`package-lock.json`. Do not reintroduce node2nix or its generated files.
