---
description: Rules for editing Nix files in this dotfiles repository
globs: ["*.nix", "flake.nix", "flake.lock"]
alwaysApply: false
---

# Nix Development Rules

## Formatting

- Run `nix fmt` after editing Nix files to ensure consistent formatting.

## Syntax Validation

- Run `nix-instantiate --parse <file>` to verify syntax before committing.
- For flake-based files, `nix flake check` or `nix build --dry-run` can catch evaluation errors.

## Secrets Management

- Secrets are managed with sops-nix. Never hardcode secrets in Nix files.
- Use `sops` CLI to edit `secrets.yaml`; do not edit the encrypted file directly.
- Reference secrets via `config.sops.secrets.<name>.path` in Nix modules.

## Module Structure

- Follow the aggregation pattern: each directory has `darwin.nix` and/or `home.nix` that imports children.
- Never import a grandchild file directly if a child aggregation file exists.
- Use `/nix-module` skill to scaffold new modules.

## Flake Inputs Access

- Access external flake inputs through the `inputs` attribute, not as direct function arguments.
- Use `inputs.xxx` pattern: `{ inputs, system, ... }: { ... inputs.foo.packages.${system}.default ... }`.
- Do not spread inputs into specialArgs.

## Flake Lock

- Do not edit `flake.lock` directly. Use `nix flake update` or `nix flake lock --update-input <input>`.
