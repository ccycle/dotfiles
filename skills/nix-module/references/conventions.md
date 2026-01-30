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

**Example:**

Directory structure:

```
modules/
  darwin.nix        # Parent darwin.nix
  home.nix          # Parent home.nix
  feature-a/
    darwin.nix      # Child darwin.nix
    home.nix        # Child home.nix
  feature-b/
    darwin.nix      # Child darwin.nix
    home.nix        # Child home.nix
```

Content of `modules/home.nix`:

```nix
{ ... }:
{
  imports = [
    ./feature-a/home.nix
    ./feature-b/home.nix
  ];
}
```

Content of `modules/darwin.nix`:

```nix
{ ... }:
{
  imports = [
    ./feature-a/darwin.nix
    ./feature-b/darwin.nix
  ];
}
```

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
