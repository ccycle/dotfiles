# dotfiles

Declarative macOS system and home configuration using Nix flakes, nix-darwin, and home-manager. See [AGENTS.md](./AGENTS.md) for development policies ([CLAUDE.md](./CLAUDE.md) is a symlink to it).

## Setup (fresh machine)

1. Install Nix:

   ```sh
   sh bootstrap/install-nix.sh
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

4. Run the bootstrap flake to provision credentials for private flake inputs (see the comment block at the top of [`bootstrap/flake.nix`](./bootstrap/flake.nix) for why this step exists):

   ```sh
   nix run ./bootstrap -- switch --flake ./bootstrap
   ```

5. Switch to the main flake:

   ```sh
   just darwin-rebuild
   ```

### Outside Nix

A small number of GUI apps are installed manually rather than managed declaratively:

- Google Chrome

## Common tasks

Run `just --list` for the full list of recipes (rebuild, worktree cleanup, git hooks install, etc.).
