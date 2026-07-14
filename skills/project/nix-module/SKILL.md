---
name: nix-module
description: Create a new feature module in the dotfiles following the 'Package by Feature' directory structure. Handles creation of darwin.nix and home.nix, and updates parent imports.
---

# Nix Module Generator

This skill automates the creation of new Nix modules in the `modules/` directory, ensuring compliance with the repository's strict directory structure rules.

## Usage

Run the generation script to create a new module structure:

```bash
skills/project/nix-module/scripts/generate-module.sh <module-name>
```

This will:
1. Create `modules/<module-name>/`
2. Create `modules/<module-name>/darwin.nix` (System config)
3. Create `modules/<module-name>/home.nix` (User config)
4. Verify or update `modules/darwin.nix` and `modules/home.nix` to import the new module.

## Rules

- **Package by Feature:** All files related to a feature go into `modules/<feature>/`.
- **Platform Separation:**
  - `darwin.nix`: nix-darwin configuration.
  - `home.nix`: home-manager configuration.
- **Strict Imports:** Parent modules must explicitly import their children.
- **No flat sub-modules:** Sub-features must be directories with their own `home.nix`/`darwin.nix`, not flat `<name>.nix` files.

## Host-Toggled Features

For features that should only activate on specific hosts (e.g., server services):

1. Create `options.nix` with an enable option.
2. Gate the feature's `darwin.nix` config with `lib.mkIf`.
3. Import the feature from `modules/darwin.nix` (unconditionally).
4. Set `enable = true` in the host module (`modules/<hostname>/darwin.nix`).

See `references/conventions.md` §6 for the full pattern and namespace rules.

For detailed conventions, see `references/conventions.md`.
