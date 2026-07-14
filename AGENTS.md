# Development Guidelines for Coding Agents

> For Claude Code quick reference (skills, profiles, settings), see [CLAUDE.md](./CLAUDE.md).

This document outlines the development policies and conventions for this dotfiles repository. Coding agents must adhere to these rules when implementing changes or adding new features.

## Communication Guidelines

- **Clarify Ambiguities:** If there is ambiguity in the user's instructions regarding the policy, always ask for clarification on the points of contention before starting actual work.
- **Verify Claims:** See the global behavioral rules in `~/.claude/CLAUDE.md` for the full verification policy. In short: never state facts without first verifying them through tool use.
- **Push Back When Needed:** You are not required to follow instructions literally at all times. If an instruction seems redundant, overly complex, or potentially dangerous, always ask for clarification before proceeding.

## Module Structure Policy

To ensure maintainability and clear dependency trees, we follow a strict **Package by Feature** aggregation pattern. For full conventions, see `skills/project/nix-module/references/conventions.md`.

**Rules:**

- **Aggregation Files:** Every directory that contains sub-modules must have a `darwin.nix` (for system config) and/or `home.nix` (for user config) that imports the corresponding files from its children.
- **Recursive Imports:** Top-level `modules/darwin.nix` imports `modules/<feature>/darwin.nix`, which in turn imports `modules/<feature>/<subfeature>/darwin.nix`.
- Never import a grandchild file directly if a child aggregation file exists.
- **Sub-modules must be directories:** Every sub-module must live in its own directory with `darwin.nix` and/or `home.nix`. Flat `<name>.nix` files as sub-modules are forbidden. Allowed support files beside aggregation files are: `options.nix`, `secrets.nix`, `drv.nix` (and drv helpers like `gemset.nix`), and data files.
- **Host modules set options only:** Host-profile modules (`modules/<hostname>/darwin.nix`) must only set option values and enable flags — they must never import sibling feature modules via `../<feature>/darwin.nix`. Host-toggled features are imported globally by `modules/darwin.nix` and gated with `enable` options.
- **Category modules are legitimate features:** Directories like `cli-tools`, `languages`, `build-tools` that group related packages by category are valid feature modules.
- **Directory hierarchy reflects dependencies:** If module A depends on module B, then B must be a child directory of A. The directory tree mirrors the dependency graph — a child is a dependency of its parent (e.g., `git/github/gh/home.nix`, not `git/gh/home.nix`).

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

We use [Agent Skills](https://agentskills.io) for task automation and guideline enforcement.

- **[nix-module](./skills/project/nix-module/SKILL.md):** Use this skill when creating new features or modules. It handles the directory structure and boilerplate generation.
- **[credentials-manager](./skills/project/credentials-manager/SKILL.md):** Use this skill for managing secrets and Nix access tokens.
- **[verify-change](./skills/project/verify-change/SKILL.md):** Use this skill to verify changes before committing. It runs syntax checks, lints, and build dry-runs.

## Legacy Guidelines

Detailed guidelines are available in the `docs/agents/` directory:

- [Bootstrap Configuration](./docs/agents/bootstrap.md)
  - Purpose and maintenance of the bootstrap profile

## Summary Checklist

When asked to implement a feature:

1. **Use `nix-module` Skill:** Start by reading `skills/nix-module/SKILL.md` and running the generation script.
2. **Use `credentials-manager` Skill:** If handling secrets, refer to `skills/credentials-manager/SKILL.md`.
3. **Check Structure:** Does it fit into an existing feature directory? If not, create `modules/<feature>`. Ensure file dependencies are clear from the structure.
4. **Separate Platforms:** Use `darwin.nix` for system config and `home.nix` for user config inside each feature directory.
5. **Verify Changes:** Run `skills/project/verify-change/scripts/check.sh` before finishing the task.
