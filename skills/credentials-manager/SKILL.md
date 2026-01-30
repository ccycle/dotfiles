---
name: credentials-manager
description: Manage Nix access tokens and secrets using sops-nix. Automates the configuration of secure token access and provides safe wrappers for editing secrets.
---

# Credentials Manager

This skill helps you manage secrets and access tokens in the dotfiles, following the security policies defined in `references/policy.md`.

## Features

### 1. Edit Secrets
Safely edit `secrets.yaml` files using the `sops` wrapper.

```bash
skills/credentials-manager/scripts/edit-secrets.sh <path/to/secrets.yaml>
```

### 2. Configure Nix Access Tokens
Generate the necessary Nix configuration to securely inject access tokens (e.g., GitHub PAT) into `/etc/nix/nix-access-tokens-work.conf`.

```bash
skills/credentials-manager/scripts/setup-token.sh <token_variable_name>
```

Example:
```bash
skills/credentials-manager/scripts/setup-token.sh github_pat_work
```
This will output the `sops.templates` and `nix.extraOptions` configuration to be added to your `darwin.nix`.

## Policies

- **Separate Files:** Work credentials must be stored in separate files (e.g., `nix-access-tokens-work.conf`) to avoid conflicts.
- **Sops Encryption:** All secrets must be encrypted using `sops`.
- **Reference:** See `references/policy.md` for the detailed security policy.
