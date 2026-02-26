---
name: darwin-rebuild
description: Apply Darwin system configuration by running scripts/darwin-rebuild.sh with the appropriate profile. Use this after modifying Nix configuration files and passing verify-change checks.
---

# Darwin Rebuild

This skill applies the nix-darwin system configuration to the local machine using `scripts/darwin-rebuild.sh`.

## Usage

```bash
scripts/darwin-rebuild.sh <profile>
```

## Profiles

| Profile | Description |
|---------|-------------|
| `private` | Main personal Darwin configuration (most common) |
| `mac-mini-m4` | Configuration for Mac Mini M4 |
| `bootstrap` | Bootstrap flake — provisions sops-nix secrets on fresh install |

## When to Use

- After modifying `.nix` files and confirming `verify-change` passes
- When deploying configuration changes to the current machine

## Prerequisites

- Run `verify-change` first to ensure no build errors
- `sudo` access is required (the script runs `sudo -H nix ... run`)
- Secrets must be properly configured (sops-nix) before running `bootstrap`

## Example

```bash
# 1. Verify changes first
skills/project/verify-change/scripts/check.sh private

# 2. Apply the configuration
scripts/darwin-rebuild.sh private
```
