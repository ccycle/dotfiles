---
name: credentials-manager
description: Manage Nix access tokens and secrets using sops-nix. Edits and rotates sops files, checks age-key recipient drift, regenerates .sops.yaml, and runs sops through rbw so plaintext keys never reach the environment.
---

# Credentials Manager

This skill helps you manage secrets and access tokens in the dotfiles, following the security policies defined in [references/policy.md](references/policy.md).

## Features

### 1. Rotate or Add One Secret

Replace (or add) a single key without decrypting the rest of the file to any screen.
The script commits the change and runs darwin-rebuild; run it with `--help` for the options.

- Agent: ask the user to store the new value in a Bitwarden Secrets Manager project the agent can read (see the bws skill), then run:

  ```bash
  .agents/skills/credentials-manager/scripts/secret-rotate.sh --key <name> --from-bws <project-id> <bws-key> --profile <profile> <path/to/secrets.yaml>
  ```

- User at a terminal (or pre-typed via herdr-tab-handoff): `--from-prompt` reads the value from a hidden prompt instead.

Never open a whole secrets file in an editor or with `sops -d` from an agent session; the `block-secret-screen-reads` Claude Code hook refuses it.
A value whose issuer can write it back itself (e.g. Pocket ID client secrets via the pocket-id-register-clients skill) needs neither path.

### 2. Configure Nix Access Tokens

Generate the necessary Nix configuration to securely inject access tokens (e.g., GitHub PAT) into `/etc/nix/nix-access-tokens-work.conf`.

```bash
.agents/skills/credentials-manager/scripts/setup-token.sh <token_variable_name>
```

Example:

```bash
.agents/skills/credentials-manager/scripts/setup-token.sh github_pat_work
```

This will output the `sops.templates` and `nix.extraOptions` configuration to be added to your `darwin.nix`.

### 3. sops / rbw Plumbing

All paths below are relative to the repository root.

| Script                                                         | Purpose                                                                                                                                      |
| -------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------- |
| `.agents/skills/credentials-manager/scripts/sops-with-rbw`     | Run any sops command with the age key fetched by rbw (`SOPS_AGE_KEY_CMD`), keeping the plaintext key out of the process environment.         |
| [verify-rbw-integration.sh](scripts/verify-rbw-integration.sh) | Verify rbw + sops wiring (rbw installed, unlocked, key item reachable).                                                                      |
| [check-recipients.sh](scripts/check-recipients.sh)             | Compare every `secrets*.yaml` recipient list against [modules/sops/age-keys.nix](../../../modules/sops/age-keys.nix) (no decryption needed). |
| [generate-sops-yaml.sh](scripts/generate-sops-yaml.sh)         | Regenerate the committed `.sops.yaml` from [modules/sops/age-keys.nix](../../../modules/sops/age-keys.nix).                                  |
| [secret-rotate.sh](scripts/secret-rotate.sh)                   | Replace one key from a hidden prompt or bws -> recipient check -> commit -> darwin-rebuild.                                                  |

## Policies

- **Separate Files:** Work credentials must be stored in separate files (e.g., `nix-access-tokens-work.conf`) to avoid conflicts.
- **Sops Encryption:** All secrets must be encrypted using `sops`.
- **Reference:** See [references/policy.md](references/policy.md) for the detailed security policy.
