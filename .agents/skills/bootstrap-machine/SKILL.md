---
name: bootstrap-machine
description: Prepare a fresh macOS machine for this dotfiles repo — install Nix, get a shell with rbw for the sops age key, and move pre-nix-darwin files aside. Use on a new machine or when Nix/rbw are missing before a darwin-rebuild.
---

# Bootstrap Machine

One-time host preparation before the first `darwin-rebuild`. Run these from
the repository root, in this order.

## 1. Install Nix

```bash
sh .agents/skills/bootstrap-machine/scripts/install-nix.sh
```

Refuses to run if `nix` is already on `PATH`.

## 2. Log in to Bitwarden (rbw) and place the age key

```bash
.agents/skills/bootstrap-machine/scripts/login-rbw-shell.sh
mkdir -p ~/.config/sops/age
rbw get "<age key item name>" > ~/.config/sops/age/keys.txt
```

`login-rbw-shell.sh` opens `nix develop .#secrets`, the shell that provides
`rbw` and `sops`. Create the key item once with
`rbw add dotfiles-age-key-$(hostname -s)`.

## 3. Only if the machine already has `/etc` config from a prior Nix install

```bash
sh .agents/skills/bootstrap-machine/scripts/backup-config.sh
```

Moves `/etc/nix/nix.conf`, `/etc/zshenv`, and `/etc/nix/nix.custom.conf` to
`*.before-nix-darwin` so nix-darwin can take them over. Skip on a clean
machine.

## 4. Switch profiles

Start with `bootstrap` (config-only, no host services), then the host profile.
Use the `darwin-rebuild` skill for both.
