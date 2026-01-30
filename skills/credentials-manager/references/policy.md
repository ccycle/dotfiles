# Credentials Management Policy

## Nix Credentials Strategy

When configuring Nix access tokens (e.g., for fetching private flakes), use a dedicated file separate from the system's primary `access-tokens.conf`.

**Rule:**
- **Separate File:** Generate a specific file for work credentials, such as `/etc/nix/nix-access-tokens-work.conf`.
- **Include mechanism:** Use the `!include` directive in `nix.extraOptions` to load this file.

**Example (nix-darwin):**

```nix
# modules/darwin/nix-core.nix
{ config, ... }:
{
  sops.templates."nix-access-tokens-work.conf" = {
    content = ''
      access-tokens = github.com=${config.sops.placeholder.github_pat_work}
    '';
    path = "/etc/nix/nix-access-tokens-work.conf";
  };

  nix.extraOptions = ''
    !include ${config.sops.templates."nix-access-tokens-work.conf".path}
  '';
}
```

**Reasoning:**
- This prevents conflicts with the base `dotfiles` repository or other configurations that might manage `/etc/nix/access-tokens.conf`.
- It allows multiple sources of credentials to coexist safely.

## File Naming Conventions

- **secrets.nix**: Represents the import of credentials.
- **secrets.yaml**: Contains credentials encrypted by sops-nix.
