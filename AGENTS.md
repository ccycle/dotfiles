# Development Guidelines for Coding Agents

This document outlines the development policies and conventions for the `dotfiles-work` repository. Coding agents must adhere to these rules when implementing changes or adding new features.

## Communication Guidelines

- **Clarify Ambiguities:** If there is ambiguity in the user's instructions regarding the policy, always ask for clarification on the points of contention before starting actual work.

## Code Reuse Policy

The `dotfiles-work` repository is an extension of the main `dotfiles` repository (usually provided as a flake input).

**Rule:**
- **Reuse first:** Before creating a new module, check if a similar module exists in `dotfiles` and import or configure it.
- **Minimize duplication:** Do not copy-paste code from `dotfiles`. Use imports or overlays.
- `dotfiles-work` should assume the existence of `dotfiles` logic and focus on work-specific overrides, secrets, or additional tools.

## Module Structure Policy

To ensure maintainability and clear dependency trees, we follow a strict aggregation pattern.

**Rule:**
- **Aggregation Files:** Every directory that contains sub-modules must have a `darwin.nix` (for system config) and/or `home.nix` (for user config) that imports the corresponding files from its children.
- **Recursive Imports:** Top-level `modules/darwin.nix` imports `modules/<feature>/darwin.nix`, which in turn imports `modules/<feature>/<subfeature>/darwin.nix`.
- Never import a grandchild file directly if a child aggregation file exists.

## Flake Inputs Access Policy

Modules must access external flake inputs through the `inputs` attribute, not as direct function arguments.

**Rule:**
- **Use `inputs.xxx`:** Always receive `inputs` in the module arguments and access dependencies as `inputs.sops-nix`, `inputs.attic`, etc.
- **Do not spread inputs into specialArgs:** `mkSpecialArgs` must not use `inputs // { ... }`. Only explicitly defined attributes (`pkgs-*`, `tailscalePackage`, `system`, etc.) and `inputs` itself should be in `specialArgs`.
- **Derived values are OK:** Convenience aliases like `pkgs-unstable`, `tailscalePackage` that are computed from inputs may remain as explicit `specialArgs`.

```nix
# Good
{ inputs, system, ... }:
{ home.packages = [ inputs.attic.packages.${system}.default ]; }

# Bad - direct input as argument
{ attic, system, ... }:
{ home.packages = [ attic.packages.${system}.default ]; }
```

## Configuration Policy

**Rule:**
- **No Default Fallbacks:** Do not use default values for critical configurations. Explicitly require the user or the environment to provide necessary values (e.g., using `mkOption` without a default, or `lib.mkIf` checks). Avoid "magic" defaults that might be incorrect in a different context.

## Agent Skills

We are migrating to [Agent Skills](https://agentskills.io) for task automation and guideline enforcement.

- **[nix-module](./skills/nix-module/SKILL.md):** Use this skill when creating new features or modules. It handles the directory structure and boilerplate generation.
- **[credentials-manager](./skills/credentials-manager/SKILL.md):** Use this skill for managing secrets and Nix access tokens.
- **[verify-change](./skills/verify-change/SKILL.md):** Use this skill to verify changes before committing. It runs syntax checks, lints, and build dry-runs.

## Legacy Guidelines

Detailed guidelines are available in the `docs/agents/` directory:

- [Bootstrap Configuration](./docs/agents/bootstrap.md)
  - Purpose and maintenance of the bootstrap profile

## Summary Checklist

When asked to implement a feature:

1. **Use `nix-module` Skill:** Start by reading `skills/nix-module/SKILL.md` and running the generation script.
2. **Use `credentials-manager` Skill:** If handling secrets, refer to `skills/credentials-manager/SKILL.md`.
3. **Check Structure:** Does it fit into an existing feature directory? If not, create `modules/<feature>`. Ensure file dependencies are clear from the structure.
4. **Separate Platforms:** Use `darwin/` for system config and `home-manager/` for user config.
5. **Code Reuse:** Check `dotfiles` repo first. Import/overlay existing modules instead of copying code (see **Code Reuse Policy**).
6. **Verify Changes:** Run `skills/verify-change/scripts/check.sh` before finishing the task.
