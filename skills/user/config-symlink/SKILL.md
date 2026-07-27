---
name: config-symlink
description: Add a config file to dotfiles with symlink deployment via home-manager
---

# Config Symlink

## Overview

When adding or managing a configuration file for a tool, place the source file in the dotfiles repo and deploy it as a symbolic link using home-manager's `mkOutOfStoreSymlink`. This keeps all config files version-controlled and editable in-place.

## Workflow

1. **Place the Source File**
   - Add the config file under the appropriate feature module directory: `modules/<feature>/`.
   - If the feature module does not exist yet, create it following the repo's "Package by Feature" structure.

2. **Register the Symlink in home.nix**
   - Open (or create) the `home.nix` for the feature module.
   - Add a `home.file` entry using `config.lib.file.mkOutOfStoreSymlink` to link the source to the target path.
   - Use the dynamic repo root: `${config.programs.git.settings.ghq.root}/github.com/ccycle/dotfiles/...`.
   - Example:
     ```nix
     home.file."${config.home.homeDirectory}/.config/tool/config.toml".source =
       config.lib.file.mkOutOfStoreSymlink
         "${config.programs.git.settings.ghq.root}/github.com/ccycle/dotfiles/modules/<feature>/config.toml";
     ```

3. **Verify**
   - Run the `verify-change` skill to check the Nix configuration is valid.
   - After rebuilding, confirm the symlink resolves to the source in the dotfiles repo.
   - Use `readlink -f <target>` (or read the file's contents), not just `ls -la <target>`. A plain `ls -la` only shows the first hop, which points into the nix store and looks unlinked from dotfiles — `mkOutOfStoreSymlink` deploys through an intermediate store path that itself symlinks out to the dotfiles file, so only the fully-resolved path confirms the live link.
