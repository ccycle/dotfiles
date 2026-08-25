# Module Structure and Organization

The core principle of this structure is to ensure that **file dependencies are evident from the directory structure**. By following these rules, the file system hierarchy should reflect the actual dependency graph of the configuration.

## 1. Directory Structure: Package by Feature

Organize the `modules/` directory by **feature**, not by technical layer (e.g., `home-manager` or `darwin`).

**Rule:**

- Create a directory for each feature (e.g., `modules/git`, `modules/cachix`).
- Do **not** split `modules/` into top-level `darwin` and `home-manager` directories.

## 2. Platform Separation (nix-darwin vs home-manager)

Inside each feature directory, distinguish between configuration for `nix-darwin` and `home-manager` by file naming convention.

**Rule:**

- Use `darwin.nix` for system-level configurations (nix-darwin).
- Use `home.nix` for user-level configurations (home-manager).

**Example Structure:**

```
modules/
  my-feature/
    darwin.nix       # System-level config (nix-darwin)
    home.nix         # User-level config (home-manager)
```

## 3. Import Logic

**Rule:**

- The `home.nix` and `darwin.nix` in a parent directory must import all corresponding configuration files (`home.nix` or `darwin.nix`) present in its subdirectories.
- **No Cross-Hierarchy Imports:** Do not import files from other top-level directories (e.g. `../bootstrap/modules/git/home.nix`), with the exception of utilities (e.g. `../utils/...`).
- **Option-based coupling is allowed:** A module may read options defined in another feature (e.g. `custom.syncHomeFiles` consumed by `zsh`). Direct import of another feature's files is not.
- **Directory hierarchy must reflect dependency relationships:** If module A depends on module B (A imports or consumes B), then B must be a child (subdirectory) of A, not a sibling or parent. The directory tree should mirror the dependency graph — a child directory is a dependency of its parent. Example: `gh` (GitHub CLI) is a tool within the `github` feature, so it lives at `git/github/gh/home.nix`, not at `git/gh/home.nix`.

## 4. Nix Derivation Naming

To clearly indicate that a file contains a Nix derivation (package definition), follow this naming convention.

**Rule:**

- Name the file `drv.nix`.
- Include the package name in the directory path.
- The resulting path should look like: `.../<package-name>/drv.nix`.

**Example:**

```
modules/
  my-custom-tool/
    drv.nix       # Contains the derivation for my-custom-tool
```

## 5. Support Files

The following files may sit alongside `darwin.nix`/`home.nix` in a feature directory without being sub-modules:

- `options.nix` — NixOS-style option declarations (`mkEnableOption`, `mkOption`)
- `secrets.nix` — sops-nix secret declarations
- `drv.nix` — Nix derivations (see §4), plus helpers like `gemset.nix`
- Data files — non-Nix files consumed by the module (e.g., `compose.yaml`, `index.html`, `*.pub`)

All other `.nix` files that represent sub-features **must** live in their own subdirectory as `<subfeature>/home.nix` or `<subfeature>/darwin.nix`. Flat `<name>.nix` sub-module files are forbidden.

## 6. Host Profiles and Enable Options

Host-specific configurations live in `modules/<hostname>/darwin.nix`. These files must **only** set option values — they must never import sibling features via `../<feature>/darwin.nix`.

**Pattern:**

1. The feature declares an enable option in `options.nix`:

   ```nix
   { lib, ... }: {
     options.services.my-feature.enable = lib.mkEnableOption "My feature";
   }
   ```

2. The feature's `darwin.nix` imports `./options.nix` and gates all config with `lib.mkIf`:

   ```nix
   { config, lib, ... }: {
     imports = [ ./options.nix ];
     config = lib.mkIf config.services.my-feature.enable { ... };
   }
   ```

3. `modules/darwin.nix` imports the feature unconditionally.
4. The host module enables it:

   ```nix
   { ... }: { services.my-feature.enable = true; }
   ```

**Option namespace rules:**

- Use `services.<name>` when nix-darwin does not already declare that namespace.
- If nix-darwin owns `services.<name>` (e.g., `services.dnsmasq`), use `custom.<name>` to avoid collisions. Precedent: `custom.nix.accessTokens`, `custom.syncHomeFiles`, `custom.dnsmasq`.
- Extending an upstream namespace with a scoped sub-option is also acceptable. Precedent: `services.tailscale.splitDns.enable`.

## 7. Category Modules

Directories that group related packages by category (e.g., `cli-tools`, `languages`, `build-tools`, `databases`) are legitimate feature modules. They exist to avoid a monolithic package list in the root configuration.

**Rule:**

- Each category module has `home.nix` that declares `home.packages`.
- Pinned package sets (e.g., `pkgs-2211`) are received as module arguments.

## 8. Darwin-Only Home Config via sharedModules

When a home-manager module should only apply on darwin (e.g., brew cask installations), inject it via `home-manager.sharedModules` in the feature's `darwin.nix` rather than importing it from the global `modules/home.nix`.

**Precedent:** `modules/docker/orbstack/darwin.nix` injects `orbstack/home.nix` via `home-manager.sharedModules`.
