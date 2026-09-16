# dotfiles

Declarative macOS system and home configuration using Nix flakes, nix-darwin, and home-manager. See [AGENTS.md](./AGENTS.md) for development policies ([CLAUDE.md](./CLAUDE.md) and [GEMINI.md](./GEMINI.md) are symlinks to it).

## Setup (fresh machine)

1. Install Nix:

   ```sh
   sh scripts/install-nix.sh
   ```

2. If the first build fails around CA certificates, symlink the bundled cert as a one-time workaround:

   ```sh
   sudo ln -s /nix/var/nix/profiles/default/etc/ssl/certs/ca-bundle.crt /etc/nix/ca_cert.pem
   ```

3. Log in to Bitwarden and place the sops-nix age key:

   ```sh
   ./scripts/login-rbw-shell.sh
   mkdir -p ~/.config/sops/age
   rbw get "<age key item name>" > ~/.config/sops/age/keys.txt
   ```

4. Switch to the `bootstrap` profile (config-only base: shared settings, no host services). This provisions credentials without triggering service/package builds:

   ```sh
   ./scripts/darwin-rebuild.sh bootstrap
   ```

5. Switch to the full configuration for this host:

   ```sh
   just darwin-rebuild
   ```

### Outside Nix

A small number of GUI apps are installed manually rather than managed declaratively:

- Google Chrome

## Common tasks

Run `just --list` for the full list of recipes (rebuild, worktree cleanup, git hooks install, etc.).
