---
name: verify-change
description: Verify code changes using syntax checking, linting, and build dry-runs. Must be run before committing any changes to Nix configuration files.
---

# Change Verification

This skill provides a comprehensive check suite to ensure that your changes to the dotfiles do not break the system.

## Usage

Run the verification script from the repository root:

```bash
skills/project/verify-change/scripts/check.sh [profile]
```

Available profiles: `bootstrap`, `private`, `mac-mini-m4`. If no profile is specified, all compatible profiles will be checked.

## Checks Performed

1.  **Syntax Check:** Parses all `.nix` files using `nix-instantiate --parse` to catch syntax errors immediately.
2.  **Build Dry-Run:** Attempts to build the darwin configuration for the specified (or all) profiles without switching, ensuring that all dependencies and modules can be resolved.
    - **bootstrap**: Builds `./bootstrap#darwinConfigurations.bootstrap.<system>.system`
    - **private**: Builds `.#darwinConfigurations.private.<system>.system`
    - **mac-mini-m4**: Builds `.#darwinConfigurations.mac-mini-m4.system` (if on aarch64-darwin)

## When to Use

- **ALWAYS** run this skill after modifying any `.nix` file.
- Use it to diagnose "why my config isn't building" issues.
