---
name: cachix-push
description: Build Nix derivations and push resulting store paths to the ccycle Cachix cache using cachix watch-exec. Builds all darwin and home configurations, or a specific profile.
---

# Cachix Push

This skill builds Nix configurations and pushes all resulting store paths to the `ccycle` Cachix binary cache using `cachix watch-exec`.

## Usage

Run the push script from the repository root:

```bash
skills/project/cachix-push/scripts/push.sh [profile]
```

If no profile is specified, all discovered profiles in both `darwinConfigurations` and `homeConfigurations` are built and pushed.

## Authentication

The script resolves a Cachix auth token in priority order:

1. `CACHIX_AUTH_TOKEN` environment variable (used directly)
2. Token file at `/run/secrets/cachix-auth-token-ccycle` (sops-nix secret path)
3. No explicit token (cachix CLI may still push if authenticated via `cachix authtoken`)

## What Gets Built

- `darwinConfigurations.<profile>.<system>.system` (nested profiles)
- `darwinConfigurations.<profile>.system` (flat profiles, current system only)
- `homeConfigurations.<profile>.<system>.activationPackage` (nested profiles)
- `homeConfigurations.<profile>.activationPackage` (flat profiles)

## When to Use

- After making changes that should be cached for other machines or CI
- Before traveling or working offline (pre-warm the cache)
- As a manual alternative to the CI cache push pipeline
