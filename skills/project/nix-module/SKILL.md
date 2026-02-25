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

For detailed conventions, see `references/conventions.md`.
