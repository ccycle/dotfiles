---
name: verify-change
description: Verify code changes using syntax checking, linting, and build dry-runs. Must be run before committing any changes to Nix configuration files.
---

# Change Verification

This skill provides a comprehensive check suite to ensure that your changes to the dotfiles do not break the system.

## Usage

Run the verification script from the repository root:

```bash
skills/verify-change/scripts/check.sh
```

## Checks Performed

1.  **Syntax Check:** Parses all `.nix` files to catch syntax errors immediately.
2.  **Linting (Optional):** Runs `nixfmt` or `statix` if available to ensure code style compliance.
3.  **Build Dry-Run:** Attempts to build the darwin configuration without switching, ensuring that all dependencies and modules can be resolved.

## When to Use

- **ALWAYS** run this skill after modifying any `.nix` file.
- Use it to diagnose "why my config isn't building" issues.
