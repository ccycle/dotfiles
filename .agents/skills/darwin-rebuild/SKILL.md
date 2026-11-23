---
name: darwin-rebuild
description: Apply Darwin system configuration by running the darwin-rebuild skill's script, which picks the profile from this machine's hostname. Use this after modifying Nix configuration files and passing verify-change checks.
---

# Darwin Rebuild

This skill applies the nix-darwin system configuration to the local machine using [scripts/darwin-rebuild.sh](scripts/darwin-rebuild.sh).

## Usage

```bash
.agents/skills/darwin-rebuild/scripts/darwin-rebuild.sh [profile]
```

Run it without a profile.
The script uses `scutil --get LocalHostName` (the same default as `darwin-rebuild switch --flake .`), resolves it to a `darwinConfigurations` entry with or without an architecture suffix, and fails with the profile list read from the flake when nothing matches.
Do not fall back to another profile on that failure; report the mismatch to the user.

Pass a profile only when the user names one.
`--help` lists the profiles the flake currently defines.
`bootstrap` matches no hostname, so it runs only when requested by name.

## When to Use

- After modifying `.nix` files and confirming `verify-change` passes
- When deploying configuration changes to the current machine

## Prerequisites

- Run `verify-change` first to ensure no build errors
- The script needs no sudo password: `sudo -H nix ...` matches the NOPASSWD rule in [modules/system/darwin.nix](../../../modules/system/darwin.nix).
  Run it directly.
  Do not probe with `sudo -n true` — that command is not covered by the rule, so it fails without a cached sudo credential even though the script would pass.
- Secrets must be properly configured (sops-nix) before running `bootstrap`

## Example

```bash
.agents/skills/verify-change/scripts/check.sh "$(scutil --get LocalHostName)"
.agents/skills/darwin-rebuild/scripts/darwin-rebuild.sh
```
