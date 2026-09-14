---
name: verify-change
description: Verify code changes using syntax checking, linting, and build dry-runs. Must be run before committing any changes to Nix configuration files.
---

# Change Verification

This skill provides a comprehensive check suite to ensure that your changes to the dotfiles do not break the system.

## Usage

Run the verification script from the repository root:

```bash
.agents/skills/verify-change/scripts/check.sh [profile]
```

Profiles are discovered from the flake: `bootstrap`, `private`, `mac-mini-m4`, `mac-mini-m4-pro`. If no profile is specified, all profiles compatible with the current system (architecture) are checked.

## Checks Performed

1.  **Syntax Check:** Parses all `.nix` files using `nix-instantiate --parse` to catch syntax errors immediately.
2.  **Structure Check:** Validates the Package by Feature layout of `modules/` (aggregation imports, support-file whitelist, no cross-hierarchy imports, host modules set options only). Rules are declared in `scripts/package-by-feature/rules.nix` and evaluated by `scripts/package-by-feature/check.nix`; to allow an intentional exception, edit `rules.nix` (e.g. `allowUnimported`, `exemptPaths`).
3.  **Build Dry-Run:** Attempts to build the darwin configuration for the specified (or all) profiles without switching, ensuring that all dependencies and modules can be resolved.
    - **bootstrap**: Builds `.#darwinConfigurations.bootstrap.<system>.system`
    - **private**: Builds `.#darwinConfigurations.private.<system>.system`
    - **mac-mini-m4** / **mac-mini-m4-pro**: Builds `.#darwinConfigurations.<profile>.system` (if on aarch64-darwin)
    - **Host awareness:** Machine-local storage (`.local/storage`) is only valid for the current host. Profiles whose declared `networking.hostName` differs from the current host are dry-run against a generated placeholder storage config, so their eval correctness is still validated without failing on missing volume assertions. Host-agnostic profiles (no pinned hostName, e.g. `private`, `bootstrap`) use the real machine config.
4.  **Expected Binaries:** If any module declares an `expected-bins.txt` (one binary name per line, colocated with the module that adds the package - see `modules/cli-tools/expected-bins.txt` for a reference example), builds that profile's real closure (both `environment.systemPackages`'s `sw/bin` and each home-manager user's `home.path/bin` - a package attribute name doesn't always match its binary name, e.g. `ripgrep` -> `rg`) and confirms every declared binary is actually present. Skipped entirely (no extra build) when no module declares one.

## When to Use

- **ALWAYS** run this skill after modifying any `.nix` file.
- Use it to diagnose "why my config isn't building" issues.
