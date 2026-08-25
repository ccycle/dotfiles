---
name: darwin-rebuild
description: Apply Darwin system configuration by running scripts/darwin-rebuild.sh with the appropriate profile. Use this after modifying Nix configuration files and passing verify-change checks.
---

# Darwin Rebuild

This skill applies the nix-darwin system configuration to the local machine using `scripts/darwin-rebuild.sh`.

## Profile Selection Policy

When invoking this skill, determine the profile automatically:

1. **Auto-discover from hostname**: Run `hostname` (or check `uname -n`) and match the result against the available `darwinConfigurations` in `flake.nix`. Each profile sets `networking.hostName` to its own name (e.g., `mac-mini-m4-pro` profile sets `networking.hostName = "mac-mini-m4-pro"`), so the current hostname directly identifies the correct profile.
2. **Fallback to `private`**: If the hostname does not match any profile in `darwinConfigurations`, use `private` as the default profile.
3. **`bootstrap` is never auto-selected**: The `bootstrap` profile must always be explicitly requested by the user.

## Usage

```bash
scripts/darwin-rebuild.sh <profile>
```

## Profiles

| Profile           | Description                                                                  |
| ----------------- | ---------------------------------------------------------------------------- |
| `private`         | Default personal Darwin configuration (fallback when hostname doesn't match) |
| `mac-mini-m4`     | Configuration for Mac Mini M4                                                |
| `mac-mini-m4-pro` | Configuration for Mac Mini M4 Pro                                            |
| `bootstrap`       | Bootstrap flake — provisions sops-nix secrets on fresh install               |

## When to Use

- After modifying `.nix` files and confirming `verify-change` passes
- When deploying configuration changes to the current machine

## Prerequisites

- Run `verify-change` first to ensure no build errors
- `sudo` access is required (the script runs `sudo -H nix ... run`)
- Secrets must be properly configured (sops-nix) before running `bootstrap`

## Example

```bash
# 1. Determine profile from hostname
profile=$(hostname)
# If hostname doesn't match a darwinConfigurations key, fall back to "private"

# 2. Verify changes first
.agents/skills/verify-change/scripts/check.sh "$profile"

# 3. Apply the configuration
scripts/darwin-rebuild.sh "$profile"
```
